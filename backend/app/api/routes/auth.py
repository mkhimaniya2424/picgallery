import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.core.email import send_verification_email as deliver_verification_email
from app.core.email import send_password_reset_email as deliver_password_reset_email
from app.core.security import create_access_token, hash_password, verify_password
from app.core.social_auth import (
    SocialIdentity,
    verify_apple_identity_token,
    verify_google_id_token,
)
from app.db.session import get_db
from app.models.connection import ConnectionInitiator, ConnectionStatus, StudioClientConnection
from app.models.email_invitation import EmailInvitation
from app.models.notification import Notification, NotificationType
from app.models.user import AuthProvider, User, UserRole
from app.schemas.user import (
    ForgotPasswordRequest,
    MessageResponse,
    ResetPasswordRequest,
    SocialLoginRequest,
    Token,
    UserCompleteProfile,
    UserLogin,
    UserRead,
    UserRegister,
    UserUpdatePermissions,
    VerifyEmailRequest,
)

router = APIRouter(prefix="/auth", tags=["auth"])

# How long a (dummy) verification token stays valid before Resend Email
# is needed again.
VERIFICATION_TOKEN_TTL = timedelta(hours=24)

# How long a (dummy) password-reset token stays valid — shorter than
# email verification since it grants a password change, not just a
# "yes this inbox is mine" confirmation.
RESET_PASSWORD_TOKEN_TTL = timedelta(hours=1)


def _generate_verification_token() -> str:
    return secrets.token_urlsafe(32)


def _generate_reset_code() -> str:
    # Deliberately short and numeric (unlike the long verification
    # token) — the Flutter app has no deep-link handling, so the user
    # has to type this in by hand on ResetPasswordScreen.
    return f"{secrets.randbelow(1_000_000):06d}"


def _consume_email_invitations(db: Session, client: User) -> None:
    """Turns every unconsumed `EmailInvitation` matching `client`'s email
    into a real, pending `StudioClientConnection` — the other half of
    `POST /connections/invite-by-email` in `connections.py`: a studio
    inviting an email with no account yet just records the invite and
    emails them to sign up, and *this* is what makes that promise real
    the moment they do. Each becomes a normal studio-initiated pending
    invite, so it shows up on the client's Invitations screen exactly
    like any other studio invite — nothing auto-accepts.

    Only meaningful for client signups; a photographer registering
    with the same email as some studio's invited-client address isn't
    what any invite meant, so callers should only call this when
    `client.role == UserRole.client`.
    """
    invitations = db.execute(
        select(EmailInvitation).where(
            EmailInvitation.email == client.email.strip().lower(),
            EmailInvitation.consumed_at.is_(None),
        )
    ).scalars().all()

    for invite in invitations:
        studio = db.get(User, invite.studio_id)
        if studio is None or studio.is_deleted:
            invite.consumed_at = datetime.now(timezone.utc)
            continue

        # A studio could in theory have both invited this email cold
        # AND already have a connection row with this client from some
        # other path — skip creating a duplicate if one somehow exists.
        existing = db.execute(
            select(StudioClientConnection).where(
                StudioClientConnection.studio_id == studio.id,
                StudioClientConnection.client_id == client.id,
            )
        ).scalar_one_or_none()

        if existing is None:
            connection = StudioClientConnection(
                studio_id=studio.id,
                client_id=client.id,
                status=ConnectionStatus.pending,
                initiated_by=ConnectionInitiator.studio,
            )
            db.add(connection)
            db.flush()

            studio_name = studio.studio_name or studio.full_name
            db.add(
                Notification(
                    user_id=client.id,
                    type=NotificationType.connection,
                    title="New connection invitation",
                    subtitle=f"{studio_name} wants to connect with you.",
                    data={"connection_id": str(connection.id)},
                )
            )

        invite.consumed_at = datetime.now(timezone.utc)


