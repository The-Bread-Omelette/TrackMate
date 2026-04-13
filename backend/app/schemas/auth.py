from pydantic import BaseModel, EmailStr, field_validator
from typing import Optional
import uuid
from app.models.user import UserRole, TrainerStatus


class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    full_name: str
    # role is NOT accepted from client — everyone registers as trainee
    # set apply_as_trainer=True to enter the trainer approval queue
    apply_as_trainer: bool = False

    @field_validator('email')
    @classmethod
    def email_to_lower(cls, v: str) -> str:
        return v.lower()
    
    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if not any(c.isupper() for c in v):
            raise ValueError("Password must contain at least one uppercase letter")
        if not any(c.isdigit() for c in v):
            raise ValueError("Password must contain at least one digit")
        return v

    @field_validator("full_name")
    @classmethod
    def validate_full_name(cls, v: str) -> str:
        v = v.strip()
        if len(v) < 2:
            raise ValueError("Full name must be at least 2 characters")
        return v


class LoginRequest(BaseModel):
    email: EmailStr
    password: str
    
    @field_validator('email')
    @classmethod
    def email_to_lower(cls, v: str) -> str:
        return v.lower()
    # No role field — role is derived from DB

    
class UserResponse(BaseModel):
    id: uuid.UUID
    email: str
    full_name: str
    role: UserRole
    trainer_status: TrainerStatus
    trainer_id: Optional[uuid.UUID]
    is_active: bool
    is_verified: bool

    model_config = {
        "from_attributes": True,
        "use_enum_values": True,
    }

class MessageResponse(BaseModel):
    message: str


class ApproveTrainerRequest(BaseModel):
    user_id: uuid.UUID
    approve: bool  # True = approve, False = reject
    
class ResendVerificationRequest(BaseModel):
    email: EmailStr
    @field_validator('email')
    @classmethod
    def email_to_lower(cls, v: str) -> str:
        return v.lower()
    
class VerifyEmailRequest(BaseModel):
    email: EmailStr
    otp: str
    @field_validator('email')
    @classmethod
    def email_to_lower(cls, v: str) -> str:
        return v.lower()
    

    @field_validator("otp")
    @classmethod
    def validate_otp(cls, v: str) -> str:
        if not v.isdigit() or len(v) != 6:
            raise ValueError("OTP must be a 6-digit number")
        return v
    
class ForgotPasswordRequest(BaseModel):
    email: EmailStr
    @field_validator('email')
    @classmethod
    def email_to_lower(cls, v: str) -> str:
        return v.lower()

class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str
    new_password: str
    @field_validator('email')
    @classmethod
    def email_to_lower(cls, v: str) -> str:
        return v.lower()
    
class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str