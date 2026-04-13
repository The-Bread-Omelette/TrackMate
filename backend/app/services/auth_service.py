import secrets
from app.core.security import hash_password
from app.models.user import User, UserRole, TrainerStatus
from app.models.trainer import TrainerApplication
from sqlalchemy.ext.asyncio import AsyncSession
from app.core.security import verify_password, create_access_token, create_refresh_token, decode_token
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse, 
    MessageResponse, ForgotPasswordRequest, ResetPasswordRequest
)
from app.core.exceptions import AuthenticationError, ConflictError, ForbiddenError, NotFoundError
from app.services.email_service import email_service
from sqlalchemy import select
from jose import JWTError
import asyncio
import random
from datetime import timedelta, timezone, datetime
import redis.asyncio as aioredis


OTP_EXPIRATION_SECONDS = 600  # 10 minutes
class AuthService:

    async def register(self, db: AsyncSession, redis_client: aioredis.Redis, payload: RegisterRequest) -> MessageResponse:
        result = await db.execute(select(User).where(User.email == payload.email))
        if result.scalar_one_or_none():
            raise ConflictError("An account with this email already exists")

        user = User(
            email=payload.email,
            hashed_password=hash_password(payload.password),
            full_name=payload.full_name,
            role=UserRole.TRAINEE,
            trainer_status=TrainerStatus.PENDING if payload.apply_as_trainer else TrainerStatus.NONE,
            verification_otp=None,
            otp_expires_at=None,
            is_active=False,
            is_verified=False,
        )
        db.add(user)
        await db.flush()
        await db.refresh(user)
        
        otp = str(random.randint(100000, 999999))
        await redis_client.set(f"verify_otp:{user.email}", otp, ex=OTP_EXPIRATION_SECONDS)

        await asyncio.to_thread(
            email_service.send_verification_email,
            user.email, user.full_name, otp
        )

        return MessageResponse(message="Account created. Please check your email to verify your account.")

    async def login(self, db: AsyncSession, payload: LoginRequest) -> tuple[User, TokenResponse]:
        result = await db.execute(select(User).where(User.email == payload.email))
        user = result.scalar_one_or_none()

        if not user or not verify_password(payload.password, user.hashed_password):
            raise AuthenticationError("Invalid email or password")

        if not user.is_active:
            if not user.is_verified:
                raise ForbiddenError("Please verify your email before logging in.")
            raise ForbiddenError("Account is deactivated. Please contact support.")
        tokens = self._issue_tokens(user)
        return user, tokens

    async def verify_email(self, db: AsyncSession, redis_client: aioredis.Redis, email: str, otp: str) -> tuple[User, TokenResponse]:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFoundError("User")
        if user.is_verified:
            raise ConflictError("Email already verified")
            
        # Retrieve OTP from Redis
        stored_otp = await redis_client.get(f"verify_otp:{email}")
        
        if not stored_otp:
            raise AuthenticationError("OTP has expired or does not exist. Please request a new one.")
        if stored_otp != otp:
            raise AuthenticationError("Invalid OTP")
        
        user.is_verified = True
        user.is_active = True
        await db.flush()
        await db.refresh(user)
        
        # Delete the OTP from Redis now that it has been used
        await redis_client.delete(f"verify_otp:{email}")
        
        tokens = self._issue_tokens(user)
        return user, tokens
              
    async def approve_trainer(
        self, db: AsyncSession, user_id: str, approve: bool, admin: User
    ) -> User:
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if not user:
            raise NotFoundError("User")

        app_result = await db.execute(
            select(TrainerApplication)
            .where(TrainerApplication.user_id == user_id)
            .order_by(TrainerApplication.submitted_at.desc())
        )
        application = app_result.scalars().first()
        if not application:
            raise NotFoundError("Trainer application not found for this user")

        if approve:
            user.role = UserRole.TRAINER
            user.trainer_status = TrainerStatus.APPROVED
            application.status = "approved"
            try:
                email_service.send_trainer_approved_email(user.email, user.full_name)
            except Exception as e:
                print(f"[Email] Failed to send approval email: {e}")
        else:
            user.role = UserRole.TRAINEE
            user.trainer_status = TrainerStatus.REJECTED
            application.status = "rejected"
            try:
                email_service.send_trainer_rejected_email(user.email, user.full_name)
            except Exception as e:
                print(f"[Email] Failed to send rejection email: {e}")

        application.reviewed_at = datetime.now(timezone.utc)

        await db.flush()
        await db.refresh(user)
        return user

    async def assign_trainer(
        self, db: AsyncSession, trainee_id: str, trainer_id: str
    ) -> User:
        t_result = await db.execute(select(User).where(User.id == trainer_id))
        trainer = t_result.scalar_one_or_none()
        if not trainer or trainer.role != UserRole.TRAINER:
            raise NotFoundError("Trainer")

        u_result = await db.execute(select(User).where(User.id == trainee_id))
        trainee = u_result.scalar_one_or_none()
        if not trainee or trainee.role != UserRole.TRAINEE:
            raise NotFoundError("Trainee")

        trainee.trainer_id = trainer.id
        await db.flush()
        await db.refresh(trainee)
        return trainee

    async def resend_verification(self, db: AsyncSession, redis_client: aioredis.Redis, email: str) -> None:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        
        if not user:
            raise NotFoundError("User")
        if user.is_verified:
            raise ConflictError("Email already verified")
            
        otp = str(random.randint(100000, 999999))
        await redis_client.set(f"verify_otp:{user.email}", otp, ex=OTP_EXPIRATION_SECONDS)
        
        await asyncio.to_thread(
            email_service.send_verification_email,
            user.email, user.full_name, otp
        )
    
    async def forgot_password(self, db: AsyncSession, redis_client: aioredis.Redis, payload: ForgotPasswordRequest) -> MessageResponse:
        result = await db.execute(select(User).where(User.email == payload.email))
        user = result.scalar_one_or_none()
        
        success_message = "If an account with that email exists, a password reset OTP has been sent."
        
        if not user:
            return MessageResponse(message=success_message)

        otp = str(random.randint(100000, 999999))
        
        await redis_client.set(f"reset_otp:{user.email}", otp, ex=OTP_EXPIRATION_SECONDS)

        try:
            await asyncio.to_thread(
                email_service.send_password_reset_email,
                user.email, user.full_name, otp
            )
        except Exception as e:
            print(f"[Email] Failed to send password reset email: {e}")

        return MessageResponse(message=success_message)

    async def reset_password(self, db: AsyncSession, redis_client: aioredis.Redis, payload: ResetPasswordRequest) -> MessageResponse:
        result = await db.execute(select(User).where(User.email == payload.email))
        user = result.scalar_one_or_none()
        
        if not user:
            raise AuthenticationError("Invalid email or OTP")

        stored_otp = await redis_client.get(f"reset_otp:{payload.email}")

        if not stored_otp:
            raise AuthenticationError("OTP has expired. Please request a new one.")
            
        if stored_otp != payload.otp:
            raise AuthenticationError("Invalid OTP")

        user.hashed_password = hash_password(payload.new_password)
        await db.flush()
        
        await redis_client.delete(f"reset_otp:{payload.email}")
        
        return MessageResponse(message="Your password has been reset successfully. You can now log in.")

    async def refresh(self, db: AsyncSession, refresh_token: str) -> TokenResponse:
        try:
            payload = decode_token(refresh_token)
        except JWTError:
            raise AuthenticationError("Invalid or expired refresh token")

        if payload.get("type") != "refresh":
            raise AuthenticationError("Token is not a refresh token")

        user_id = payload.get("sub")
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if not user or not user.is_active:
            raise AuthenticationError("User not found or inactive")

        return self._issue_tokens(user)

    async def get_current_user(self, db: AsyncSession, token: str) -> User:
        try:
            payload = decode_token(token)
        except JWTError:
            raise AuthenticationError()

        if payload.get("type") != "access":
            raise AuthenticationError("Invalid token type")

        user_id = payload.get("sub")
        result = await db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()

        if not user:
            raise AuthenticationError()
        if not user.is_active:
            raise ForbiddenError("Account is deactivated")

        return user

    def _issue_tokens(self, user: User) -> TokenResponse:
        access_token = create_access_token(subject=str(user.id), role=user.role.value)
        refresh_token = create_refresh_token(subject=str(user.id), role=user.role.value)
        return TokenResponse(access_token=access_token, refresh_token=refresh_token)


auth_service = AuthService()