@router.post("/register", response_model=Token, status_code=status.HTTP_201_CREATED)
def register(payload: UserRegister, background_tasks: BackgroundTasks, db: Session = Depends(get_db)) -> Token:
    existing = (
        db.query(User)
        .filter(User.email == payload.email, User.role == payload.role, User.is_deleted == False)  # noqa: E712
        .first()
    )
    if existing:
        role_label = "Studio" if payload.role == UserRole.photographer else "Client"
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"A {role_label} account already exists for this email",
        )

    verification_token = _generate_verification_token()
    user = User(
        full_name=payload.full_name,
        email=payload.email,
        hashed_password=hash_password(payload.password),
        role=payload.role,
        studio_name=payload.studio_name,
        studio_address=payload.studio_address,
        business_type=payload.business_type,
        agreed_to_terms=payload.agreed_to_terms,
        email_verification_token=verification_token,
        email_verification_sent_at=datetime.now(timezone.utc),
        # The `plan_status` column has a NOT NULL constraint at the
        # database level; every new account must get an explicit value
        # or the INSERT fails. "inactive" means "no active paid plan yet".
        plan_status="inactive",
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    if user.role == UserRole.client:
        # Any studio that ran "Invite New Client" against this email
        # before the account existed (`POST /connections/invite-by-email`)
        # gets turned into a real pending connection now.
        _consume_email_invitations(db, user)
        db.commit()

    # Actual SMTP send happens after the response is returned, so
    # registration never waits on (or fails because of) mail delivery.
    background_tasks.add_task(deliver_verification_email, to_email=user.email, token=verification_token)

    token = create_access_token(subject=str(user.id))
    return Token(access_token=token, user=UserRead.model_validate(user))


@router.post("/login", response_model=Token)
def login(payload: UserLogin, db: Session = Depends(get_db)) -> Token:
    query = db.query(User).filter(User.email == payload.email, User.is_deleted == False)  # noqa: E712
    if payload.role is not None:
        query = query.filter(User.role == payload.role)
    candidates = query.all()

    if not candidates:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    if len(candidates) > 1:
        # Same email, no role specified, and it's registered under BOTH
        # roles — can't safely guess which account's password to check.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This email is used by both a Client and a Studio account. Please choose which one you're signing in as.",
        )

    user = candidates[0]
    if user.hashed_password is None:
        # Account was created via Google/Apple sign-in and has no
        # password set — verify_password() would otherwise crash
        # passlib with a None hash and surface as a 500.
        provider_label = user.auth_provider.value.capitalize() if user.auth_provider else "Google or Apple"
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"This account uses {provider_label} sign-in. Please continue with {provider_label} instead.",
        )
    if not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )

    token = create_access_token(subject=str(user.id))
    return Token(access_token=token, user=UserRead.model_validate(user))


@router.post("/social-login", response_model=Token)
def social_login(payload: SocialLoginRequest, db: Session = Depends(get_db)) -> Token:
    """Sign in with Google / Sign in with Apple, unified into one
    endpoint. Same Role Selection flow as email registration: `role` is
    required up front (mirrors `register()`'s required `role` field
    rather than `login()`'s optional one, since there's no password to
    fall back on for disambiguation), and find-or-create is scoped to
    (email, role) — the same `uq_users_email_role` constraint the
    email/password flow already relies on.

    First sign-in creates the account (auto-verified — the provider
    already proved the email is real, so there's no email-verification
    step to send here, unlike register()). Returning sign-ins are
    recognized by (provider_user_id, auth_provider, role) — role is
    part of the lookup (not just email/provider) so the same Google/
    Apple account can hold a separate Client and Studio row, matching
    how email/password accounts work (`uq_users_email_role`). Falls
    back to (email, role) for the very first call on a given role,
    before provider_user_id is stored for that row.
    """
    identity: SocialIdentity = (
        verify_google_id_token(payload.id_token)
        if payload.provider == AuthProvider.google
        else verify_apple_identity_token(payload.id_token)
    )

    if not identity.email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Your Google/Apple account has no email address we can use to sign you in.",
        )

    user = (
        db.query(User)
        .filter(
            User.provider_user_id == identity.provider_user_id,
            User.auth_provider == payload.provider,
            User.role == payload.role,
            User.is_deleted == False,  # noqa: E712
        )
        .first()
    )

    if user is None:
        # Not seen this provider account before — fall back to
        # (email, role), same lookup register()/login() use, in case
        # this is the very first social sign-in for an email that
        # already has a row under this role. Deleted rows are excluded
        # here too so a deleted account can never be silently
        # resurrected by signing in again with the same email/provider.
        user = (
            db.query(User)
            .filter(User.email == identity.email, User.role == payload.role, User.is_deleted == False)  # noqa: E712
            .first()
        )

    if user is None:
        full_name = payload.full_name or identity.full_name or identity.email.split("@")[0]
        user = User(
            full_name=full_name,
            email=identity.email,
            hashed_password=None,
            role=payload.role,
            auth_provider=payload.provider,
            provider_user_id=identity.provider_user_id,
            agreed_to_terms=True,
            is_email_verified=True,
            # See matching comment in the email/password signup path above:
            # the DB requires a non-null plan_status on every new user row.
            plan_status="inactive",
        )
        db.add(user)
    else:
        # Existing row (created via email/password, or via the other
        # provider) signing in with Google/Apple for the first time —
        # link this provider account to it rather than rejecting it.
        user.auth_provider = payload.provider
        user.provider_user_id = identity.provider_user_id
        if identity.email_verified:
            user.is_email_verified = True

    db.commit()
    db.refresh(user)

    token = create_access_token(subject=str(user.id))
    return Token(access_token=token, user=UserRead.model_validate(user))


