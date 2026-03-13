# TrackMate

Fitness tracking platform — Flutter mobile app + FastAPI backend.

---

## Project Structure

```
trackmate/
├── backend/                  # FastAPI backend
│   ├── app/
│   │   ├── api/v1/
│   │   │   ├── endpoints/    # Route handlers
│   │   │   ├── deps.py       # FastAPI dependencies (auth guards)
│   │   │   └── router.py
│   │   ├── core/
│   │   │   ├── config.py     # Pydantic settings
│   │   │   ├── security.py   # JWT + bcrypt
│   │   │   └── exceptions.py
│   │   ├── db/
│   │   │   └── base.py       # SQLAlchemy async engine + session
│   │   ├── models/
│   │   │   └── user.py       # SQLAlchemy ORM model
│   │   ├── schemas/
│   │   │   └── auth.py       # Pydantic request/response schemas
│   │   ├── services/
│   │   │   └── auth_service.py
│   │   └── main.py
│   ├── alembic/              # DB migrations
│   ├── tests/
│   │   ├── unit/
│   │   └── integration/
│   ├── requirements.txt
│   ├── Dockerfile
│   └── .env.example
│
├── mobile/                   # Flutter app
│   ├── lib/
│   │   ├── core/
│   │   │   ├── constants/    # API URLs, storage keys
│   │   │   ├── di/           # GetIt dependency injection
│   │   │   ├── errors/       # Failure types + Dio error mapper
│   │   │   ├── network/      # Dio client + auth interceptor
│   │   │   └── router/       # GoRouter setup
│   │   ├── features/
│   │   │   └── auth/
│   │   │       ├── data/     # Models, datasources, repository impl
│   │   │       ├── domain/   # Entities, repository interface
│   │   │       └── presentation/  # BLoC + Pages + Widgets
│   │   ├── shared/
│   │   │   ├── theme/        # AppTheme, AppColors
│   │   │   └── widgets/      # RoleSelector, TmTextField
│   │   └── main.dart
│   └── pubspec.yaml
│
└── docker-compose.yml
```

---

## Quick Start

### 1. Backend

```bash
cd backend

# Start PostgreSQL
docker-compose up db -d

# Install dependencies
pip install -r requirements.txt

# Copy env
cp .env.example .env

# Run migrations
alembic upgrade head

# Start API
uvicorn app.main:app --reload
# Docs at http://localhost:8000/docs
```

### Or with Docker (full stack)
```bash
docker-compose up --build
```

### 2. Run Tests

```bash
cd backend
pip install aiosqlite  # for in-memory test DB
pytest -v
```

### 3. Flutter App

```bash
cd mobile
flutter pub get
flutter run
```

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/v1/auth/register` | Register new user |
| POST | `/api/v1/auth/login` | Login (returns JWT pair) |
| POST | `/api/v1/auth/refresh` | Refresh access token |
| GET | `/api/v1/auth/me` | Get current user |
| POST | `/api/v1/auth/logout` | Logout |
| GET | `/health` | Health check |

---

## Auth Flow

1. User selects role (Trainee / Trainer / Admin) and submits credentials
2. Backend validates credentials + role match, returns `access_token` + `refresh_token`
3. Flutter stores tokens in `flutter_secure_storage` (encrypted)
4. Dio interceptor attaches `Bearer` token to every request automatically
5. On 401, interceptor attempts silent refresh before re-routing to login

---

## Environment Variables (Backend)

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL async URL |
| `SECRET_KEY` | JWT signing key (min 32 chars) |
| `ALGORITHM` | JWT algorithm (default: HS256) |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | Access token TTL |
| `REFRESH_TOKEN_EXPIRE_DAYS` | Refresh token TTL |
| `APP_ENV` | `development` or `production` |
| `CORS_ORIGINS` | JSON array of allowed origins |
