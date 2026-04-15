import uuid
from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from pydantic import BaseModel, Field
from typing import Optional

from app.db.base import get_db
from app.api.v1.deps import get_current_user
from app.models.user import User
from app.models.social import ReportType
from app.services.social_service import social_service

router = APIRouter(prefix="/social", tags=["Social"])


class CreatePostRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000, description="Post content cannot exceed 2000 characters")


class FriendRequestResponse(BaseModel):
    request_id: uuid.UUID
    accept: bool


class ReportMessageRequest(BaseModel):
    message_id: uuid.UUID
    reported_user_id: uuid.UUID
    report_type: ReportType
    body: str = Field(..., min_length=1, max_length=2000, description="Report description cannot exceed 2000 characters")


@router.post("/friends/request/{user_id}", status_code=status.HTTP_201_CREATED)
async def send_friend_request(
    user_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    req = await social_service.send_friend_request(db, current_user, user_id)
    return {"request_id": str(req.id), "status": req.status}


@router.put("/friends/request/{request_id}", status_code=status.HTTP_200_OK)
async def respond_to_friend_request(
    request_id: uuid.UUID,
    payload: FriendRequestResponse,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    req = await social_service.respond_to_friend_request(db, request_id, current_user, payload.accept)
    return {"request_id": str(req.id), "status": req.status}


@router.get("/friends/requests", status_code=status.HTTP_200_OK)
async def get_pending_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    requests = await social_service.get_pending_requests(db, current_user.id)
    return [
        {
            "request_id": str(r.id),
            "sender": {"id": str(r.sender_id), "full_name": r.sender.full_name},
            "created_at": r.created_at.isoformat(),
        }
        for r in requests
    ]


@router.get("/friends", status_code=status.HTTP_200_OK)
async def get_friends(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    friends = await social_service.get_friends(db, current_user.id)
    return [{"id": str(f.id), "full_name": f.full_name, "email": f.email} for f in friends]


@router.delete("/friends/{friend_id}", status_code=status.HTTP_200_OK)
async def remove_friend(
    friend_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await social_service.remove_friend(db, current_user.id, friend_id)
    return {"message": "Friend removed"}


@router.get("/feed", status_code=status.HTTP_200_OK)
async def get_feed(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await social_service.get_feed(db, current_user)


@router.post("/posts", status_code=status.HTTP_201_CREATED)
async def create_post(
    payload: CreatePostRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    post = await social_service.create_post(db, current_user, payload.content)
    return {"id": str(post.id), "content": post.content, "created_at": post.created_at.isoformat()}


@router.delete("/posts/{post_id}", status_code=status.HTTP_200_OK)
async def delete_post(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await social_service.delete_post(db, post_id, current_user)
    return {"message": "Post deleted"}


@router.post("/posts/{post_id}/like", status_code=status.HTTP_200_OK)
async def toggle_like(
    post_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    liked = await social_service.toggle_like(db, post_id, current_user)
    return {"liked": liked}


@router.post("/report/message", status_code=status.HTTP_201_CREATED)
async def report_message(
    payload: ReportMessageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    report = await social_service.report_message(
        db, current_user, payload.message_id,
        payload.reported_user_id, payload.report_type, payload.body,
    )
    return {"report_id": str(report.id), "status": report.status}

@router.get("/leaderboard", status_code=status.HTTP_200_OK)
async def get_leaderboard(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from app.services.fitness_service import fitness_service
    from datetime import date, timedelta
    from sqlalchemy import func
    from app.models.fitness import StepLog

    friends = await social_service.get_friends(db, current_user.id)
    visible_ids = [f.id for f in friends] + [current_user.id]

    since = date.today() - timedelta(days=7)
    result = await db.execute(
        select(
            StepLog.user_id,
            func.sum(StepLog.steps).label("total_steps"),
        )
        .where(
            StepLog.user_id.in_(visible_ids),
            StepLog.logged_date >= since,
        )
        .group_by(StepLog.user_id)
        .order_by(func.sum(StepLog.steps).desc())
    )
    rows = result.all()

    user_map = {str(f.id): f.full_name for f in friends}
    user_map[str(current_user.id)] = current_user.full_name

    return [
        {
            "rank": i + 1,
            "user_id": str(row.user_id),
            "full_name": user_map.get(str(row.user_id), "Unknown"),
            "total_steps": row.total_steps,
            "is_me": str(row.user_id) == str(current_user.id),
        }
        for i, row in enumerate(rows)
    ]