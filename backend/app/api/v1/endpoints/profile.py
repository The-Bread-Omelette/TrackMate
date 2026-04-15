from fastapi import APIRouter, Depends, status, Query
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.base import get_db
from app.api.v1.deps import get_current_user
from app.models.user import User,  UserRole
from app.schemas.profile import ProfileUpdateRequest, ProfileResponse, FullUserResponse
from app.services.profile_service import profile_service
from app.schemas.auth import UserResponse
from sqlalchemy import select, and_, or_

router = APIRouter(prefix="/profile", tags=["Profile"])


@router.get(
    "/users/search",
    response_model=list[UserResponse],
    status_code=status.HTTP_200_OK,
    summary="Search users by name or email",
)
async def search_users(
    q: str = Query(..., min_length=2, max_length=50),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> list[UserResponse]:
    result = await db.execute(
        select(User).where(
            and_(
                User.id != current_user.id,
                User.is_active == True,
                User.is_verified == True,
                or_(
                    User.full_name.ilike(f"%{q}%"),
                    User.email.ilike(f"%{q}%"),
                )
            )
        ).limit(20)
    )
    users = result.scalars().all()
    return [UserResponse.model_validate(u) for u in users]

@router.get(
    "/me",
    response_model=FullUserResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current user with profile",
)
async def get_my_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> FullUserResponse:
    profile = await profile_service.get_or_create_profile(db, current_user)
    tdee = profile_service.calculate_tdee(profile)
    profile_data = ProfileResponse.model_validate(profile)
    profile_data.tdee = tdee
    return FullUserResponse(
        id=current_user.id,
        email=current_user.email,
        full_name=current_user.full_name,
        role=current_user.role.value,
        trainer_status=current_user.trainer_status.value,
        is_verified=current_user.is_verified,
        profile=profile_data,
    )


@router.put(
    "/me",
    response_model=ProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Update current user profile",
)
async def update_my_profile(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ProfileResponse:
    profile = await profile_service.update_profile(db, current_user, payload)
    tdee = profile_service.calculate_tdee(profile)
    response = ProfileResponse.model_validate(profile)
    response.tdee = tdee
    return response


@router.get(
    "/me/biometrics",
    response_model=ProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Get biometrics and goals",
)
async def get_biometrics(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ProfileResponse:
    profile = await profile_service.get_or_create_profile(db, current_user)
    tdee = profile_service.calculate_tdee(profile)
    response = ProfileResponse.model_validate(profile)
    response.tdee = tdee
    return response


@router.put(
    "/me/biometrics",
    response_model=ProfileResponse,
    status_code=status.HTTP_200_OK,
    summary="Update biometrics and goals",
)
async def update_biometrics(
    payload: ProfileUpdateRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> ProfileResponse:
    profile = await profile_service.update_profile(db, current_user, payload)
    tdee = profile_service.calculate_tdee(profile)
    response = ProfileResponse.model_validate(profile)
    response.tdee = tdee
    return response