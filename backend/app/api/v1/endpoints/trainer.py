import uuid
from datetime import datetime
from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field
from typing import Optional

from app.db.base import get_db
from app.api.v1.deps import get_current_user, require_trainer
from app.models.user import User
from app.services.trainer_service import trainer_service

router = APIRouter(prefix="/trainer", tags=["Trainer"])


class TrainerApplicationRequest(BaseModel):
    phone_number: Optional[str] = Field(default=None, max_length=20)
    experience_years: Optional[int] = Field(default=None, ge=0, le=80, description="Years of experience cannot be negative or absurd")
    about: Optional[str] = Field(default=None, max_length=2000)
    specializations: Optional[str] = Field(default=None, max_length=500)
    certifications: Optional[str] = Field(default=None, max_length=500)
    hourly_rate: Optional[float] = Field(default=None, ge=0.0, le=100000.0, description="Hourly rate cannot be negative or absurd")


class TrainerRequestBody(BaseModel):
    trainer_id: uuid.UUID
    goal: str = Field(..., max_length=1000)


class RespondToRequestBody(BaseModel):
    accept: bool


class ScheduleSessionRequest(BaseModel):
    trainee_id: uuid.UUID
    scheduled_at: datetime
    duration_minutes: int = Field(default=60, ge=15, le=360, description="Session must be between 15 mins and 6 hours")
    notes: Optional[str] = Field(default=None, max_length=1000)


class AddNoteRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=2000)


# ── Trainer Application ───────────────────────────────────────────────────────

