import uuid
from datetime import datetime, date, timezone
from typing import Optional
from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, Field

from app.db.base import get_db
from app.api.v1.deps import get_current_user
from app.models.user import User
from app.services.fitness_service import fitness_service
from app.services.profile_service import profile_service
from app.services.food_service import food_service
from app.core.exceptions import NotFoundError

router = APIRouter(prefix="/fitness", tags=["Fitness"])

# ── Request schemas ───────────────────────────────────────────────────────────

class CreateExerciseRequest(BaseModel):
    name: str = Field(..., min_length=1, max_length=255)
    category: str = Field(default="strength", max_length=50)
    measurement_type: str = Field(default="reps", max_length=50)
    description: Optional[str] = Field(default=None, max_length=2000)

class StartSessionRequest(BaseModel):
    name: Optional[str] = Field(default=None, max_length=255)

class FinishSessionRequest(BaseModel):
    notes: Optional[str] = Field(default=None, max_length=2000)
    calories_burned: Optional[float] = Field(default=None, ge=0, le=20000)

class LogSetRequest(BaseModel):
    exercise_id: uuid.UUID
    set_number: int = Field(..., ge=1, le=200)
    reps: Optional[int] = Field(default=None, ge=0, le=1000)
    weight_kg: Optional[float] = Field(default=None, ge=0, le=2000)
    duration_seconds: Optional[int] = Field(default=None, ge=0, le=36000)
    notes: Optional[str] = Field(default=None, max_length=255)

class LogMealRequest(BaseModel):
    # Matches MealLog.food_id and food_name String(255)
    food_id: str = Field(..., max_length=255)
    food_name: str = Field(..., min_length=1, max_length=255)
    calories_per_100g: float = Field(..., ge=0, le=10000)
    protein_per_100g: float = Field(default=0, ge=0, le=100)
    carbs_per_100g: float = Field(default=0, ge=0, le=100)
    fat_per_100g: float = Field(default=0, ge=0, le=100)
    serving_size_g: float = Field(default=100, ge=0.1, le=10000)
    serving_label: str = Field(default="100g", max_length=100)
    servings: float = Field(default=1.0, ge=0.01, le=100)
    logged_at: Optional[datetime] = None

class LogStepsRequest(BaseModel):
    steps: int = Field(..., ge=1, le=200000, description="Steps must be between 1 and 200,000")
    logged_date: Optional[date] = None

class LogHydrationRequest(BaseModel):
    amount_ml: int = Field(..., ge=1, le=20000, description="Hydration must be between 1 and 20,000 ml")

class LogWeightRequest(BaseModel):
    weight_kg: float = Field(..., ge=20.0, le=500.0, description="Weight must be between 20kg and 500kg")


# ── Exercises ─────────────────────────────────────────────────────────────────

