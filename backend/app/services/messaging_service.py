import uuid
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, or_, func
from sqlalchemy.orm import selectinload

from app.models.messaging import Conversation, ConversationMember, Message, MessageStatus
from app.models.user import User
from app.core.exceptions import NotFoundError, ForbiddenError


class MessagingService:

    async def get_or_create_conversation(
        self, db: AsyncSession, user_a_id: uuid.UUID, user_b_id: uuid.UUID
    ) -> Conversation:
        result = await db.execute(
            select(Conversation)
            .join(ConversationMember, ConversationMember.conversation_id == Conversation.id)
            .where(ConversationMember.user_id == user_a_id)
            .options(selectinload(Conversation.members))
        )
        conversations = result.scalars().all()

        for conv in conversations:
            member_ids = {str(m.user_id) for m in conv.members}
            if str(user_b_id) in member_ids and len(member_ids) == 2:
                return conv

        conv = Conversation()
        db.add(conv)
        await db.flush()

        for uid in [user_a_id, user_b_id]:
            member = ConversationMember(
                conversation_id=conv.id,
                user_id=uid,
            )
            db.add(member)

        await db.flush()
        await db.refresh(conv)
        return conv

    async def get_conversation(
        self, db: AsyncSession, conversation_id: uuid.UUID, user_id: uuid.UUID
    ) -> Conversation:
        result = await db.execute(
            select(Conversation)
            .where(Conversation.id == conversation_id)
            .options(selectinload(Conversation.members))
        )
        conv = result.scalar_one_or_none()
        if not conv:
            raise NotFoundError("Conversation")
        member_ids = [str(m.user_id) for m in conv.members]
        if str(user_id) not in member_ids:
            raise ForbiddenError("You are not a member of this conversation")
        return conv

    async def get_conversations(
        self, db: AsyncSession, user_id: uuid.UUID
    ) -> list[dict]:
        result = await db.execute(
            select(ConversationMember)
            .where(ConversationMember.user_id == user_id)
            .options(
                selectinload(ConversationMember.conversation)
                .selectinload(Conversation.members)
                .selectinload(ConversationMember.user)
            )
        )
        memberships = result.scalars().all()

        conversations = []
        for membership in memberships:
            conv = membership.conversation

            last_msg_result = await db.execute(
                select(Message)
                .where(Message.conversation_id == conv.id)
                .order_by(Message.created_at.desc())
                .limit(1)
            )
            last_msg = last_msg_result.scalar_one_or_none()

            unread_result = await db.execute(
                select(func.count(Message.id))
                .where(
                    and_(
                        Message.conversation_id == conv.id,
                        Message.sender_id != user_id,
                        Message.created_at > (membership.last_read_at or datetime.min.replace(tzinfo=timezone.utc)),
                    )
                )
            )
            unread_count = unread_result.scalar_one()

            other_member = next((m for m in conv.members if str(m.user_id) != str(user_id)), None)

            conversations.append({
                "conversation_id": str(conv.id),
                "other_user": {
                    "id": str(other_member.user_id) if other_member else None,
                    "full_name": other_member.user.full_name if other_member else None,
                } if other_member else None,
                "last_message": {
                    "content": last_msg.content if last_msg and not last_msg.is_deleted else None,
                    "sender_id": str(last_msg.sender_id) if last_msg else None,
                    "created_at": last_msg.created_at.isoformat() if last_msg else None,
                    "status": last_msg.status if last_msg else None,
                } if last_msg else None,
                "unread_count": unread_count,
                "created_at": conv.created_at.isoformat(),
            })

        return sorted(
            conversations,
            key=lambda x: x["last_message"]["created_at"] if x["last_message"] else x["created_at"],
            reverse=True,
        )

    async def get_messages(self, db: AsyncSession, conversation_id: uuid.UUID, user_id: uuid.UUID, before: datetime | None = None, limit: int = 50) -> list[Message]:
        # 🔥 Updated to pre-load reply_to for Flutter
        query = select(Message).where(
            and_(Message.conversation_id == conversation_id, Message.is_deleted == False)
        ).options(selectinload(Message.reply_to))
        
        if before:
            query = query.where(Message.created_at < before)

        query = query.order_by(Message.created_at.desc()).limit(limit)
        result = await db.execute(query)
        return list(reversed(result.scalars().all()))

    async def save_message(self, db: AsyncSession, conversation_id: uuid.UUID, sender_id: uuid.UUID, content: str, reply_to_id: uuid.UUID | None = None) -> Message:
        msg = Message(
            conversation_id=conversation_id,
            sender_id=sender_id,
            content=content,
            reply_to_id=reply_to_id, 
            status=MessageStatus.SENT,
        )
        db.add(msg)
        await db.flush()
        return msg

    async def toggle_pin(self, db: AsyncSession, message_id: uuid.UUID, user_id: uuid.UUID) -> Message:
        result = await db.execute(select(Message).where(Message.id == message_id))
        msg = result.scalar_one_or_none()
        if not msg: raise NotFoundError("Message")
        
        msg.is_pinned = not msg.is_pinned
        await db.flush()
        return msg

    async def mark_delivered(
        self, db: AsyncSession, message_id: uuid.UUID
    ) -> None:
        result = await db.execute(select(Message).where(Message.id == message_id))
        msg = result.scalar_one_or_none()
        if msg and msg.status == MessageStatus.SENT:
            msg.status = MessageStatus.DELIVERED
            await db.flush()

    async def mark_read(
        self,
        db: AsyncSession,
        conversation_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> None:
        result = await db.execute(
            select(ConversationMember).where(
                and_(
                    ConversationMember.conversation_id == conversation_id,
                    ConversationMember.user_id == user_id,
                )
            )
        )
        member = result.scalar_one_or_none()
        if member:
            member.last_read_at = datetime.now(timezone.utc)
            await db.flush()

        msgs_result = await db.execute(
            select(Message).where(
                and_(
                    Message.conversation_id == conversation_id,
                    Message.sender_id != user_id,
                    Message.status != MessageStatus.READ,
                )
            )
        )
        for msg in msgs_result.scalars().all():
            msg.status = MessageStatus.READ
        await db.flush()

    async def delete_message(
        self,
        db: AsyncSession,
        message_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> Message:
        result = await db.execute(select(Message).where(Message.id == message_id))
        msg = result.scalar_one_or_none()
        if not msg:
            raise NotFoundError("Message")
        if str(msg.sender_id) != str(user_id):
            raise ForbiddenError("You can only delete your own messages")
        msg.is_deleted = True
        msg.content = ""
        await db.flush()
        await db.refresh(msg)
        return msg


messaging_service = MessagingService()