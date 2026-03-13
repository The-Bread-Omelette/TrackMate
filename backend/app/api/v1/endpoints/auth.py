from fastapi import APIRouter, Depends, status, Response, Request, Cookie, Body
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.base import get_db
from app.schemas.auth import (
    RegisterRequest,
    LoginRequest,
    RefreshTokenRequest,
    AuthResponse,
    TokenResponse,
    UserResponse,
    MessageResponse,
)
from app.services.auth_service import auth_service
from app.api.v1.deps import get_current_user
from app.models.user import User
from app.core.config import settings
from app.core.exceptions import AuthenticationError

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _set_auth_cookies(response: Response, tokens: TokenResponse) -> None:
    # Control cookie security via env vars (COOKIE_SECURE, COOKIE_SAMESITE)
    secure = settings.COOKIE_SECURE
    same_site = settings.COOKIE_SAMESITE.lower()
    if same_site not in ("none", "lax", "strict"):
        same_site = "lax"

    # Modern browsers require Secure=True for SameSite=None.
    if same_site == "none" and not secure:
        # Fallback to Lax when Secure is not enabled to avoid cookie rejection.
        same_site = "lax"

    response.set_cookie(
        key="access_token",
        value=tokens.access_token,
        httponly=True,
        secure=secure,
        samesite=same_site,
        max_age=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        path="/",
    )
    response.set_cookie(
        key="refresh_token",
        value=tokens.refresh_token,
        httponly=True,
        secure=secure,
        samesite=same_site,
        max_age=settings.REFRESH_TOKEN_EXPIRE_DAYS * 24 * 60 * 60,
        path="/",
    )


def _clear_auth_cookies(response: Response) -> None:
    response.delete_cookie("access_token", path="/")
    response.delete_cookie("refresh_token", path="/")


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a new user",
)
async def register(
    payload: RegisterRequest,
    response: Response,
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    auth = await auth_service.register(db, payload)
    _set_auth_cookies(response, auth.tokens)
    return auth


@router.post(
    "/login",
    response_model=AuthResponse,
    status_code=status.HTTP_200_OK,
    summary="Login with email, password, and role",
)
async def login(
    payload: LoginRequest,
    response: Response,
    db: AsyncSession = Depends(get_db),
) -> AuthResponse:
    auth = await auth_service.login(db, payload)
    _set_auth_cookies(response, auth.tokens)
    return auth


@router.post(
    "/refresh",
    response_model=TokenResponse,
    status_code=status.HTTP_200_OK,
    summary="Refresh access token",
)
async def refresh_token(
    response: Response,
    refresh_token: str | None = Cookie(default=None),
    payload: RefreshTokenRequest | None = Body(default=None),
    db: AsyncSession = Depends(get_db),
) -> TokenResponse:
    token = refresh_token or (payload.refresh_token if payload else None)
    if not token:
        raise AuthenticationError("Refresh token required")

    tokens = await auth_service.refresh(db, token)
    _set_auth_cookies(response, tokens)
    return tokens


@router.get(
    "/me",
    response_model=UserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current authenticated user",
)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> UserResponse:
    return UserResponse.model_validate(current_user)


@router.post(
    "/logout",
    response_model=MessageResponse,
    status_code=status.HTTP_200_OK,
    summary="Logout (client-side token invalidation)",
)
async def logout(
    response: Response,
    current_user: User = Depends(get_current_user),
) -> MessageResponse:
    _clear_auth_cookies(response)
    # Stateless JWT: logout is handled by clearing cookies client-side.
    return MessageResponse(message="Logged out successfully")
