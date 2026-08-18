# PicGallery Backend

FastAPI + PostgreSQL backend for the PicGallery Flutter app.

**Stack**
- Flutter → Frontend (`../picgallery`)
- FastAPI → Python backend
- PostgreSQL → Database
- SQLAlchemy → ORM
- psycopg (v3) → PostgreSQL driver

## 1. Prerequisites

- Python 3.11+
- PostgreSQL running locally (or a connection string to a remote instance)

## 2. Setup

```bash
cd backend
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt

cp .env.example .env
# edit .env with your real DB credentials / secret key
```

Create the database (if it doesn't exist yet):

```bash
createdb picgallery
# or, from psql:
# CREATE DATABASE picgallery;
```

## 3. Run migrations

```bash
alembic revision --autogenerate -m "create users table"
alembic upgrade head
```

## 4. Run the API

```bash
uvicorn app.main:app --reload
```

- API root: http://127.0.0.1:8000
- Interactive docs (Swagger): http://127.0.0.1:8000/docs
- Health check: http://127.0.0.1:8000/health

## 5. Endpoints implemented so far

Matches the Flutter app's 3-step Create Account screen and login screen:

| Method | Path                    | Description                          |
|--------|-------------------------|---------------------------------------|
| POST   | `/api/v1/auth/register` | Create account (client or photographer) |
| POST   | `/api/v1/auth/login`    | Log in, returns a JWT                |
| GET    | `/api/v1/auth/me`       | Current user (requires Bearer token) |

`POST /api/v1/auth/register` body:

```json
{
  "full_name": "Jane Doe",
  "email": "jane@example.com",
  // "phone": "+1 555 0100",
  "password": "secret123",
  "role": "client",
  "agreed_to_terms": true
}
```

For `role: "photographer"`, also include `studio_name` (required), plus optional
`studio_address` and `business_type`.

## 6. Project layout

```
backend/
  app/
    core/       # settings, security (hashing, JWT)
    db/         # SQLAlchemy engine/session, declarative base
    models/     # SQLAlchemy models (User, ...)
    schemas/    # Pydantic request/response models
    api/        # routers + shared dependencies
    main.py     # FastAPI app entrypoint
  alembic/      # DB migrations
  requirements.txt
  .env.example
```

## 7. Connecting Flutter to this API

In the Flutter app, point your API base URL at this server, e.g.
`http://10.0.2.2:8000/api/v1` for the Android emulator, or
`http://127.0.0.1:8000/api/v1` for iOS simulator / web. A `services/`
folder already exists in the Flutter project (`lib/services`) — that's
where an `ApiClient`/`AuthService` calling these endpoints would live.
