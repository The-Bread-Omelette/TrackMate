from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from jose import JWTError

from app.models.user import User, UserRole
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, UserResponse, AuthResponse
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.core.exceptions import AuthenticationError, ConflictError, NotFoundError, ForbiddenError


class AuthService:

    async def register(self, db: AsyncSession, payload: RegisterRequest) -> AuthResponse:
        # Check for existing email
        result = await db.execute(select(User).where(User.email == payload.email))
        existing = result.scalar_one_or_none()
        if existing:
            raise ConflictError("An account with this email already exists")

        user = User(
            email=payload.email,
            hashed_password=hash_password(payload.password),
            full_name=payload.full_name,
            role=payload.role,
            is_active=True,
            is_verified=False,  # email verification can be added later
        )
        db.add(user)
        await db.flush()  # get the generated id without committing
        await db.refresh(user)

        tokens = self._issue_tokens(user)
        return AuthResponse(
            user=UserResponse.model_validate(user),
            tokens=tokens,
        )

    async def login(self, db: AsyncSession, payload: LoginRequest) -> AuthResponse:
        result = await db.execute(select(User).where(User.email == payload.email))
        user = result.scalar_one_or_none()

        if not user or not verify_password(payload.password, user.hashed_password):
            raise AuthenticationError("Invalid email or password")

        if not user.is_active:
            raise ForbiddenError("Account is deactivated. Please contact support.")

        # Validate role matches what was selected on the login screen
        if user.role != payload.role:
            raise ForbiddenError("Incorrect role selected for this account")

        tokens = self._issue_tokens(user)
        return AuthResponse(
            user=UserResponse.model_validate(user),
            tokens=tokens,
        )

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