@router.get("/me", response_model=UserRead)
def read_current_user(current_user: User = Depends(get_current_user)) -> User:
    return current_user


@router.put("/complete-profile", response_model=UserRead)
def complete_profile(
    payload: UserCompleteProfile,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    """Final onboarding step (Complete Profile screen). Studio fields are
    required for photographer accounts and ignored for clients — role is
    taken from the authenticated user, never from the request body."""
    if current_user.role == UserRole.photographer and not payload.studio_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="studio_name is required for photographer accounts",
        )

    current_user.full_name = payload.full_name
    current_user.country = payload.country
    current_user.state = payload.state
    current_user.city = payload.city
    current_user.address = payload.address
    current_user.bio = payload.bio

    if current_user.role == UserRole.photographer:
        current_user.studio_name = payload.studio_name
        current_user.specializations = (
            ",".join(payload.specializations) if payload.specializations else None
        )

    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/send-verification-email", response_model=MessageResponse)
def send_verification_email(
    background_tasks: BackgroundTasks,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> MessageResponse:
    """Backs the Resend Email button on both `email_verification_screen.dart`
    (the initial "we just sent it" confirmation) and
    `verification_pending_screen.dart` (item 21 — blocked state). (Re)issues
    the token and hands the actual SMTP send off to a background task."""
    if current_user.is_email_verified:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Email is already verified")

    verification_token = _generate_verification_token()
    current_user.email_verification_token = verification_token
    current_user.email_verification_sent_at = datetime.now(timezone.utc)
    db.commit()

    background_tasks.add_task(deliver_verification_email, to_email=current_user.email, token=verification_token)
    return MessageResponse(message="Verification email resent.")


def _consume_verification_token(token: str, db: Session) -> User:
    user = db.query(User).filter(User.email_verification_token == token).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired verification token")

    sent_at = user.email_verification_sent_at
    if sent_at is not None:
        if sent_at.tzinfo is None:
            sent_at = sent_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) - sent_at > VERIFICATION_TOKEN_TTL:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired verification token")

    user.is_email_verified = True
    user.email_verification_token = None
    db.commit()
    db.refresh(user)
    return user


@router.post("/verify-email", response_model=UserRead)
def verify_email(payload: VerifyEmailRequest, db: Session = Depends(get_db)) -> User:
    """Consumes the token from the verification link. Not authenticated —
    the token itself is the credential, same as a real email verification
    link would be. Used if the app ever handles the link as a deep link."""
    return _consume_verification_token(payload.token, db)


