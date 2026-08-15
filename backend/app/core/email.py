"""Real SMTP email delivery for verification / password-reset links.

Uses stdlib `smtplib` only (no extra dependency). If SMTP_HOST isn't
configured, `send_email` logs a warning and returns without raising —
callers (auth routes) should never fail registration/login just because
mail couldn't go out.
"""

import logging
import smtplib
from email.message import EmailMessage

from app.core.config import settings

logger = logging.getLogger("app.email")


def send_email(*, to_email: str, subject: str, html_body: str, text_body: str) -> bool:
    """Sends a single email. Returns True if it was handed off to the
    SMTP server successfully, False otherwise (including when SMTP isn't
    configured at all). Never raises — errors are logged instead."""
    if not settings.SMTP_HOST:
        logger.warning(
            "SMTP_HOST is not configured — skipping email send to %s (subject=%r). "
            "Set SMTP_HOST/SMTP_USERNAME/SMTP_PASSWORD in .env to enable real delivery.",
            to_email,
            subject,
        )
        return False

    message = EmailMessage()
    message["Subject"] = subject
    from_email = settings.SMTP_FROM_EMAIL or settings.SMTP_USERNAME
    message["From"] = f"{settings.SMTP_FROM_NAME} <{from_email}>"
    message["To"] = to_email
    message.set_content(text_body)
    message.add_alternative(html_body, subtype="html")

    try:
        with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT, timeout=10) as smtp:
            if settings.SMTP_USE_TLS:
                smtp.starttls()
            if settings.SMTP_USERNAME:
                smtp.login(settings.SMTP_USERNAME, settings.SMTP_PASSWORD)
            smtp.send_message(message)
        return True
    except Exception:
        logger.exception("Failed to send email to %s (subject=%r)", to_email, subject)
        return False


def send_verification_email(*, to_email: str, token: str) -> bool:
    verify_link = f"{settings.app_public_url}/api/v1/auth/verify-email-link?token={token}"
    subject = "Verify your picgallery email"
    html_body = f"""\
<div style="font-family: -apple-system, Arial, sans-serif; max-width: 480px; margin: auto;">
  <h2 style="color:#7C3AED;">Verify your email</h2>
  <p>Tap the button below to confirm <strong>{to_email}</strong> and continue setting up your picgallery account.</p>
  <p style="margin: 32px 0;">
    <a href="{verify_link}"
       style="background:#7C3AED;color:#fff;padding:14px 28px;border-radius:10px;
              text-decoration:none;font-weight:600;display:inline-block;">
      Verify Email
    </a>
  </p>
  <p style="color:#888;font-size:13px;">This link expires in 24 hours. If you didn't request this, you can ignore this email.</p>
  <p style="color:#888;font-size:13px;">Or paste this link into your browser: {verify_link}</p>
</div>
"""
    text_body = (
        f"Verify your email for picgallery.\n\n"
        f"Open this link to confirm {to_email}:\n{verify_link}\n\n"
        f"This link expires in 24 hours."
    )
    return send_email(to_email=to_email, subject=subject, html_body=html_body, text_body=text_body)


def send_password_reset_email(*, to_email: str, token: str) -> bool:
    subject = "Your picgallery password reset code"
    html_body = f"""\
<div style="font-family: -apple-system, Arial, sans-serif; max-width: 480px; margin: auto;">
  <h2 style="color:#7C3AED;">Reset your password</h2>
  <p>We received a request to reset the password for <strong>{to_email}</strong>.</p>
  <p style="margin: 28px 0; text-align:center;">
    <span style="font-size:32px; font-weight:700; letter-spacing:6px; color:#7C3AED;">{token}</span>
  </p>
  <p style="color:#444;">Enter this code on the Reset Password screen in the app to continue.</p>
  <p style="color:#888;font-size:13px;">This code expires in 1 hour. If you didn't request this, you can ignore this email.</p>
</div>
"""
    text_body = f"Your picgallery password reset code: {token}\nThis code expires in 1 hour."
    return send_email(to_email=to_email, subject=subject, html_body=html_body, text_body=text_body)


