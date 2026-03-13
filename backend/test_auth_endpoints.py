import pytest
from httpx import AsyncClient

REGISTER_URL = "/api/v1/auth/register"
LOGIN_URL = "/api/v1/auth/login"
REFRESH_URL = "/api/v1/auth/refresh"
ME_URL = "/api/v1/auth/me"
LOGOUT_URL = "/api/v1/auth/logout"


@pytest.mark.asyncio
async def test_register_success(client: AsyncClient):
    res = await client.post(REGISTER_URL, json={
        "email": "user@test.com",
        "password": "TestPass1",
        "full_name": "Test User",
        "role": "trainee",
    })
    assert res.status_code == 201
    data = res.json()
    assert "tokens" in data
    assert "user" in data
    assert data["user"]["email"] == "user@test.com"
    assert data["user"]["role"] == "trainee"

    # Cookies should be set for cookie-based authentication
    assert res.cookies.get("access_token")
    assert res.cookies.get("refresh_token")


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient):
    payload = {"email": "dup@test.com", "password": "TestPass1", "full_name": "Dup User", "role": "trainee"}
    await client.post(REGISTER_URL, json=payload)
    res = await client.post(REGISTER_URL, json=payload)
    assert res.status_code == 409


@pytest.mark.asyncio
async def test_login_success(client: AsyncClient):
    await client.post(REGISTER_URL, json={
        "email": "login@test.com", "password": "TestPass1",
        "full_name": "Login User", "role": "trainee",
    })
    res = await client.post(LOGIN_URL, json={
        "email": "login@test.com", "password": "TestPass1", "role": "trainee",
    })
    assert res.status_code == 200
    assert "access_token" in res.json()["tokens"]
    assert res.cookies.get("access_token")
    assert res.cookies.get("refresh_token")


@pytest.mark.asyncio
async def test_login_wrong_password(client: AsyncClient):
    await client.post(REGISTER_URL, json={
        "email": "wp@test.com", "password": "TestPass1",
        "full_name": "WP User", "role": "trainee",
    })
    res = await client.post(LOGIN_URL, json={
        "email": "wp@test.com", "password": "WrongPass1", "role": "trainee",
    })
    assert res.status_code == 401


@pytest.mark.asyncio
async def test_login_wrong_role(client: AsyncClient):
    await client.post(REGISTER_URL, json={
        "email": "role@test.com", "password": "TestPass1",
        "full_name": "Role User", "role": "trainee",
    })
    res = await client.post(LOGIN_URL, json={
        "email": "role@test.com", "password": "TestPass1", "role": "trainer",
    })
    assert res.status_code == 403


@pytest.mark.asyncio
async def test_get_me(client: AsyncClient):
    # Register and rely on cookie-based auth for subsequent requests
    await client.post(REGISTER_URL, json={
        "email": "me@test.com", "password": "TestPass1",
        "full_name": "Me User", "role": "trainee",
    })

    res = await client.get(ME_URL)
    assert res.status_code == 200
    assert res.json()["email"] == "me@test.com"


@pytest.mark.asyncio
async def test_refresh_token(client: AsyncClient):
    # Register and use the refresh cookie to obtain new tokens
    await client.post(REGISTER_URL, json={
        "email": "refresh@test.com", "password": "TestPass1",
        "full_name": "Refresh User", "role": "trainee",
    })

    res = await client.post(REFRESH_URL)
    assert res.status_code == 200
    assert "access_token" in res.json()


@pytest.mark.asyncio
async def test_logout(client: AsyncClient):
    # Register and logout using cookie-based auth
    await client.post(REGISTER_URL, json={
        "email": "logout@test.com", "password": "TestPass1",
        "full_name": "Logout User", "role": "trainee",
    })

    res = await client.post(LOGOUT_URL)
    assert res.status_code == 200
    assert res.json()["message"] == "Logged out successfully"