@router.post("/apply", status_code=status.HTTP_201_CREATED)
async def submit_application(
    payload: TrainerApplicationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    app = await trainer_service.submit_application(
        db, current_user,
        payload.phone_number, payload.experience_years,
        payload.about, payload.specializations,
        payload.certifications, payload.hourly_rate,
    )
    return {"application_id": str(app.id), "status": app.status}


# ── Trainee: Browse & Request Trainers ────────────────────────────────────────

@router.get("/available", status_code=status.HTTP_200_OK)
async def get_available_trainers(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await trainer_service.get_available_trainers(db)


@router.post("/request", status_code=status.HTTP_201_CREATED)
async def send_trainer_request(
    payload: TrainerRequestBody,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    req = await trainer_service.send_trainer_request(
        db, current_user, payload.trainer_id, payload.goal
    )
    return {"request_id": str(req.id), "status": req.status}


@router.get("/my-trainer", status_code=status.HTTP_200_OK)
async def get_my_trainer(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not current_user.trainer_id:
        return {"trainer": None}
    from sqlalchemy import select
    from app.models.user import User as UserModel
    result = await db.execute(
        select(UserModel).where(UserModel.id == current_user.trainer_id)
    )
    trainer = result.scalar_one_or_none()
    if not trainer:
        return {"trainer": None}
    return {
        "trainer": {
            "id": str(trainer.id),
            "full_name": trainer.full_name,
            "email": trainer.email,
        }
    }

@router.get("/my-notes", status_code=status.HTTP_200_OK)
async def get_my_notes(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    from app.models.trainer import TrainerNote
    result = await db.execute(
        select(TrainerNote)
        .where(TrainerNote.trainee_id == current_user.id)
        .order_by(TrainerNote.created_at.desc())
    )
    notes = result.scalars().all()
    return [
        {"id": str(n.id), "content": n.content, "created_at": n.created_at.isoformat()} 
        for n in notes
    ]
    
@router.post("/quit", status_code=status.HTTP_200_OK)
async def quit_current_trainer(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await trainer_service.quit_trainer(db, current_user)
    return {"message": "Successfully removed trainer."}


# ── Trainer: Manage Students ──────────────────────────────────────────────────

@router.get("/students", status_code=status.HTTP_200_OK)
async def get_students(
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    return await trainer_service.get_students(db, trainer.id)


@router.get("/students/{trainee_id}", status_code=status.HTTP_200_OK)
async def get_student_detail(
    trainee_id: uuid.UUID,
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    return await trainer_service.get_student_detail(db, trainer.id, trainee_id)


@router.post("/students/{trainee_id}/notes", status_code=status.HTTP_201_CREATED)
async def add_note(
    trainee_id: uuid.UUID,
    payload: AddNoteRequest,
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    note = await trainer_service.add_note(db, trainer, trainee_id, payload.content)
    return {"note_id": str(note.id), "content": note.content, "created_at": note.created_at.isoformat()}


@router.get("/stats", status_code=status.HTTP_200_OK)
async def get_trainer_stats(
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    return await trainer_service.get_stats(db, trainer.id)


# ── Trainer: Requests ─────────────────────────────────────────────────────────

@router.get("/requests", status_code=status.HTTP_200_OK)
async def get_trainer_requests(
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    requests = await trainer_service.get_trainer_requests(db, trainer.id)
    return [
        {
            "request_id": str(r.id),
            "trainee": {"id": str(r.trainee_id), "full_name": r.trainee.full_name},
            "goal": r.goal,
            "status": r.status,
            "created_at": r.created_at.isoformat(),
        }
        for r in requests
    ]


@router.put("/requests/{request_id}", status_code=status.HTTP_200_OK)
async def respond_to_request(
    request_id: uuid.UUID,
    payload: RespondToRequestBody,
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    req = await trainer_service.respond_to_trainer_request(db, request_id, trainer, payload.accept)
    return {"request_id": str(req.id), "status": req.status}


# ── Trainer: Calendar ─────────────────────────────────────────────────────────

@router.get("/calendar", status_code=status.HTTP_200_OK)
async def get_calendar(
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    return await trainer_service.get_calendar(db, trainer.id)


@router.post("/calendar/sessions", status_code=status.HTTP_201_CREATED)
async def schedule_session(
    payload: ScheduleSessionRequest,
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    session = await trainer_service.schedule_session(
        db, trainer, payload.trainee_id,
        payload.scheduled_at, payload.duration_minutes, payload.notes,
    )
    return {
        "session_id": str(session.id),
        "scheduled_at": session.scheduled_at.isoformat(),
        "duration_minutes": session.duration_minutes,
    }
    
from app.services.fitness_service import fitness_service as fs

# ── Trainer: View Student Fitness Data ───────────────────────────────────────

@router.get("/students/{trainee_id}/workouts", status_code=status.HTTP_200_OK)
async def get_student_workouts(
    trainee_id: uuid.UUID,
    limit: int = Query(default=20, le=100),
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    from app.models.user import User as UserModel
    result = await db.execute(
        select(UserModel).where(
            UserModel.id == trainee_id,
            UserModel.trainer_id == trainer.id,
        )
    )
    if not result.scalar_one_or_none():
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Student")

    sessions = await fs.get_session_history(db, trainee_id, limit)
    from app.api.v1.endpoints.fitness import _format_session
    return [_format_session(s) for s in sessions]


@router.get("/students/{trainee_id}/nutrition", status_code=status.HTTP_200_OK)
async def get_student_nutrition(
    trainee_id: uuid.UUID,
    date: Optional[datetime] = Query(default=None),
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    from app.models.user import User as UserModel
    result = await db.execute(
        select(UserModel).where(
            UserModel.id == trainee_id,
            UserModel.trainer_id == trainer.id,
        )
    )
    if not result.scalar_one_or_none():
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Student")

    from datetime import timezone, date as date_type
    target = date.date() if date else datetime.now(timezone.utc).date()
    meals = await fs.get_meals_for_date(db, trainee_id, target)
    summary = await fs.get_nutrition_summary(db, trainee_id, target)
    return {
        "summary": summary,
        "meals": [
            {
                "id": str(m.id),
                "food_name": m.food_name,
                "servings": m.servings,
                "calories": round(m.calories_per_100g * m.servings * m.serving_size_g / 100, 1),
                "protein_g": round(m.protein_per_100g * m.servings * m.serving_size_g / 100, 1),
                "logged_at": m.logged_at.isoformat(),
            }
            for m in meals
        ],
    }


@router.get("/students/{trainee_id}/stats", status_code=status.HTTP_200_OK)
async def get_student_stats(
    trainee_id: uuid.UUID,
    trainer: User = Depends(require_trainer),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    from app.models.user import User as UserModel
    from app.services.profile_service import profile_service
    result = await db.execute(
        select(UserModel).where(
            UserModel.id == trainee_id,
            UserModel.trainer_id == trainer.id,
        )
    )
    trainee = result.scalar_one_or_none()
    if not trainee:
        from app.core.exceptions import NotFoundError
        raise NotFoundError("Student")

    profile = await profile_service.get_or_create_profile(db, trainee)
    weekly = await fs.get_weekly_stats(db, trainee_id, profile.daily_step_goal)
    streak = await fs.get_streak(db, trainee_id, profile.daily_step_goal)
    steps_history = await fs.get_steps_history(db, trainee_id, days=7)
    weight_trend = await fs.get_weight_trend(db, trainee_id, days=30)

    return {
        "weekly": weekly,
        "streak_days": streak,
        "steps_history": steps_history,
        "weight_trend": weight_trend,
    }


# ── Trainee: View Own Scheduled Sessions ─────────────────────────────────────

@router.get("/my-sessions", status_code=status.HTTP_200_OK)
async def get_my_sessions(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import select
    from app.models.trainer import TrainerSession
    from sqlalchemy.orm import selectinload
    result = await db.execute(
        select(TrainerSession)
        .where(TrainerSession.trainee_id == current_user.id)
        .options(selectinload(TrainerSession.trainer))
        .order_by(TrainerSession.scheduled_at)
    )
    sessions = result.scalars().all()
    return [
        {
            "id": str(s.id),
            "trainer": {"id": str(s.trainer_id), "full_name": s.trainer.full_name},
            "scheduled_at": s.scheduled_at.isoformat(),
            "duration_minutes": s.duration_minutes,
            "notes": s.notes,
        }
        for s in sessions
    ]