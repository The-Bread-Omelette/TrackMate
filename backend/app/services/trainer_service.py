import uuid
import random
from datetime import datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, and_, func
from sqlalchemy.orm import selectinload
from app.models.trainer import TrainerApplication, TrainerRequest, TrainerRequestStatus, TrainerSession, TrainerNote
from app.models.user import User, UserRole
from app.models.notification import NotificationType
from app.services.notification_service import notification_service
from app.core.exceptions import NotFoundError, ConflictError, ForbiddenError


class TrainerService:

    # ── Trainer Application ───────────────────────────────────────────────────

    async def submit_application(
        self,
        db: AsyncSession,
        user: User,
        phone_number: str | None,
        experience_years: int | None,
        about: str | None,
        specializations: str | None,
        certifications: str | None,
        hourly_rate: float | None,
    ) -> TrainerApplication:
        existing = await db.execute(
            select(TrainerApplication).where(TrainerApplication.user_id == user.id)
        )
        if existing.scalar_one_or_none():
            raise ConflictError("Application already submitted")

        app = TrainerApplication(
            user_id=user.id,
            phone_number=phone_number,
            experience_years=experience_years,
            about=about,
            specializations=specializations,
            certifications=certifications,
            hourly_rate=hourly_rate,
        )
        db.add(app)

        from app.services.profile_service import profile_service
        from app.schemas.profile import ProfileUpdateRequest
        await profile_service.update_profile(db, user, ProfileUpdateRequest(
            phone_number=phone_number,
            hourly_rate=hourly_rate,
            specializations=specializations,
            experience_years=experience_years,
        ))

        await db.flush()
        return app

    async def get_my_application(self, db: AsyncSession, user_id: uuid.UUID) -> TrainerApplication | None:
        result = await db.execute(
            select(TrainerApplication).where(TrainerApplication.user_id == user_id)
        )
        return result.scalar_one_or_none()

    async def update_application(
        self,
        db: AsyncSession,
        user_id: uuid.UUID,
        phone_number: str | None,
        experience_years: int | None,
        about: str | None,
        specializations: str | None,
        certifications: str | None,
        hourly_rate: float | None,
    ) -> TrainerApplication:
        result = await db.execute(
            select(TrainerApplication).where(TrainerApplication.user_id == user_id)
        )
        app = result.scalar_one_or_none()
        if not app:
            raise NotFoundError("Application not found")

        if phone_number is not None: app.phone_number = phone_number
        if experience_years is not None: app.experience_years = experience_years
        if about is not None: app.about = about
        if specializations is not None: app.specializations = specializations
        if certifications is not None: app.certifications = certifications
        if hourly_rate is not None: app.hourly_rate = hourly_rate

        # Sync profile updates as well
        from app.services.profile_service import profile_service
        from app.schemas.profile import ProfileUpdateRequest
        from app.models.user import User as UserModel
        
        user_result = await db.execute(select(UserModel).where(UserModel.id == user_id))
        user = user_result.scalar_one_or_none()
        if user:
            await profile_service.update_profile(db, user, ProfileUpdateRequest(
                phone_number=app.phone_number,
                hourly_rate=app.hourly_rate,
                specializations=app.specializations,
                experience_years=app.experience_years,
            ))

        await db.flush()
        return app

    async def withdraw_application(self, db: AsyncSession, user_id: uuid.UUID) -> None:
        result = await db.execute(
            select(TrainerApplication).where(TrainerApplication.user_id == user_id)
        )
        app = result.scalar_one_or_none()
        if app:
            await db.delete(app)
            await db.flush()

    # ── Trainee → Trainer Request ─────────────────────────────────────────────

    async def send_trainer_request(
        self, db: AsyncSession, trainee: User, trainer_id: uuid.UUID, goal: str
    ) -> TrainerRequest:
        if trainee.trainer_id:
            raise ConflictError("You already have an active trainer.")

        trainer_result = await db.execute(
            select(User).where(User.id == trainer_id, User.role == UserRole.TRAINER)
        )
        trainer = trainer_result.scalar_one_or_none()
        if not trainer:
            raise NotFoundError("Trainer")

        existing = await db.execute(
            select(TrainerRequest).where(
                TrainerRequest.trainee_id == trainee.id,
                TrainerRequest.trainer_id == trainer_id,
                TrainerRequest.status == TrainerRequestStatus.PENDING,
            )
        )
        if existing.scalar_one_or_none():
            raise ConflictError("Request already pending")

        req = TrainerRequest(
            trainee_id=trainee.id,
            trainer_id=trainer_id,
            goal=goal,
        )
        db.add(req)
        await db.flush()

        await notification_service.create(
            db, trainer_id, NotificationType.TRAINER_REQUEST,
            "New trainee request",
            f"{trainee.full_name} wants you as their trainer",
            reference_id=str(req.id),
        )
        return req

    async def respond_to_trainer_request(
        self, db: AsyncSession, request_id: uuid.UUID, trainer: User, accept: bool
    ) -> TrainerRequest:
        result = await db.execute(
            select(TrainerRequest).where(
                TrainerRequest.id == request_id,
                TrainerRequest.trainer_id == trainer.id,
                TrainerRequest.status == TrainerRequestStatus.PENDING,
            )
        )
        req = result.scalar_one_or_none()
        if not req:
            raise NotFoundError("Request")

        req.status = TrainerRequestStatus.ACCEPTED if accept else TrainerRequestStatus.REJECTED
        await db.flush()

        if accept:
            trainee_result = await db.execute(select(User).where(User.id == req.trainee_id))
            trainee = trainee_result.scalar_one_or_none()
            if trainee:
                trainee.trainer_id = trainer.id
                
                await db.execute(
                    TrainerRequest.__table__.update()
                    .where(
                        and_(
                            TrainerRequest.trainee_id == trainee.id,
                            TrainerRequest.status == TrainerRequestStatus.PENDING,
                            TrainerRequest.id != req.id
                        )
                    )
                    .values(status=TrainerRequestStatus.REJECTED)
                )
                await db.flush()

            await notification_service.create(
                db, req.trainee_id, NotificationType.TRAINER_ACCEPTED,
                "Trainer request accepted",
                f"{trainer.full_name} accepted your request",
                reference_id=str(req.id),
            )
        else:
            await notification_service.create(
                db, req.trainee_id, NotificationType.TRAINER_REJECTED,
                "Trainer request rejected",
                f"{trainer.full_name} could not take you on at this time",
                reference_id=str(req.id),
            )

        return req

    async def quit_trainer(self, db: AsyncSession, trainee: User) -> None:
        if not trainee.trainer_id:
            raise ConflictError("You do not have an active trainer to quit.")
            
        old_trainer_id = trainee.trainer_id
        trainee.trainer_id = None
        
        await db.execute(
            TrainerRequest.__table__.update()
            .where(
                and_(
                    TrainerRequest.trainee_id == trainee.id,
                    TrainerRequest.trainer_id == old_trainer_id,
                    TrainerRequest.status == TrainerRequestStatus.ACCEPTED
                )
            )
            .values(status=TrainerRequestStatus.REJECTED)
        )
        
        try:
            from app.services.messaging_service import messaging_service
            conv = await messaging_service.get_or_create_conversation(db, trainee.id, old_trainer_id)
            await messaging_service.save_message(
                db, conv.id, trainee.id, 
                "System: The training relationship has been terminated."
            )
        except Exception:
            pass 

        await db.flush()

    async def get_trainer_requests(
        self, db: AsyncSession, trainer_id: uuid.UUID
    ) -> list[TrainerRequest]:
        result = await db.execute(
            select(TrainerRequest).where(
                TrainerRequest.trainer_id == trainer_id,
                TrainerRequest.status == TrainerRequestStatus.PENDING,
            ).options(selectinload(TrainerRequest.trainee))
        )
        return result.scalars().all()

    # ── Trainer Students ──────────────────────────────────────────────────────

    async def get_students(self, db: AsyncSession, trainer_id: uuid.UUID) -> list[dict]:
        result = await db.execute(
            select(User).where(User.trainer_id == trainer_id)
            .options(selectinload(User.profile))
        )
        students = result.scalars().all()
        return [self._student_summary(s) for s in students]

    def _student_summary(self, user: User) -> dict:
        seed = int(str(user.id).replace("-", "")[:8], 16)
        random.seed(seed)
        adherence = random.randint(55, 98)
        workout_score = random.randint(50, 100)
        streak = random.randint(0, 30)
        excellence = round((adherence * 0.4 + workout_score * 0.4 + min(streak * 2, 20)) / 1.0, 1)
        needs_attention = adherence < 65 or streak < 3

        return {
            "id": str(user.id),
            "full_name": user.full_name,
            "email": user.email,
            "profile_image_url": user.profile.profile_image_url if user.profile else None,
            "adherence": adherence,
            "workout_score": workout_score,
            "streak": streak,
            "excellence_pct": min(excellence, 100),
            "needs_attention": needs_attention,
            "height_cm": user.profile.height_cm if user.profile else None,
            "weight_kg": user.profile.weight_kg if user.profile else None,
            "daily_step_goal": user.profile.daily_step_goal if user.profile else None,
            "daily_calorie_goal": user.profile.daily_calorie_goal if user.profile else None,
            "bio": user.profile.bio if user.profile else None,
            "activity_level": user.profile.activity_level if user.profile else None,
        }

    async def get_student_detail(
        self, db: AsyncSession, trainer_id: uuid.UUID, trainee_id: uuid.UUID
    ) -> dict:
        result = await db.execute(
            select(User).where(
                User.id == trainee_id,
                User.trainer_id == trainer_id,
            ).options(selectinload(User.profile))
        )
        student = result.scalar_one_or_none()
        if not student:
            raise NotFoundError("Student")

        notes_result = await db.execute(
            select(TrainerNote).where(
                TrainerNote.trainee_id == trainee_id,
                TrainerNote.trainer_id == trainer_id,
            ).order_by(TrainerNote.created_at.desc())
        )
        notes = notes_result.scalars().all()

        summary = self._student_summary(student)
        summary["notes"] = [
            {"id": str(n.id), "content": n.content, "created_at": n.created_at.isoformat()}
            for n in notes
        ]
        return summary

    # ── Trainer Notes ─────────────────────────────────────────────────────────

    async def add_note(
        self, db: AsyncSession, trainer: User, trainee_id: uuid.UUID, content: str
    ) -> TrainerNote:
        trainee_result = await db.execute(
            select(User).where(User.id == trainee_id, User.trainer_id == trainer.id)
        )
        if not trainee_result.scalar_one_or_none():
            raise ForbiddenError("Not your student")

        note = TrainerNote(
            trainer_id=trainer.id,
            trainee_id=trainee_id,
            content=content,
        )
        db.add(note)
        await db.flush()
        return note

    # ── Trainer Calendar ──────────────────────────────────────────────────────

    async def schedule_session(
        self,
        db: AsyncSession,
        trainer: User,
        trainee_id: uuid.UUID,
        scheduled_at: datetime,
        duration_minutes: int,
        notes: str | None,
    ) -> TrainerSession:
        trainee_result = await db.execute(
            select(User).where(User.id == trainee_id, User.trainer_id == trainer.id)
        )
        if not trainee_result.scalar_one_or_none():
            raise ForbiddenError("Not your student")

        session = TrainerSession(
            trainer_id=trainer.id,
            trainee_id=trainee_id,
            scheduled_at=scheduled_at,
            duration_minutes=duration_minutes,
            notes=notes,
        )
        db.add(session)
        await db.flush()
        return session

    async def get_calendar(self, db: AsyncSession, trainer_id: uuid.UUID) -> list[dict]:
        result = await db.execute(
            select(TrainerSession).where(
                TrainerSession.trainer_id == trainer_id,
            )
            .options(selectinload(TrainerSession.trainee))
            .order_by(TrainerSession.scheduled_at)
        )
        sessions = result.scalars().all()
        return [
            {
                "id": str(s.id),
                "trainee": {"id": str(s.trainee_id), "full_name": s.trainee.full_name},
                "scheduled_at": s.scheduled_at.isoformat(),
                "duration_minutes": s.duration_minutes,
                "notes": s.notes,
            }
            for s in sessions
        ]

    # ── Trainer Stats ─────────────────────────────────────────────────────────

    async def get_stats(self, db: AsyncSession, trainer_id: uuid.UUID) -> dict:
        students = await self.get_students(db, trainer_id)
        total = len(students)
        needs_attention = sum(1 for s in students if s["needs_attention"])
        avg_adherence = round(sum(s["adherence"] for s in students) / total, 1) if total else 0

        return {
            "total_students": total,
            "avg_adherence": avg_adherence,
            "needs_attention": needs_attention,
        }

    # ── Available Trainers ────────────────────────────────────────────────────

    async def get_available_trainers(self, db: AsyncSession) -> list[dict]:
        result = await db.execute(
            select(User).where(User.role == UserRole.TRAINER, User.is_active == True)
            .options(selectinload(User.profile))
        )
        trainers = result.scalars().all()
        return [
            {
                "id": str(t.id),
                "full_name": t.full_name,
                "email": t.email,
                "profile_image_url": t.profile.profile_image_url if t.profile else None,
                "specializations": t.profile.specializations if t.profile else None,
                "experience_years": t.profile.experience_years if t.profile else None,
                "hourly_rate": t.profile.hourly_rate if t.profile else None,
                "bio": t.profile.bio if t.profile else None,
            }
            for t in trainers
        ]

trainer_service = TrainerService()