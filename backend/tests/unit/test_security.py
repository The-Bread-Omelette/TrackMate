import pytest
from app.core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
)


def test_hash_password_produces_different_hashes():
    h1 = hash_password("TestPass1")
    h2 = hash_password("TestPass1")
    assert h1 != h2  # bcrypt salts differ


def test_verify_password_correct():
    hashed = hash_password("TestPass1")
    assert verify_password("TestPass1", hashed) is True


def test_verify_password_wrong():
    hashed = hash_password("TestPass1")
    assert verify_password("WrongPass1", hashed) is False


def test_access_token_decode():
    token = create_access_token(subject="user-123", role="trainee")
    payload = decode_token(token)
    assert payload["sub"] == "user-123"
    assert payload["role"] == "trainee"
    assert payload["type"] == "access"


def test_refresh_token_decode():
    token = create_refresh_token(subject="user-456", role="trainer")
    payload = decode_token(token)
    assert payload["sub"] == "user-456"
    assert payload["type"] == "refresh"


def test_invalid_token_raises():
    from jose import JWTError
    with pytest.raises(JWTError):
        decode_token("not.a.valid.token")
