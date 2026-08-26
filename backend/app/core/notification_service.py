"""Notification service that respects user notification preferences.

Provides wrapper functions for sending push and email notifications,
checking user's push_notifications_enabled and email_notifications_enabled
flags before actually sending.
"""

import logging
from app.models.user import User
from app.core.email import (
    send_email,
    send_verification_email,
    send_password_reset_email,
    send_connection_invite_email,
    send_connection_request_email,
    send_subscription_activated_email,
)
from app.core.firebase_service import send_push_notification

logger = logging.getLogger("app.notifications")


def should_send_push_notification(user: User) -> bool:
    """Check if user has enabled push notifications.
    
    Returns True only if:
    - User has a registered FCM token
    - User has push_notifications_enabled flag set to True
    """
    return bool(user.fcm_token and user.push_notifications_enabled)


def should_send_email_notification(user: User) -> bool:
    """Check if user has enabled email notifications.
    
    Returns True only if user has email_notifications_enabled flag set to True.
    Note: Some system emails (verification, password reset) are sent regardless
    of this preference since they're user-initiated.
    """
    return user.email_notifications_enabled


def send_push_if_enabled(
    user: User,
    title: str,
    body: str,
    data: dict | None = None,
) -> bool:
    """Send a push notification only if user has it enabled.
    
    Args:
        user: User object
        title: Notification title
        body: Notification body
        data: Optional data payload
        
    Returns:
        True if notification was sent (or user disabled it), False if failed
    """
    if not should_send_push_notification(user):
        logger.debug(
            f"Skipping push notification for user {user.id} — "
            f"fcm_token={bool(user.fcm_token)}, "
            f"push_notifications_enabled={user.push_notifications_enabled}"
        )
        return True  # Not an error, user just disabled it

    try:
        success = send_push_notification(
            token=user.fcm_token,
            title=title,
            body=body,
            data=data or {},
        )
        if not success:
            logger.warning(f"Failed to send push notification to user {user.id}")
        return success
    except Exception as e:
        logger.exception(f"Error sending push notification to user {user.id}: {e}")
        return False


def send_email_if_enabled(
    user: User,
    subject: str,
    html_body: str,
    text_body: str,
    email_type: str = "notification",
) -> bool:
    """Send an email notification only if user has it enabled.
    
    System emails like verification and password reset should NOT use this
    function — they should always be sent regardless of preference.
    
    Args:
        user: User object
        subject: Email subject
        html_body: HTML email body
        text_body: Plain text email body
        email_type: Type of email (for logging)
        
    Returns:
        True if email was sent (or user disabled it), False if failed
    """
    if not should_send_email_notification(user):
        logger.debug(
            f"Skipping {email_type} email for user {user.id} "
            f"({user.email}) — email_notifications_enabled=False"
        )
        return True  # Not an error, user just disabled it

    try:
        success = send_email(
            to_email=user.email,
            subject=subject,
            html_body=html_body,
            text_body=text_body,
        )
        if not success:
            logger.warning(f"Failed to send {email_type} email to user {user.id}")
        return success
    except Exception as e:
        logger.exception(f"Error sending {email_type} email to user {user.id}: {e}")
        return False


def send_connection_invite_if_enabled(user: User, studio_name: str) -> bool:
    """Send connection invite email only if user has email notifications enabled.
    
    Sent to a client when a studio invites them to connect.
    """
    if not should_send_email_notification(user):
        logger.debug(
            f"Skipping connection invite email for user {user.id} "
            f"({user.email}) — email_notifications_enabled=False"
        )
        return True

    try:
        success = send_connection_invite_email(
            to_email=user.email,
            studio_name=studio_name,
        )
        if not success:
            logger.warning(
                f"Failed to send connection invite email to user {user.id} "
                f"({user.email})"
            )
        return success
    except Exception as e:
        logger.exception(
            f"Error sending connection invite email to user {user.id}: {e}"
        )
        return False


def send_connection_request_if_enabled(user: User, client_name: str) -> bool:
    """Send connection request email only if user has email notifications enabled.
    
    Sent to a studio when a client requests to connect.
    """
    if not should_send_email_notification(user):
        logger.debug(
            f"Skipping connection request email for user {user.id} "
            f"({user.email}) — email_notifications_enabled=False"
        )
        return True

    try:
        success = send_connection_request_email(
            to_email=user.email,
            client_name=client_name,
        )
        if not success:
            logger.warning(
                f"Failed to send connection request email to user {user.id} "
                f"({user.email})"
            )
        return success
    except Exception as e:
        logger.exception(
            f"Error sending connection request email to user {user.id}: {e}"
        )
        return False


def send_subscription_activated_if_enabled(
    user: User,
    plan: str,
    expiry: str,
) -> bool:
    """Send subscription activated email only if user has email notifications enabled.
    
    Note: This might be a critical transactional email that should always be sent.
    Consider removing the check for this function.
    """
    if not should_send_email_notification(user):
        logger.debug(
            f"Skipping subscription activated email for user {user.id} "
            f"({user.email}) — email_notifications_enabled=False"
        )
        return True

    try:
        success = send_subscription_activated_email(
            to_email=user.email,
            full_name=user.full_name or "User",
            plan=plan,
            expiry=expiry,
        )
        if not success:
            logger.warning(
                f"Failed to send subscription activated email to user {user.id} "
                f"({user.email})"
            )
        return success
    except Exception as e:
        logger.exception(
            f"Error sending subscription activated email to user {user.id}: {e}"
        )
        return False