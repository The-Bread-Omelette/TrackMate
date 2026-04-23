import uuid
from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional
from pydantic import BaseModel

from app.schemas.auth import ApproveTrainerRequest
from app.db.base import get_db
from app.api.v1.deps import require_admin
from app.models.user import User
from app.services.admin_service import admin_service

router = APIRouter(prefix="/admin", tags=["Admin"])


class ResolveReportRequest(BaseModel):
    dismiss: bool = False


@router.post("/trainer-applications/{user_id}/approve", status_code=status.HTTP_200_OK)
async def approve_trainer(
    user_id: uuid.UUID,
    payload: ApproveTrainerRequest,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    result = await admin_service.resolve_trainer_application(db, str(user_id), payload.approve, admin)
    return {"message": "Success", "status": result["status"], "role": result["role"]}


@router.get("/stats", status_code=status.HTTP_200_OK)
async def get_stats(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await admin_service.get_stats(db)


@router.get("/users", status_code=status.HTTP_200_OK)
async def list_users(
    role: Optional[str] = Query(default=None),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, le=100),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    users = await admin_service.list_users(db, role, page, limit)
    return [
        {
            "id": str(u.id),
            "email": u.email,
            "full_name": u.full_name,
            "role": u.role,
            "trainer_status": u.trainer_status,
            "is_active": u.is_active,
            "is_verified": u.is_verified,
            "created_at": u.created_at.isoformat(),
        }
        for u in users
    ]


@router.get("/users/{user_id}", status_code=status.HTTP_200_OK)
async def get_user(
    user_id: uuid.UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    user = await admin_service.get_user(db, user_id)
    return {
        "id": str(user.id),
        "email": user.email,
        "full_name": user.full_name,
        "role": user.role,
        "trainer_status": user.trainer_status,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "created_at": user.created_at.isoformat(),
        "profile": {
            "bio": user.profile.bio if user.profile else None,
            "height_cm": user.profile.height_cm if user.profile else None,
            "weight_kg": user.profile.weight_kg if user.profile else None,
        } if user.profile else None,
    }


@router.put("/users/{user_id}/deactivate", status_code=status.HTTP_200_OK)
async def deactivate_user(
    user_id: uuid.UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    user = await admin_service.set_active(db, user_id, False)
    return {"message": f"{user.full_name} deactivated"}


@router.put("/users/{user_id}/activate", status_code=status.HTTP_200_OK)
async def activate_user(
    user_id: uuid.UUID,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    user = await admin_service.set_active(db, user_id, True)
    return {"message": f"{user.full_name} activated"}


@router.get("/trainer-applications/new", status_code=status.HTTP_200_OK)
async def get_new_admissions(
    status: Optional[str] = Query(default=None),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await admin_service.get_new_admissions(db, status)


@router.get("/trainer-applications/updates", status_code=status.HTTP_200_OK)
async def get_profile_updates(
    status: Optional[str] = Query(default=None),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await admin_service.get_profile_updates(db, status)


@router.get("/reports", status_code=status.HTTP_200_OK)
async def get_reports(
    status: Optional[str] = Query(default=None),
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await admin_service.get_reports(db, status)


@router.put("/reports/{report_id}/resolve", status_code=status.HTTP_200_OK)
async def resolve_report(
    report_id: uuid.UUID,
    payload: ResolveReportRequest,
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    report = await admin_service.resolve_report(db, report_id, payload.dismiss)
    return {"report_id": str(report.id), "status": report.status}


@router.get("/reports/flagged-messages", status_code=status.HTTP_200_OK)
async def get_flagged_messages(
    admin: User = Depends(require_admin),
    db: AsyncSession = Depends(get_db),
):
    return await admin_service.get_flagged_messages(db)