@router.get("/verify-email-link", response_class=HTMLResponse, include_in_schema=False)
def verify_email_link(token: str, db: Session = Depends(get_db)) -> HTMLResponse:
    """The link actually placed in the verification email — opened from
    Gmail/Outlook/etc. on any device, so this stays a plain browser page
    that consumes the token directly rather than being an app deep link
    itself. It then hands off into the app via the same `picgallery://`
    custom-scheme DeepLinkService already used for payment redirects
    (see `deep_link_service.dart`), so the user doesn't have to
    manually switch back — auto-redirect first, with a tappable
    fallback button in case the browser blocks the automatic one."""
    try:
        _consume_verification_token(token, db)
        message, ok = "Your email is verified. Taking you back to the picgallery app...", True
    except HTTPException as exc:
        message, ok = exc.detail, False

    color = "#16A34A" if ok else "#DC2626"
    app_link = "picgallery://email-verified"
    redirect_script = f'<script>window.location.href = "{app_link}";</script>' if ok else ""
    button = (
        f'<p style="margin-top:24px;"><a href="{app_link}" '
        'style="background:#7C3AED;color:#fff;padding:14px 28px;border-radius:10px;'
        'text-decoration:none;font-weight:600;display:inline-block;">Open picgallery app</a></p>'
        if ok
        else ""
    )
    return HTMLResponse(
        f"""<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>picgallery — Email Verification</title>{redirect_script}</head>
<body style="font-family:-apple-system,Arial,sans-serif;display:flex;min-height:100vh;
             align-items:center;justify-content:center;margin:0;background:#F5F3FF;">
  <div style="text-align:center;padding:40px;max-width:420px;">
    <h2 style="color:{color};">{'Verified!' if ok else 'Verification failed'}</h2>
    <p style="color:#444;">{message}</p>
    {button}
  </div>
</body></html>"""
    )


@router.put("/permissions", response_model=UserRead)
def update_permissions(
    payload: UserUpdatePermissions,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> User:
    """Backs items 15-17 (Camera / Photo Library / Push Notification
    prompts). Each screen's "Allow Access" triggers the real native OS
    permission dialog client-side (via `permission_handler`) first, then
    sends its one flag as whatever the OS actually granted; "Not Now"
    either omits the call entirely or sends it as False — the brief has
    onSkip always advance regardless of granted state, so the frontend is
    free to skip calling this on Not Now. This endpoint itself just
    records the flag it's given — it has no way to independently verify
    the OS permission state."""
    updates = payload.model_dump(exclude_unset=True)
    for field, value in updates.items():
        setattr(current_user, field, value)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/forgot-password", response_model=MessageResponse)
def forgot_password(
    payload: ForgotPasswordRequest, background_tasks: BackgroundTasks, db: Session = Depends(get_db)
) -> MessageResponse:
    """Backs `forgot_password_screen.dart`'s Send Reset Link button and
    `check_email_screen.dart`'s Resend link. Always returns 200 with the
    same generic message regardless of whether the email exists, so the
    response can never be used to enumerate registered accounts — the
    token is only generated (and only emailed) when a matching user is
    actually found."""
    user = db.query(User).filter(User.email == payload.email, User.is_deleted == False).first()  # noqa: E712
    if user is not None:
        reset_code = _generate_reset_code()
        user.reset_password_token = reset_code
        user.reset_password_sent_at = datetime.now(timezone.utc)
        db.commit()

        # This call was previously missing entirely — a token was saved
        # to the DB but no email ever went out, so the user was stuck on
        # "Check Your Inbox" forever with nothing arriving.
        background_tasks.add_task(deliver_password_reset_email, to_email=user.email, token=reset_code)

    return MessageResponse(message="If that email is registered, a password reset code has been sent.")


@router.post("/reset-password", response_model=MessageResponse)
def reset_password(payload: ResetPasswordRequest, db: Session = Depends(get_db)) -> MessageResponse:
    """Consumes the token from the (dummy) reset-password link, same TTL
    pattern as `verify_email`. Not authenticated — the token itself is
    the credential, since the user isn't logged in when resetting a
    forgotten password."""
    user = db.query(User).filter(User.reset_password_token == payload.token).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset token")

    sent_at = user.reset_password_sent_at
    if sent_at is not None:
        if sent_at.tzinfo is None:
            sent_at = sent_at.replace(tzinfo=timezone.utc)
        if datetime.now(timezone.utc) - sent_at > RESET_PASSWORD_TOKEN_TTL:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired reset token")

    user.hashed_password = hash_password(payload.new_password)
    user.reset_password_token = None
    user.reset_password_sent_at = None
    db.commit()

    return MessageResponse(message="Password reset successfully. You can now sign in with your new password.")