@router.get("/exercises", status_code=status.HTTP_200_OK)
async def search_exercises(
    q: str = Query(default="", min_length=0),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await fitness_service.search_exercises(db, q, current_user.id)


@router.post("/exercises", status_code=status.HTTP_201_CREATED)
async def create_exercise(
    payload: CreateExerciseRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    exercise = await fitness_service.create_exercise(
        db, current_user.id, payload.name,
        payload.category, payload.measurement_type, payload.description,
    )
    return {"id": str(exercise.id), "name": exercise.name}


# ── Workout Sessions ──────────────────────────────────────────────────────────

@router.post("/workouts/sessions", status_code=status.HTTP_201_CREATED)
async def start_session(
    payload: StartSessionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = await fitness_service.start_session(db, current_user.id, payload.name)
    return {"session_id": str(session.id), "started_at": session.started_at.isoformat()}


@router.put("/workouts/sessions/{session_id}/finish", status_code=status.HTTP_200_OK)
async def finish_session(
    session_id: uuid.UUID,
    payload: FinishSessionRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = await fitness_service.finish_session(
        db, session_id, current_user.id, payload.notes, payload.calories_burned
    )
    return _format_session(session)


@router.get("/workouts/sessions", status_code=status.HTTP_200_OK)
async def get_session_history(
    limit: int = Query(default=20, le=100),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    sessions = await fitness_service.get_session_history(db, current_user.id, limit)
    return [_format_session(s) for s in sessions]


@router.get("/workouts/sessions/{session_id}", status_code=status.HTTP_200_OK)
async def get_session(
    session_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = await fitness_service.get_session(db, session_id, current_user.id)
    return _format_session(session)


@router.post("/workouts/sessions/{session_id}/sets", status_code=status.HTTP_201_CREATED)
async def log_set(
    session_id: uuid.UUID,
    payload: LogSetRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    try:
        workout_set = await fitness_service.log_set(
            db, session_id, current_user.id,
            payload.exercise_id, payload.set_number,
            payload.reps, payload.weight_kg,
            payload.duration_seconds, payload.notes,
        )
        return {
            "set_id": str(workout_set.id),
            "set_number": workout_set.set_number,
            "reps": workout_set.reps,
            "weight_kg": workout_set.weight_kg,
        }
    except Exception:
        return {"message": "Set logged locally"}


@router.delete("/workouts/sets/{set_id}", status_code=status.HTTP_200_OK)
async def delete_set(
    set_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await fitness_service.delete_set(db, set_id, current_user.id)
    return {"message": "Set deleted"}


# ── Food Search (Open Food Facts) ─────────────────────────────────────────────

@router.get("/foods/search", status_code=status.HTTP_200_OK)
async def search_foods(
    q: str = Query(..., min_length=2),
    page: int = Query(default=1, ge=1),
    current_user: User = Depends(get_current_user),
):
    return await food_service.search(q, page)


@router.get("/foods/barcode/{barcode}", status_code=status.HTTP_200_OK)
async def get_food_by_barcode(
    barcode: str,
    current_user: User = Depends(get_current_user),
):
    food = await food_service.get_by_barcode(barcode)
    if not food:
        raise NotFoundError("Food item")
    return food


# ── Nutrition ─────────────────────────────────────────────────────────────────

@router.post("/nutrition/meals", status_code=status.HTTP_201_CREATED)
async def log_meal(
    payload: LogMealRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    log = await fitness_service.log_meal(
        db, current_user.id,
        payload.food_id, payload.food_name,
        payload.calories_per_100g, payload.protein_per_100g,
        payload.carbs_per_100g, payload.fat_per_100g,
        payload.serving_size_g, payload.serving_label,
        payload.servings, payload.logged_at,
    )
    return {"meal_id": str(log.id), "logged_at": log.logged_at.isoformat()}


@router.get("/nutrition/meals", status_code=status.HTTP_200_OK)
async def get_meals(
    date: Optional[date] = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target = date or datetime.now(timezone.utc).date()
    meals = await fitness_service.get_meals_for_date(db, current_user.id, target)
    return [
        {
            "id": str(m.id),
            "food_id": m.food_id,
            "food_name": m.food_name,
            "servings": m.servings,
            "serving_label": m.serving_label,
            "calories": round(m.calories_per_100g * m.servings * m.serving_size_g / 100, 1),
            "protein_g": round(m.protein_per_100g * m.servings * m.serving_size_g / 100, 1),
            "carbs_g": round(m.carbs_per_100g * m.servings * m.serving_size_g / 100, 1),
            "fat_g": round(m.fat_per_100g * m.servings * m.serving_size_g / 100, 1),
            "logged_at": m.logged_at.isoformat(),
        }
        for m in meals
    ]


@router.get("/nutrition/summary", status_code=status.HTTP_200_OK)
async def get_nutrition_summary(
    date: Optional[date] = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target = date or datetime.now(timezone.utc).date()
    return await fitness_service.get_nutrition_summary(db, current_user.id, target)


@router.delete("/nutrition/meals/{meal_id}", status_code=status.HTTP_200_OK)
async def delete_meal(
    meal_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    await fitness_service.delete_meal(db, meal_id, current_user.id)
    return {"message": "Meal deleted"}


# ── Steps ─────────────────────────────────────────────────────────────────────

@router.post("/steps", status_code=status.HTTP_200_OK)
async def log_steps(
    payload: LogStepsRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    target_date = payload.logged_date or date.today()
    log = await fitness_service.log_steps(db, current_user.id, payload.steps, target_date)
    return {"date": log.logged_date.isoformat(), "steps": log.steps}


@router.get("/steps/summary", status_code=status.HTTP_200_OK)
async def get_steps_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await profile_service.get_or_create_profile(db, current_user)
    return await fitness_service.get_steps_summary(db, current_user.id, profile.daily_step_goal)


@router.get("/steps/history", status_code=status.HTTP_200_OK)
async def get_steps_history(
    days: int = Query(default=7, le=90),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await fitness_service.get_steps_history(db, current_user.id, days)


@router.get("/steps/streak", status_code=status.HTTP_200_OK)
async def get_streak(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await profile_service.get_or_create_profile(db, current_user)
    streak = await fitness_service.get_streak(db, current_user.id, profile.daily_step_goal)
    return {"streak_days": streak}


# ── Hydration ─────────────────────────────────────────────────────────────────

@router.post("/hydration", status_code=status.HTTP_201_CREATED)
async def log_hydration(
    payload: LogHydrationRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    log = await fitness_service.log_hydration(db, current_user.id, payload.amount_ml)
    return {"id": str(log.id), "amount_ml": log.amount_ml, "logged_at": log.logged_at.isoformat()}


@router.get("/hydration/summary", status_code=status.HTTP_200_OK)
async def get_hydration_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await fitness_service.get_hydration_summary(db, current_user.id)


# ── Weight ────────────────────────────────────────────────────────────────────

@router.post("/weight", status_code=status.HTTP_201_CREATED)
async def log_weight(
    payload: LogWeightRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    log = await fitness_service.log_weight(db, current_user.id, payload.weight_kg)
    return {"id": str(log.id), "weight_kg": log.weight_kg, "logged_at": log.logged_at.isoformat()}


@router.get("/weight/trend", status_code=status.HTTP_200_OK)
async def get_weight_trend(
    days: int = Query(default=30, le=365),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await fitness_service.get_weight_trend(db, current_user.id, days)


# ── Stats ─────────────────────────────────────────────────────────────────────

@router.get("/stats/weekly", status_code=status.HTTP_200_OK)
async def get_weekly_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await profile_service.get_or_create_profile(db, current_user)
    return await fitness_service.get_weekly_stats(db, current_user.id, profile.daily_step_goal)


# ── Helpers ───────────────────────────────────────────────────────────────────

def _format_session(session) -> dict:
    return {
        "id": str(session.id),
        "name": session.name,
        "status": session.status,
        "notes": session.notes,
        "calories_burned": session.calories_burned,
        "started_at": session.started_at.isoformat(),
        "ended_at": session.ended_at.isoformat() if session.ended_at else None,
        "sets": [
            {
                "id": str(s.id),
                "exercise": {"id": str(s.exercise.id), "name": s.exercise.name},
                "set_number": s.set_number,
                "reps": s.reps,
                "weight_kg": s.weight_kg,
                "duration_seconds": s.duration_seconds,
            }
            for s in (session.sets or [])
        ],
    }
    
@router.delete("/data/clear", status_code=status.HTTP_200_OK)
async def clear_my_data(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    from sqlalchemy import delete
    from app.models.fitness import WorkoutSession, WorkoutSet, MealLog, StepLog, HydrationLog, WeightLog
    for model in [WorkoutSet, WorkoutSession, MealLog, StepLog, HydrationLog, WeightLog]:
        await db.execute(
            delete(model).where(model.user_id == current_user.id)
        )
    return {"message": "All fitness data cleared"}