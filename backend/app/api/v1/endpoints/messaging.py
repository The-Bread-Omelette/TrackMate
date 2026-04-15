import json
import uuid
from datetime import datetime, timezone
from sqlalchemy import select, and_, func
from fastapi import APIRouter, Depends, WebSocket, WebSocketDisconnect, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel

from app.db.base import get_db, AsyncSessionLocal
from app.api.v1.deps import get_current_user
from app.models.user import User
from app.models.messaging import ConversationMember, Message
from app.services.messaging_service import messaging_service
from app.services.presence_service import presence_service
from app.services.connection_manager import manager
from app.core.exceptions import NotFoundError


class StartConversationRequest(BaseModel):
    other_user_id: uuid.UUID


router = APIRouter(prefix="/messaging", tags=["Messaging"])


# ─── REST ────────────────────────────────────────────────────────────────────

@router.post("/conversations", status_code=status.HTTP_201_CREATED)
async def start_conversation(
    payload: StartConversationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(User).where(
            and_(
                User.id == payload.other_user_id,
                User.is_active == True,
                User.is_verified == True,
            )
        )
    )
    other_user = result.scalar_one_or_none()
    if not other_user:
        raise NotFoundError("User")

    conv = await messaging_service.get_or_create_conversation(
        db, current_user.id, payload.other_user_id
    )
    return {
        "conversation_id": str(conv.id),
        "other_user": {
            "id": str(other_user.id),
            "full_name": other_user.full_name,
            "email": other_user.email,
        }
    }


