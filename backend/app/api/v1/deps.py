from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.base import get_db
from app.models.user import User, UserRole
from app.services.auth_service import auth_service
from app.core.exceptions import ForbiddenError, AuthenticationError


async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db),
) -> User:
    # Support both Authorization header and cookie-based authentication.
    token = None

    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.lower().startswith("bearer "):
        token = auth_header.split(" ", 1)[1]
    else:
        token = request.cookies.get("access_token")

    if not token:
        raise AuthenticationError()

    return await auth_service.get_current_user(db, token)


async def require_trainee(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.TRAINEE:
        raise ForbiddenError("Trainee access required")
    return current_user


async def require_trainer(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.TRAINER:
        raise ForbiddenError("Trainer access required")
    return current_user


async def require_admin(current_user: User = Depends(get_current_user)) -> User:
    if current_user.role != UserRole.ADMIN:
        raise ForbiddenError("Admin access required")
    return current_user
