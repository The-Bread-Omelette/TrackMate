import pytest
from pydantic import ValidationError
from app.schemas.auth import RegisterRequest, LoginRequest
from app.models.user import UserRole


def test_register_valid():
    req = RegisterRequest(
        email="test@example.com",
        password="TestPass1",
        full_name="John Doe",
        role=UserRole.TRAINEE,
    )
    assert req.email == "test@example.com"


def test_register_short_password():
    with pytest.raises(ValidationError, match="at least 8 characters"):
        RegisterRequest(email="a@b.com", password="Abc1", full_name="John Doe")


def test_register_no_uppercase():
    with pytest.raises(ValidationError, match="uppercase"):
        RegisterRequest(email="a@b.com", password="testpass1", full_name="John Doe")


def test_register_no_digit():
    with pytest.raises(ValidationError, match="digit"):
        RegisterRequest(email="a@b.com", password="TestPassword", full_name="John Doe")


def test_register_invalid_email():
    with pytest.raises(ValidationError):
        RegisterRequest(email="not-an-email", password="TestPass1", full_name="John Doe")


def test_register_short_name():
    with pytest.raises(ValidationError, match="2 characters"):
        RegisterRequest(email="a@b.com", password="TestPass1", full_name="J")
