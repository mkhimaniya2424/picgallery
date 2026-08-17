import enum
import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Boolean, Date, DateTime, Enum, Integer, Numeric, String, Text, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class UserRole(str, enum.Enum):
    """Mirrors the `UserRole` enum in the Flutter app (app_routes.dart)."""
    photographer = "photographer"
    client = "client"


class AuthProvider(str, enum.Enum):
    """How this account authenticates. `local` = email/password (the
    original flow); `google`/`apple` = Sign in with Google/Apple, whose
    ID tokens are verified server-side in `core/social_auth.py` instead
    of checking a password."""
    local = "local"
    google = "google"
    apple = "apple"


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        # Same email can register once as a client AND once as a
        # photographer — just not twice under the same role. Replaces
        # the old plain unique=True on `email`.
        UniqueConstraint("email", "role", name="uq_users_email_role"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)

    # Step 1 — identity
    full_name: Mapped[str] = mapped_column(String(150), nullable=False)
    email: Mapped[str] = mapped_column(String(255), index=True, nullable=False)
    # `phone` was removed as a feature (column dropped from the DB
    # directly) — kept out of the ORM model entirely so SELECT/INSERT
    # never reference a column that no longer exists.

    # Step 2 — auth. Nullable because Google/Apple sign-in accounts have
    # no password at all — the provider's ID token is the credential
    # instead (see auth_provider/provider_user_id below and
    # core/social_auth.py).
    hashed_password: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Role
    role: Mapped[UserRole] = mapped_column(Enum(UserRole, name="user_role"), nullable=False)

    # Sign in with Google / Sign in with Apple. auth_provider records how
    # the account was created; provider_user_id is the stable subject
    # ("sub") claim from that provider's verified ID token, used to
    # re-recognize the same external account on later sign-ins.
    auth_provider: Mapped[AuthProvider] = mapped_column(
        Enum(AuthProvider, name="auth_provider"), nullable=False, default=AuthProvider.local
    )
    provider_user_id: Mapped[str | None] = mapped_column(String(255), nullable=True, index=True)

    # Step 3 — photographer-only studio details (nullable for clients)
    studio_name: Mapped[str | None] = mapped_column(String(150), nullable=True)
    studio_address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    business_type: Mapped[str | None] = mapped_column(String(100), nullable=True)

    # Complete Profile step — shared by both roles
    avatar_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Studio cover photo (Showcase Portfolio feature) — the wide banner
    # image shown at the top of a studio's public profile. Same
    # convention as avatar_url: stores the full public URL, built via
    # build_media_url() at upload time. Nullable/unset for clients.
    cover_image_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    country: Mapped[str | None] = mapped_column(String(100), nullable=True)
    state: Mapped[str | None] = mapped_column(String(100), nullable=True)
    city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    address: Mapped[str | None] = mapped_column(String(255), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Complete Profile step — photographer-only Studio business details.
    # Comma-separated tags from the fixed set in the Flutter app
    # (kStudioSpecializations: Wedding, Portrait, Event, Product).
    specializations: Mapped[str | None] = mapped_column(String(255), nullable=True)

    # Studio profile fields (Task 3) — photographer ("Studio") role only,
    # always nullable/unset for client accounts. List-type fields follow
    # the same convention as `specializations` above: stored as a
    # comma-separated string, exposed to the API as a list.
    year_established: Mapped[int | None] = mapped_column(Integer, nullable=True)
    team_size: Mapped[int | None] = mapped_column(Integer, nullable=True)
    service_areas: Mapped[str | None] = mapped_column(String(500), nullable=True)
    studio_type: Mapped[str | None] = mapped_column(String(100), nullable=True)
    experience_years: Mapped[int | None] = mapped_column(Integer, nullable=True)
    languages: Mapped[str | None] = mapped_column(String(255), nullable=True)
    equipment_highlights: Mapped[str | None] = mapped_column(Text, nullable=True)
    pricing_min: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    pricing_max: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    package_details: Mapped[str | None] = mapped_column(Text, nullable=True)
    availability_days: Mapped[str | None] = mapped_column(String(255), nullable=True)
    instagram_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    facebook_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    youtube_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    pinterest_url: Mapped[str | None] = mapped_column(String(500), nullable=True)

    # Client optional profile fields (Task 4) — client role only, always
    # nullable/unset for photographer accounts. `preferred_photo_types`
    # follows the same comma-separated-string convention as
    # `specializations`/`service_areas` above.
    profile_photo_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    gender: Mapped[str | None] = mapped_column(String(20), nullable=True)
    date_of_birth: Mapped[date | None] = mapped_column(Date, nullable=True)
    preferred_photo_types: Mapped[str | None] = mapped_column(String(255), nullable=True)
    preferred_city: Mapped[str | None] = mapped_column(String(100), nullable=True)
    budget_min: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)
    budget_max: Mapped[Decimal | None] = mapped_column(Numeric(10, 2), nullable=True)

    agreed_to_terms: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_email_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # Soft delete (Task 10 — Delete Account). `is_deleted` is checked by
    # `get_current_user` (app/api/deps.py) so any access token issued
    # before deletion is rejected on its very next use — there's no
    # separate token/session store in this app, so this flag doubles as
    # the revocation mechanism. `deleted_at` records when. The row is
    # never physically removed (keeps FK history from other tables
    # intact); the email is anonymized at delete time instead (see
    # DELETE /users/me) so the address is freed up for the person to
    # register a brand new account with it.
    is_deleted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Email verification (item 21 — Verification Pending screen / Resend
    # Email on both verification screens). A fresh token is generated on
    # register and again on every "Resend Email" tap; POST /auth/verify-email
    # consumes it and flips is_email_verified.
    email_verification_token: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    email_verification_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Forgot/Reset Password flow (Task 11). Mirrors the email-verification
    # token pattern exactly: a fresh token is generated on every
    # POST /auth/forgot-password call and consumed by POST /auth/reset-password,
    # which also enforces the same TTL check as verify_email.
    reset_password_token: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    reset_password_sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    # Onboarding permission prompts (items 15-17 — Camera / Photo Library /
    # Push Notification screens). Dummy-only: no real OS permission is ever
    # checked, this just records which button the user tapped so the rest
    # of the app can read a stable "did they say yes" flag later.
    camera_permission_granted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    photo_library_permission_granted: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    push_notifications_enabled: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # Privacy & Security screen — "Download Permissions" toggle. Whether
    # this user allows their galleries/media to be downloaded. Defaults
    # to True (opt-out rather than opt-in) since download was always
    # available before this setting existed.
    allow_downloads: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)

    # App Settings screen — "App Language" picker. Distinct from
    # `languages` above (the studio's spoken-language tags shown on its
    # public profile) — this is the user's own UI language preference.
    app_language: Mapped[str] = mapped_column(String(30), default="English", nullable=False)

    # Subscription / billing fields — added via SQL migration (not yet in
    # alembic), matching the columns already present in the database.
    # plan_status: "active" | "inactive" | "expired"  (DB: varchar, NOT NULL)
    # plan_expiry: when the current plan ends  (DB: timestamp)
    # trial_used: whether the free trial has been consumed  (DB: bool)
    # plan_started_at: when the current plan was activated  (DB: timestamptz)
    #
    # plan_status is NOT NULL at the database level even though it was
    # previously typed as nullable here — that mismatch let new-user
    # INSERTs (signup, Google/Apple sign-in) fail with a NotNullViolation
    # since nothing set this column. default="inactive" covers any other
    # code path that constructs a User() without setting it explicitly.
    current_plan: Mapped[str | None] = mapped_column(String(20), nullable=True)
    plan_status: Mapped[str] = mapped_column(String(20), nullable=False, default="inactive", server_default="inactive")
    plan_expiry: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    trial_used: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    plan_started_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now(), onupdate=func.now()
    )