import csv
import os
import uuid
from datetime import datetime, date, timezone, timedelta
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func, desc
from sqlalchemy.orm import selectinload

from app.models.fitness import (
    Exercise, WorkoutSession, WorkoutSet, WorkoutStatus,
    MealLog, StepLog, HydrationLog, WeightLog
)
from app.models.user import User
from app.core.exceptions import NotFoundError, ForbiddenError


class FitnessService:
    def __init__(self):
        self.local_exercise_db = []
        self._load_exercises_csv()

    def _load_exercises_csv(self):
        csv_path = os.path.join(os.path.dirname(__file__), "exercises.csv")
        if not os.path.exists(csv_path):
            return
        try:
            with open(csv_path, mode="r", encoding="utf-8") as f:
                reader = csv.DictReader(f)
                for row in reader:
                    self.local_exercise_db.append({
                        "id": str(uuid.uuid4()),
                        "name": row.get("Exercise Name", "").strip(),
                        "category": row.get("Exercise Type", "strength").lower(),
                        "measurement_type": "reps",
                        "description": row.get("Description", ""),
                        "is_custom": False,
                    })
        except Exception:
            pass

    # ── Exercises ─────────────────────────────────────────────────────────────

    async def search_exercises(self, db: AsyncSession, q: str, user_id: uuid.UUID) -> list[dict]:
        # Overridden to use the CSV data so the Flutter app gets the new items
        q = q.lower().strip()
        if not q:
            return self.local_exercise_db[:20]
        return [ex for ex in self.local_exercise_db if q in ex["name"].lower()][:20]

    async def create_exercise(
        self, db: AsyncSession, user_id: uuid.UUID,
        name: str, category: str, measurement_type: str, description: str | None
    ) -> Exercise:
        exercise = Exercise(
            name=name, category=category,
            measurement_type=measurement_type,
            description=description,
            is_custom=True, created_by=user_id,
        )
        db.add(exercise)
        await db.flush()
        return exercise

    # ── Workout Sessions ──────────────────────────────────────────────────────

    async def start_session(
        self, db: AsyncSession, user_id: uuid.UUID, name: str | None
    ) -> WorkoutSession:
        session = WorkoutSession(user_id=user_id, name=name)
        db.add(session)
        await db.flush()
        await db.refresh(session)
        return session

    async def finish_session(
        self, db: AsyncSession, session_id: uuid.UUID,
        user_id: uuid.UUID, notes: str | None, calories_burned: float | None
    ) -> WorkoutSession:
        session = await self._get_session(db, session_id, user_id)
        session.status = WorkoutStatus.COMPLETED
        session.ended_at = datetime.now(timezone.utc)
        session.notes = notes
        session.calories_burned = calories_burned
        await db.flush()
        await db.refresh(session)
        return session

    async def get_session(
        self, db: AsyncSession, session_id: uuid.UUID, user_id: uuid.UUID
    ) -> WorkoutSession:
        return await self._get_session(db, session_id, user_id)

    async def get_session_history(
        self, db: AsyncSession, user_id: uuid.UUID, limit: int = 20
    ) -> list[WorkoutSession]:
        result = await db.execute(
            select(WorkoutSession)
            .where(
                WorkoutSession.user_id == user_id,
                WorkoutSession.status == WorkoutStatus.COMPLETED,
            )
            .options(selectinload(WorkoutSession.sets).selectinload(WorkoutSet.exercise))
            .order_by(desc(WorkoutSession.started_at))
            .limit(limit)
        )
        return result.scalars().all()

    async def _get_session(
        self, db: AsyncSession, session_id: uuid.UUID, user_id: uuid.UUID
    ) -> WorkoutSession:
        result = await db.execute(
            select(WorkoutSession)
            .where(WorkoutSession.id == session_id)
            .options(selectinload(WorkoutSession.sets).selectinload(WorkoutSet.exercise))
        )
        session = result.scalar_one_or_none()
        if not session:
            raise NotFoundError("Workout session")
        if str(session.user_id) != str(user_id):
            raise ForbiddenError("Not your session")
        return session

    async def log_set(
        self, db: AsyncSession, session_id: uuid.UUID, user_id: uuid.UUID,
        exercise_id: uuid.UUID, set_number: int,
        reps: int | None, weight_kg: float | None,
        duration_seconds: int | None, notes: str | None
    ) -> WorkoutSet:
        await self._get_session(db, session_id, user_id)
        workout_set = WorkoutSet(
            session_id=session_id, exercise_id=exercise_id,
            set_number=set_number, reps=reps, weight_kg=weight_kg,
            duration_seconds=duration_seconds, notes=notes,
        )
        db.add(workout_set)
        await db.flush()
        await db.refresh(workout_set)
        return workout_set

    async def delete_set(
        self, db: AsyncSession, set_id: uuid.UUID, user_id: uuid.UUID
    ) -> None:
        result = await db.execute(
            select(WorkoutSet)
            .where(WorkoutSet.id == set_id)
            .options(selectinload(WorkoutSet.session))
        )
        workout_set = result.scalar_one_or_none()
        if not workout_set:
            raise NotFoundError("Set")
        if str(workout_set.session.user_id) != str(user_id):
            raise ForbiddenError("Not your set")
        await db.delete(workout_set)
        await db.flush()

    # ── Food & Nutrition ──────────────────────────────────────────────────────

    async def log_meal(
        self, db: AsyncSession, user_id: uuid.UUID, food_id: str, food_name: str,
        calories_per_100g: float, protein_per_100g: float, carbs_per_100g: float,
        fat_per_100g: float, serving_size_g: float, serving_label: str,
        servings: float, logged_at: datetime | None,
    ) -> MealLog:
        log = MealLog(
            user_id=user_id, food_id=food_id, food_name=food_name,
            calories_per_100g=calories_per_100g, protein_per_100g=protein_per_100g,
            carbs_per_100g=carbs_per_100g, fat_per_100g=fat_per_100g,
            serving_size_g=serving_size_g, serving_label=serving_label,
            servings=servings, logged_at=logged_at or datetime.now(timezone.utc),
        )
        db.add(log)
        await db.flush()
        await db.refresh(log)
        return log
    
    async def get_meals_for_date(self, db: AsyncSession, user_id: uuid.UUID, target_date: date) -> list[MealLog]:
        start = datetime.combine(target_date, datetime.min.time()).replace(tzinfo=timezone.utc)
        end = start + timedelta(days=1)
        result = await db.execute(
            select(MealLog).where(
                MealLog.user_id == user_id, MealLog.logged_at >= start, MealLog.logged_at < end,
            ).order_by(MealLog.logged_at)
        )
        return result.scalars().all()

    async def delete_meal(self, db: AsyncSession, meal_id: uuid.UUID, user_id: uuid.UUID) -> None:
        result = await db.execute(select(MealLog).where(MealLog.id == meal_id))
        log = result.scalar_one_or_none()
        if not log: raise NotFoundError("Meal log")
        if str(log.user_id) != str(user_id): raise ForbiddenError("Not your meal")
        await db.delete(log)
        await db.flush()

    async def get_nutrition_summary(self, db: AsyncSession, user_id: uuid.UUID, target_date: date) -> dict:
        meals = await self.get_meals_for_date(db, user_id, target_date)
        def _calc(m, field): return getattr(m, field) * m.servings * m.serving_size_g / 100
        return {
            "date": target_date.isoformat(),
            "total_calories": round(sum(_calc(m, "calories_per_100g") for m in meals), 1),
            "total_protein_g": round(sum(_calc(m, "protein_per_100g") for m in meals), 1),
            "total_carbs_g": round(sum(_calc(m, "carbs_per_100g") for m in meals), 1),
            "total_fat_g": round(sum(_calc(m, "fat_per_100g") for m in meals), 1),
            "meal_count": len(meals),
        }

    # ── Steps ─────────────────────────────────────────────────────────────────

    async def log_steps(self, db: AsyncSession, user_id: uuid.UUID, steps: int, logged_date: date) -> StepLog:
        result = await db.execute(select(StepLog).where(StepLog.user_id == user_id, StepLog.logged_date == logged_date))
        existing = result.scalar_one_or_none()
        if existing:
            existing.steps = steps
            await db.flush()
            return existing
        log = StepLog(user_id=user_id, steps=steps, logged_date=logged_date)
        db.add(log)
        await db.flush()
        await db.refresh(log)
        return log

    async def get_steps_summary(self, db: AsyncSession, user_id: uuid.UUID, user_goal: int) -> dict:
        today = date.today()
        result = await db.execute(select(StepLog).where(StepLog.user_id == user_id, StepLog.logged_date == today))
        log = result.scalar_one_or_none()
        steps_today = log.steps if log else 0
        return {
            "date": today.isoformat(),
            "steps": steps_today,
            "goal": user_goal,
            "percentage": round(steps_today / user_goal * 100, 1) if user_goal else 0,
            "remaining": max(0, user_goal - steps_today),
        }

    async def get_steps_history(self, db: AsyncSession, user_id: uuid.UUID, days: int = 7) -> list[dict]:
        since = date.today() - timedelta(days=days)
        result = await db.execute(select(StepLog).where(StepLog.user_id == user_id, StepLog.logged_date >= since).order_by(StepLog.logged_date))
        logs = result.scalars().all()
        return [{"date": l.logged_date.isoformat(), "steps": l.steps} for l in logs]

    async def get_streak(self, db: AsyncSession, user_id: uuid.UUID, goal: int) -> int:
        result = await db.execute(select(StepLog).where(StepLog.user_id == user_id, StepLog.steps >= goal).order_by(desc(StepLog.logged_date)))
        logs = result.scalars().all()
        streak = 0
        check_date = date.today()
        for log in logs:
            if log.logged_date == check_date:
                streak += 1
                check_date -= timedelta(days=1)
            else: break
        return streak

    # ── Hydration ─────────────────────────────────────────────────────────────

    async def log_hydration(self, db: AsyncSession, user_id: uuid.UUID, amount_ml: int) -> HydrationLog:
        log = HydrationLog(user_id=user_id, amount_ml=amount_ml)
        db.add(log)
        await db.flush()
        await db.refresh(log)
        return log

    async def get_hydration_summary(self, db: AsyncSession, user_id: uuid.UUID) -> dict:
        today_start = datetime.combine(date.today(), datetime.min.time()).replace(tzinfo=timezone.utc)
        result = await db.execute(select(func.sum(HydrationLog.amount_ml)).where(HydrationLog.user_id == user_id, HydrationLog.logged_at >= today_start))
        total_ml = result.scalar_one() or 0
        return {
            "date": date.today().isoformat(),
            "total_ml": total_ml,
            "total_l": round(total_ml / 1000, 2),
            "goal_ml": 2500,
            "percentage": round(total_ml / 2500 * 100, 1),
        }

    # ── Weight ────────────────────────────────────────────────────────────────

    async def log_weight(self, db: AsyncSession, user_id: uuid.UUID, weight_kg: float) -> WeightLog:
        log = WeightLog(user_id=user_id, weight_kg=weight_kg)
        db.add(log)
        await db.flush()
        await db.refresh(log)
        return log

    async def get_weight_trend(self, db: AsyncSession, user_id: uuid.UUID, days: int = 30) -> list[dict]:
        since = datetime.now(timezone.utc) - timedelta(days=days)
        result = await db.execute(select(WeightLog).where(WeightLog.user_id == user_id, WeightLog.logged_at >= since).order_by(WeightLog.logged_at))
        logs = result.scalars().all()
        return [{"date": l.logged_at.date().isoformat(), "weight_kg": l.weight_kg} for l in logs]

    # ── Stats ─────────────────────────────────────────────────────────────────

    async def get_weekly_stats(self, db: AsyncSession, user_id: uuid.UUID, user_goal: int) -> dict:
        since = datetime.now(timezone.utc) - timedelta(days=7)
        since_date = date.today() - timedelta(days=7)

        workouts = await db.execute(select(func.count(WorkoutSession.id)).where(WorkoutSession.user_id == user_id, WorkoutSession.status == WorkoutStatus.COMPLETED, WorkoutSession.started_at >= since))
        calories_burned = await db.execute(select(func.sum(WorkoutSession.calories_burned)).where(WorkoutSession.user_id == user_id, WorkoutSession.status == WorkoutStatus.COMPLETED, WorkoutSession.started_at >= since))
        step_logs = await db.execute(select(StepLog).where(StepLog.user_id == user_id, StepLog.logged_date >= since_date))
        step_data = step_logs.scalars().all()
        total_steps = sum(s.steps for s in step_data)
        goal_days_met = sum(1 for s in step_data if s.steps >= user_goal)
        streak = await self.get_streak(db, user_id, user_goal)

        return {
            "workouts_completed": workouts.scalar_one() or 0,
            "calories_burned": round(calories_burned.scalar_one() or 0, 1),
            "total_steps": total_steps,
            "step_goal_days_met": goal_days_met,
            "streak_days": streak,
        }

fitness_service = FitnessService()