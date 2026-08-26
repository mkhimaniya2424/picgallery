import uuid

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models.notification import Notification
from app.models.user import User
from app.schemas.notification import NotificationRead
from app.core.firebase_service import send_push_notification

router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get("", response_model=list[NotificationRead])
def list_notifications(
    limit: int = Query(default=100, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> list[NotificationRead]:
    """Available to both roles — this is the real backend for both the
    Client Alerts tab (previously `AlertsLocalStore`, Hive-only with no
    server component at all) and the Studio Notifications screen.
    Newest first, same ordering `AlertsController.items` sorted by
    client-side.
    """
    notifications = (
        db.execute(
            select(Notification)
            .where(Notification.user_id == current_user.id)
            .order_by(Notification.created_at.desc())
            .limit(limit)
        )
        .scalars()
        .all()
    )
    return [NotificationRead.model_validate(n) for n in notifications]


def _get_own_notification_or_404(db: Session, notification_id: uuid.UUID, current_user: User) -> Notification:
    notification = db.get(Notification, notification_id)
    if notification is None or notification.user_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Notification not found")
    return notification


@router.post("/{notification_id}/read", response_model=NotificationRead)
def mark_notification_read(
    notification_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> NotificationRead:
    notification = _get_own_notification_or_404(db, notification_id, current_user)
    if not notification.is_read:
        notification.is_read = True
        db.commit()
        db.refresh(notification)
    return NotificationRead.model_validate(notification)


@router.post("/read-all", status_code=status.HTTP_204_NO_CONTENT)
def mark_all_notifications_read(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    db.execute(
        update(Notification)
        .where(Notification.user_id == current_user.id, Notification.is_read.is_(False))
        .values(is_read=True)
    )
    db.commit()


@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_notification(
    notification_id: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    notification = _get_own_notification_or_404(db, notification_id, current_user)
    db.delete(notification)
    db.commit()


@router.delete("", status_code=status.HTTP_204_NO_CONTENT)
def clear_notifications(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Backs `AlertsController.clearAll` / a studio-side "clear all"
    action. Deletes rather than just marking read, matching
    `AlertsLocalStore.clear`'s previous semantics.
    """
    db.execute(
        Notification.__table__.delete().where(Notification.user_id == current_user.id)
    )
    db.commit()


@router.post("/test-push", status_code=status.HTTP_200_OK)
def send_test_push_notification(
    current_user: User = Depends(get_current_user)
) -> dict:
    """Sends a test push notification to the current user's registered FCM token."""
    if not current_user.fcm_token:
        raise HTTPException(status_code=400, detail="No push token registered for this user.")
        
    success = send_push_notification(
        token=current_user.fcm_token,
        title="Test Notification",
        body="This is a test push notification from PicGallery!",
        data={"type": "test", "user_id": str(current_user.id)}
    )
    
    if success:
        return {"message": "Test push notification sent successfully."}
    else:
        raise HTTPException(status_code=500, detail="Failed to send push notification.")
