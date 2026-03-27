# TrackMate

A fitness tracking platform connecting trainees with trainers, built with Flutter (frontend) and FastAPI (backend).

The production backend API is currently hosted and live on **Render**.

---

## Quick Start (Web)

It is very easy to get TrackMate running in your Chrome browser. Because the backend is already hosted on Render, you don't need to configure any databases or servers to try it out.

Just clone the repository, navigate to the frontend directory, and run it:

```bash
git clone https://github.com/your-username/trackmate.git
cd trackmate/mobile
flutter run -d chrome --web-port 3000
```

---

## Project Structure

```
trackmate/
├── mobile/          # Flutter app
└── backend/         # FastAPI backend
```

---

## Features

### Authentication
- Email/password registration with OTP email verification
- Account is inactive until email is verified
- Login derives role from database — no client-side role selection
- Cookie-based JWT authentication (httponly, secure)
- Automatic token refresh via Dio interceptor
- Logout clears session cookies

### Roles
| Role | Description |
|------|-------------|
| `trainee` | Default role on registration |
| `trainer` | Requires admin approval after applying |
| `admin` | Seeded from environment variables on startup |

### Trainer Application Flow
1. User registers with `apply_as_trainer: true`
2. Account is created with `trainer_status: pending`
3. Admin reviews and approves or rejects via API
4. On approval, role is updated to `trainer` and user receives an email notification
5. On rejection, user receives a rejection email

### Trainee–Trainer Assignment
- Admin can assign a trainer to any trainee
- Each trainee has one optional trainer (`trainer_id` foreign key)
- Only approved trainers can be assigned

### Email Notifications
| Trigger | Email sent |
|---------|-----------|
| Registration | OTP verification code (expires in 10 minutes) |
| Login attempt (unverified) | New OTP resent automatically |
| Trainer approved | Approval notification |
| Trainer rejected | Rejection notification |

---

## Deploying the Backend to Render

