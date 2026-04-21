from pydantic import BaseModel, field_validator, Field
from typing import Optional
from datetime import datetime
import uuid
from app.models.profile import Gender, ActivityLevel


class ProfileUpdateRequest(BaseModel):
    bio: Optional[str] = Field(default=None, max_length=2000)
    date_of_birth: Optional[datetime] = None
    gender: Optional[Gender] = None
    phone_number: Optional[str] = Field(default=None, max_length=20)
    height_cm: Optional[float] = None
    weight_kg: Optional[float] = None
    daily_step_goal: Optional[int] = None
    daily_calorie_goal: Optional[int] = None
    activity_level: Optional[ActivityLevel] = None
    specializations: Optional[str] = Field(default=None, max_length=500)
    certifications: Optional[str] = Field(default=None, max_length=500)
    experience_years: Optional[int] = None
    hourly_rate: Optional[float] = None

    @field_validator("height_cm")
    @classmethod
    def validate_height(cls, v: float | None) -> float | None:
        if v is not None and not (50 <= v <= 300):
            raise ValueError("Height must be between 50 and 300 cm")
        return v

    @field_validator("weight_kg")
    @classmethod
    def validate_weight(cls, v: float | None) -> float | None:
        if v is not None and not (20 <= v <= 500):
            raise ValueError("Weight must be between 20 and 500 kg")
        return v

    @field_validator("daily_step_goal")
    @classmethod
    def validate_steps(cls, v: int | None) -> int | None:
        if v is not None and not (1000 <= v <= 100000):
            raise ValueError("Step goal must be between 1000 and 100000")
        return v

    @field_validator("daily_calorie_goal")
    @classmethod
    def validate_calories(cls, v: int | None) -> int | None:
        if v is not None and not (500 <= v <= 10000):
            raise ValueError("Calorie goal must be between 500 and 10000")
        return v
        
    @field_validator("experience_years")
    @classmethod
    def validate_experience(cls, v: int | None) -> int | None:
        if v is not None and not (0 <= v <= 80):
            raise ValueError("Experience years must be between 0 and 80")
        return v

    @field_validator("hourly_rate")
    @classmethod
    def validate_hourly_rate(cls, v: float | None) -> float | None:
        if v is not None and not (0 <= v <= 100000):
            raise ValueError("Hourly rate must be realistic (0 to 100000)")
        return v


class ProfileResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    phone_number: Optional[str] = None
    profile_image_url: Optional[str]
    bio: Optional[str]
    date_of_birth: Optional[datetime]
    gender: Optional[Gender]
    height_cm: Optional[float]
    weight_kg: Optional[float]
    daily_step_goal: int
    daily_calorie_goal: Optional[int]
    activity_level: Optional[ActivityLevel]
    specializations: Optional[str]
    certifications: Optional[str]
    experience_years: Optional[int]
    hourly_rate: Optional[float] = None
    tdee: Optional[float] = None # calculated, not stored
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True, "use_enum_values": True}


class FullUserResponse(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str
    role: str
    trainer_status: str
    is_verified: bool
    profile: Optional[ProfileResponse]

    model_config = {"from_attributes": True, "use_enum_values": True}