@router.get("/conversations")
async def list_conversations(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await messaging_service.get_conversations(db, current_user.id)


@router.get("/conversations/{conversation_id}/messages")
async def get_messages(
    conversation_id: uuid.UUID,
    before: datetime | None = Query(default=None),
    limit: int = Query(default=50, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    messages = await messaging_service.get_messages(
        db, conversation_id, current_user.id, before, limit
    )
    return [
        {
            "id": str(m.id),
            "conversation_id": str(m.conversation_id),
            "sender_id": str(m.sender_id),
            "content": m.content,
            "status": m.status,
            "is_pinned": m.is_pinned, # 🔥 Exposed to Flutter
            "reply_to": {"id": str(m.reply_to.id), "content": m.reply_to.content} if m.reply_to else None, # 🔥 Exposed
            "is_deleted": m.is_deleted,
            "created_at": m.created_at.isoformat(),
        }
        for m in messages
    ]


@router.put("/conversations/{conversation_id}/read", status_code=status.HTTP_200_OK)
async def mark_read(
    conversation_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    conv = await messaging_service.get_conversation(
        db, conversation_id, current_user.id
    )
    await messaging_service.mark_read(db, conversation_id, current_user.id)

    other_member = next(
        (m for m in conv.members if str(m.user_id) != str(current_user.id)),
        None,
    )
    if other_member:
        await manager.send(str(other_member.user_id), {
            "type": "messages_read",
            "conversation_id": str(conversation_id),
            "read_by": str(current_user.id),
        })

    return {"message": "Marked as read"}


@router.delete("/messages/{message_id}", status_code=status.HTTP_200_OK)
async def delete_message(
    message_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    msg = await messaging_service.delete_message(db, message_id, current_user.id)
    return {"message": "Deleted", "message_id": str(msg.id)}


@router.get("/users/{user_id}/presence")
async def get_user_presence(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
):
    online = await presence_service.is_online(str(user_id))
    last_seen = await presence_service.get_last_seen(str(user_id))
    return {
        "user_id": str(user_id),
        "online": online,
        "last_seen": last_seen,
    }


@router.post("/ws-ticket", status_code=status.HTTP_200_OK)
async def get_ws_ticket(
    current_user: User = Depends(get_current_user),
) -> dict:
    ticket = await presence_service.create_ws_ticket(str(current_user.id))
    return {"ticket": ticket}


# ─── WebSocket ───────────────────────────────────────────────────────────────

@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    ticket: str = Query(...),
):
    await websocket.accept()

    user_id_str = await presence_service.consume_ws_ticket(ticket)
    if not user_id_str:
        await websocket.close(code=4001, reason="Invalid or expired ticket")
        return

    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(User).where(User.id == uuid.UUID(user_id_str)) 
        )
        user = result.scalar_one_or_none()
        if not user or not user.is_active:
            await websocket.close(code=4001, reason="User not found")
            return

    user_id = str(user.id)
    manager._connections[user_id] = websocket
    await presence_service.set_online(user_id)
    await _broadcast_presence(user_id, online=True)

    # Push unread summary to client on connect
    async with AsyncSessionLocal() as db:
        memberships_result = await db.execute(
            select(ConversationMember).where(ConversationMember.user_id == user.id)
        )
        memberships = memberships_result.scalars().all()

        unread_conversations = []
        for membership in memberships:
            unread_result = await db.execute(
                select(func.count(Message.id)).where(
                    and_(
                        Message.conversation_id == membership.conversation_id,
                        Message.sender_id != user.id,
                        Message.created_at > (
                            membership.last_read_at or
                            datetime.min.replace(tzinfo=timezone.utc)
                        ),
                    )
                )
            )
            count = unread_result.scalar_one()
            if count > 0:
                unread_conversations.append({
                    "conversation_id": str(membership.conversation_id),
                    "unread_count": count,
                })

        if unread_conversations:
            await manager.send(user_id, {
                "type": "unread_summary",
                "conversations": unread_conversations,
            })
            
    try:
        while True:
            raw = await websocket.receive_text()
            try:
                data = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = data.get("type")

            # ── Send message to Abu <3 <3 ──────────────────────────────────────────────
          # ── Send message to Sahil<3──────────────────────────────────────────────
            if msg_type == "send_message":
                conversation_id = data.get("conversation_id")
                content = data.get("content", "").strip()
                reply_to_id = data.get("reply_to_id") 
                client_id = data.get("client_id") # 🔥 Capture the client_id from Flutter
                
                if not conversation_id or not content:
                    continue
                    
                if len(content) > 2000:
                    await manager.send(user_id, {"type": "error", "message": "Message exceeds 2000 characters."})
                    continue

                async with AsyncSessionLocal() as db:
                    try:
                        conv_uuid = uuid.UUID(conversation_id)
                        conv = await messaging_service.get_conversation(db, conv_uuid, user.id)
                        
                        msg = await messaging_service.save_message(
                            db, conv_uuid, user.id, content,
                            reply_to_id=uuid.UUID(reply_to_id) if reply_to_id else None
                        )
                        await db.commit()
                        await db.refresh(msg, ["reply_to"])

                        # The core message dictionary
                        msg_dict = {
                            "id": str(msg.id),
                            "conversation_id": str(msg.conversation_id),
                            "sender_id": str(msg.sender_id),
                            "content": msg.content,
                            "status": msg.status,
                            "is_pinned": msg.is_pinned,
                            "reply_to": {"id": str(msg.reply_to.id), "content": msg.reply_to.content} if msg.reply_to else None,
                            "created_at": msg.created_at.isoformat(),
                        }

                        # 1. Send new_message to the OTHER user(s)
                        other = next((m for m in conv.members if str(m.user_id) != user_id), None)
                        if other:
                            delivered = await manager.send(str(other.user_id), {
                                "type": "new_message",
                                "message": msg_dict
                            })
                            if delivered:
                                async with AsyncSessionLocal() as db2:
                                    await messaging_service.mark_delivered(db2, msg.id)
                                    await db2.commit()
                                msg_dict["status"] = "delivered"

                        # 🔥 2. Send the EXPLICIT ACK directly back to the sender
                        await manager.send(user_id, {
                            "type": "message_ack",
                            "client_id": client_id,
                            "message": msg_dict
                        })

                    except Exception as e:
                        await db.rollback()
                        await manager.send(user_id, {"type": "error", "message": str(e)})

            # ── Pin message ───────────────────────────────────────────────
            elif msg_type == "pin_message":
                msg_id = data.get("message_id")
                if not msg_id:
                    continue
                    
                async with AsyncSessionLocal() as db:
                    try:
                        msg = await messaging_service.toggle_pin(db, uuid.UUID(msg_id), user.id)
                        await db.commit()
                        
                        conv = await messaging_service.get_conversation(db, msg.conversation_id, user.id)
                        
                        broadcast_payload = {
                            "type": "message_pinned",
                            "message_id": str(msg.id),
                            "is_pinned": msg.is_pinned,
                            "content": msg.content
                        }
                        
                        # Tell everyone in the chat that the pin status changed
                        for member in conv.members:
                            await manager.send(str(member.user_id), broadcast_payload)
                    except Exception:
                        await db.rollback()

            # ── Mark read ─────────────────────────────────────────────────
            elif msg_type == "mark_read":
                conversation_id = data.get("conversation_id")
                if not conversation_id:
                    continue

                async with AsyncSessionLocal() as db:
                    try:
                        conv_uuid = uuid.UUID(conversation_id)
                        conv = await messaging_service.get_conversation(db, conv_uuid, user.id)
                        await messaging_service.mark_read(db, conv_uuid, user.id)
                        await db.commit()

                        other = next((m for m in conv.members if str(m.user_id) != user_id), None)
                        if other:
                            await manager.send(str(other.user_id), {
                                "type": "messages_read",
                                "conversation_id": conversation_id,
                                "read_by": user_id,
                            })
                    except Exception:
                        await db.rollback()

            # ── Typing ───────────────────────────────────────────────────
            elif msg_type == "typing":
                conversation_id = data.get("conversation_id")
                if not conversation_id:
                    continue

                await presence_service.set_typing(conversation_id, user_id)

                async with AsyncSessionLocal() as db:
                    try:
                        conv = await messaging_service.get_conversation(db, uuid.UUID(conversation_id), user.id)
                        other = next((m for m in conv.members if str(m.user_id) != user_id), None)
                        if other:
                            await manager.send(str(other.user_id), {
                                "type": "typing",
                                "conversation_id": conversation_id,
                                "user_id": user_id,
                            })
                    except Exception:
                        pass

            # ── Heartbeat ─────────────────────────────────────────────────
            elif msg_type == "heartbeat":
                await presence_service.heartbeat(user_id)
                await manager.send(user_id, {"type": "heartbeat_ack"})

    except WebSocketDisconnect:
        pass
    finally:
        manager.disconnect(user_id)
        await presence_service.set_offline(user_id)
        await _broadcast_presence(user_id, online=False)


async def _broadcast_presence(user_id: str, online: bool) -> None:
    payload = {
        "type": "user_online" if online else "user_offline",
        "user_id": user_id,
    }
    for connected_user_id in list(manager._connections.keys()):
        if connected_user_id != user_id:
            await manager.send(connected_user_id, payload)