def send_connection_invite_email(*, to_email: str, studio_name: str) -> bool:
    """Sent to a client when a studio invites them to connect (Task 5.3).
    No token/link — unlike verification and password-reset, there's no
    action the client can take from the email itself, since accepting
    or declining happens in-app on the Invitations screen. This is just
    a heads-up.
    """
    subject = f"{studio_name} invited you to connect on picgallery"
    html_body = f"""\
<div style="font-family: -apple-system, Arial, sans-serif; max-width: 480px; margin: auto;">
  <h2 style="color:#7C3AED;">You've been invited</h2>
  <p><strong>{studio_name}</strong> would like to connect with you on picgallery.</p>
  <p style="color:#444;">Open the app and go to Invitations to accept or decline.</p>
  <p style="color:#888;font-size:13px;">If you weren't expecting this, you can safely ignore it.</p>
</div>
"""
    text_body = (
        f"{studio_name} invited you to connect on picgallery.\n\n"
        f"Open the app and go to Invitations to accept or decline."
    )
    return send_email(to_email=to_email, subject=subject, html_body=html_body, text_body=text_body)


def send_signup_invite_email(*, to_email: str, studio_name: str) -> bool:
    """Sent to an email address a studio invited that has no PicGallery
    client account yet (Task: "Invite New Client" should work for
    non-users too — see `POST /connections/invite-by-email`). Unlike
    [send_connection_invite_email], there's no in-app Invitations
    screen to point to since the recipient can't log in yet, so this
    just asks them to download the app and register with this email —
    `auth.register` auto-converts any matching `EmailInvitation` rows
    into a real, pending connection the moment that account exists.
    """
    subject = f"{studio_name} invited you to picgallery"
    html_body = f"""\
<div style="font-family: -apple-system, Arial, sans-serif; max-width: 480px; margin: auto;">
  <h2 style="color:#7C3AED;">You've been invited</h2>
  <p><strong>{studio_name}</strong> uses picgallery to share and deliver photos, and would like to connect with you.</p>
  <p style="color:#444;">Download the picgallery app and sign up with this email address ({to_email}) — you'll automatically see a connection request from {studio_name} waiting for you to accept.</p>
  <p style="color:#888;font-size:13px;">If you weren't expecting this, you can safely ignore it.</p>
</div>
"""
    text_body = (
        f"{studio_name} invited you to connect on picgallery.\n\n"
        f"Download the picgallery app and sign up with this email address ({to_email}) — "
        f"you'll automatically see a connection request from {studio_name} waiting for you to accept."
    )
    return send_email(to_email=to_email, subject=subject, html_body=html_body, text_body=text_body)


def send_connection_request_email(*, to_email: str, client_name: str) -> bool:
    """Sent to a studio when a client requests to connect (Task 21.2) —
    the studio-facing mirror of [send_connection_invite_email]. Same
    no-token/no-link shape: accepting or declining happens in-app on
    the studio's Connections screen, not from the email.
    """
    subject = f"{client_name} wants to connect with you on picgallery"
    html_body = f"""\
<div style="font-family: -apple-system, Arial, sans-serif; max-width: 480px; margin: auto;">
  <h2 style="color:#7C3AED;">New connection request</h2>
  <p><strong>{client_name}</strong> would like to connect with you on picgallery.</p>
  <p style="color:#444;">Open the app and go to Connections to accept or decline.</p>
  <p style="color:#888;font-size:13px;">If you weren't expecting this, you can safely ignore it.</p>
</div>
"""
    text_body = (
        f"{client_name} wants to connect with you on picgallery.\n\n"
        f"Open the app and go to Connections to accept or decline."
    )
    return send_email(to_email=to_email, subject=subject, html_body=html_body, text_body=text_body)