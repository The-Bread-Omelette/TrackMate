from fastapi import APIRouter, Depends, status, Response, Request, Cookie, Body
from sqlalchemy.ext.asyncio import AsyncSession
import redis.asyncio as aioredis
import uuid


from app.db.base import get_db
from app.schemas.auth import (
    RegisterRequest, LoginRequest, TokenResponse,
    UserResponse, MessageResponse, 
    ResendVerificationRequest, VerifyEmailRequest, ForgotPasswordRequest, ResetPasswordRequest
)
from app.services.auth_service import auth_service
from app.api.v1.deps import get_current_user, require_admin
from app.core.redis import get_redis 
from app.models.user import User
from app.core.config import settings
from app.core.exceptions import AuthenticationError, ConflictError

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _set_auth_cookies(response: Response, tokens: TokenResponse) -> None:
    secure = settings.COOKIE_SECURE
    same_site = settings.COOKIE_SAMESITE.lower()
    if same_site not in ("none", "lax", "strict"):
        same_site = "lax"
    if same_site == "none" and not secure:
        same_site = "lax"

    response.set_cookie(
        key="access_token", value=tokens.access_token,
        httponly=True, secure=secure, samesite=same_site,
        max_age=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60, path="/",
    )
    response.set_cookie(
        key="refresh_token", value=tokens.refresh_token,
        httponly=True, secure=secure, samesite=same_site,
        max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60, path="/",
    )


def _clear_auth_cookies(response: Response) -> None:
    response.delete_cookie("access_token", path="/")
    response.delete_cookie("refresh_token", path="/")


@router.post("/register", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
async def register(
    payload: RegisterRequest,
    db: AsyncSession = Depends(get_db),
    redis_client: aioredis.Redis = Depends(get_redis),
) -> MessageResponse:
    return await auth_service.register(db, redis_client, payload)


@router.post("/login", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def login(
    payload: LoginRequest, response: Response, db: AsyncSession = Depends(get_db),
) -> UserResponse:
    user, tokens = await auth_service.login(db, payload)
    _set_auth_cookies(response, tokens) 
    return UserResponse.model_validate(user)


@router.post("/refresh", response_model=MessageResponse, status_code=status.HTTP_200_OK)
async def refresh_token(
    response: Response,
    body: dict = Body(default={}),
    refresh_token_cookie: str | None = Cookie(default=None, alias="refresh_token"),
    db: AsyncSession = Depends(get_db),
) -> MessageResponse:
    token = body.get("refresh_token") or refresh_token_cookie
    if not token:
        raise AuthenticationError("Refresh token required")
    new_tokens = await auth_service.refresh(db, token)
    _set_auth_cookies(response, new_tokens)
    return MessageResponse(message="Session refreshed")


@router.get("/me", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def get_me(current_user: User = Depends(get_current_user)) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.post("/logout", response_model=MessageResponse, status_code=status.HTTP_200_OK)
async def logout(
    response: Response, current_user: User = Depends(get_current_user),
) -> MessageResponse:
    _clear_auth_cookies(response)
    return MessageResponse(message="Logged out successfully")


@router.post("/verify-email", response_model=UserResponse, status_code=status.HTTP_200_OK)
async def verify_email(
    payload: VerifyEmailRequest,
    response: Response,
    db: AsyncSession = Depends(get_db),
    redis_client: aioredis.Redis = Depends(get_redis),
) -> UserResponse:
    user, tokens = await auth_service.verify_email(db, redis_client, payload.email, payload.otp)
    _set_auth_cookies(response, tokens)
    return UserResponse.model_validate(user)

@router.post("/resend-verification", response_model=MessageResponse, status_code=status.HTTP_200_OK)
async def resend_verification(
    payload: ResendVerificationRequest,
    db: AsyncSession = Depends(get_db),
    redis_client: aioredis.Redis = Depends(get_redis),
) -> MessageResponse:
    await auth_service.resend_verification(db, redis_client, payload.email)
    return MessageResponse(message="Verification email sent")


@router.post("/forgot-password", response_model=MessageResponse, status_code=status.HTTP_200_OK)
async def forgot_password(
    payload: ForgotPasswordRequest, 
    db: AsyncSession = Depends(get_db),
    redis_client: aioredis.Redis = Depends(get_redis),
):
    return await auth_service.forgot_password(db, redis_client, payload)


@router.post("/reset-password", response_model=MessageResponse, status_code=status.HTTP_200_OK)
async def reset_password(
    payload: ResetPasswordRequest, 
    db: AsyncSession = Depends(get_db),
    redis_client: aioredis.Redis = Depends(get_redis),
):
    return await auth_service.reset_password(db, redis_client, payload)