### Prerequisites
- A [Render](https://render.com) account
- A PostgreSQL database (Render's managed Postgres or external)
- A Gmail account with an [App Password](https://support.google.com/accounts/answer/185833) for SMTP

### Step 1 — Create a PostgreSQL Database on Render

1. In the Render dashboard, click **New → PostgreSQL**.
2. Choose a name (e.g., `trackmate-db`), region, and plan.
3. Once created, copy the **Internal Database URL** — you'll use this as `DATABASE_URL`.

> **Note:** Use the **Internal URL** (not the External URL) when your backend web service is in the same Render region. It is faster and does not incur egress charges.

### Step 2 — Create a Web Service on Render

1. Click **New → Web Service** and connect your GitHub repository.
2. Set the **Root Directory** to `backend`.
3. Configure the build and start commands:

| Setting | Value |
|---------|-------|
| **Environment** | Python 3 |
| **Build Command** | `pip install -r requirements.txt && alembic upgrade head` |
| **Start Command** | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |

> Render injects `$PORT` automatically — do **not** hardcode a port number.

### Step 3 — Set Environment Variables

In your web service's **Environment** tab, add the following variables:

```env
# Database
DATABASE_URL=<Internal PostgreSQL URL from Step 1 — use postgresql+asyncpg:// scheme>

# JWT
SECRET_KEY=<a random string, minimum 32 characters>
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Cookie  ← IMPORTANT for Render (HTTPS in production)
COOKIE_SECURE=true
COOKIE_SAMESITE=none

# App
APP_ENV=production
APP_HOST=0.0.0.0
APP_PORT=10000
CORS_ORIGINS=["https://your-flutter-app-domain.com"]

# Email (Gmail App Password)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=you@gmail.com
SMTP_PASSWORD=<your 16-character App Password>
EMAIL_FROM=you@gmail.com
EMAIL_FROM_NAME=TrackMate
FRONTEND_URL=https://your-flutter-app-domain.com

# Admin seed (created on startup if not exists)
ADMIN_EMAIL=admin@trackmate.com
ADMIN_PASSWORD=<strong password>
ADMIN_FULL_NAME=Admin
```

> ** DATABASE_URL scheme:** Render's connection string uses `postgresql://`. Change the scheme to `postgresql+asyncpg://` so SQLAlchemy's async driver works correctly.

### Step 4 — Deploy

Click **Deploy** (or push to your connected branch). Render will:
1. Install Python dependencies.
2. Run `alembic upgrade head` to apply all migrations.
3. Start the Uvicorn server.

The service URL will be something like `https://trackmate-backend.onrender.com`. API docs are **disabled in production** (`APP_ENV=production`).

### Step 5 — Point the Flutter App at the Render Backend

Update the base URL in your Flutter app's API client (e.g., `lib/core/network/api_client.dart` or your DI setup) to your Render service URL:

```dart
const String baseUrl = 'https://trackmate-backend.onrender.com';
```

### Free Tier Considerations

If you are using Render's **free tier**, note that web services spin down after 15 minutes of inactivity and take ~30 seconds to cold-start on the next request. To avoid this during development or demos, consider:
- Upgrading to a paid instance type, or
- Using an uptime-monitoring service (e.g., UptimeRobot) to ping the health endpoint periodically.

---

## Backend Local Setup

### Requirements
- Python 3.12+
- PostgreSQL
- Gmail account with App Password for SMTP

### Installation
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Environment Variables
Create a `.env` file in the `backend/` directory:
```env
# Database
DATABASE_URL=postgresql+asyncpg://postgres:password@localhost:5432/trackmate

# JWT
SECRET_KEY=your-secret-key-min-32-chars
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=30
REFRESH_TOKEN_EXPIRE_DAYS=7

# Cookie
COOKIE_SECURE=false
COOKIE_SAMESITE=lax

# App
APP_ENV=development
APP_HOST=0.0.0.0
APP_PORT=8000
CORS_ORIGINS=["http://localhost:3000"]

# Email (Gmail App Password)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=you@gmail.com
SMTP_PASSWORD=your_16_char_app_password
EMAIL_FROM=you@gmail.com
EMAIL_FROM_NAME=TrackMate
FRONTEND_URL=http://localhost:3000

# Admin seed (created on startup if not exists)
ADMIN_EMAIL=admin@trackmate.com
ADMIN_PASSWORD=AdminPass123
ADMIN_FULL_NAME=Admin
```

### Database Migration
```bash
alembic upgrade head
```

### Running the Backend
```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

API docs available at `http://localhost:8000/docs` in development mode.

---

## Frontend Setup

### Requirements
- Flutter 3.x
- Dart SDK >= 3.3.0

### Installation
```bash
cd mobile
flutter pub get
```

### Running on Web
```bash
flutter run -d chrome --web-port 3000
```

### Running on Android Emulator
```bash
flutter emulators --launch <emulator_id>
flutter run
```

---

## API Endpoints

### Auth
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/auth/register` | No | Register new account |
| POST | `/api/v1/auth/login` | No | Login |
| POST | `/api/v1/auth/logout` | Yes | Logout |
| POST | `/api/v1/auth/refresh` | Cookie | Refresh access token |
| GET | `/api/v1/auth/me` | Yes | Get current user |
| POST | `/api/v1/auth/verify-email` | No | Verify email with OTP |
| POST | `/api/v1/auth/resend-verification` | No | Resend OTP |

### Admin
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/auth/admin/trainer-applications` | Admin | Approve or reject trainer |
| POST | `/api/v1/auth/admin/assign-trainer` | Admin | Assign trainer to trainee |

---

## Database Schema

### Users Table
| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `email` | String | Unique, indexed |
| `hashed_password` | String | bcrypt hashed |
| `full_name` | String | |
| `role` | Enum | `trainee`, `trainer`, `admin` |
| `trainer_status` | Enum | `none`, `pending`, `approved`, `rejected` |
| `trainer_id` | UUID FK | Assigned trainer (nullable) |
| `is_active` | Boolean | False until email verified |
| `is_verified` | Boolean | Email verification status |
| `verification_otp` | String | 6-digit OTP (nullable) |
| `otp_expires_at` | DateTime | OTP expiry (nullable) |
| `created_at` | DateTime | |
| `updated_at` | DateTime | |

---

## Tech Stack

### Frontend
- Flutter + Dart
- `flutter_bloc` — state management
- `go_router` — navigation
- `dio` + `dio_cookie_manager` — HTTP client with cookie support
- `get_it` — dependency injection
- `dartz` — functional error handling

### Backend
- FastAPI
- SQLAlchemy (async) + PostgreSQL
- Alembic — migrations
- `python-jose` — JWT
- `passlib` + bcrypt — password hashing
- `pydantic-settings` — environment config
- smtplib — email delivery