from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.api.deps import get_current_studio_user
from app.db.session import get_db
from app.models.activity_log import ActivityLog
from app.models.user import User
from app.schemas.activity_log import ActivityLogList, ActivityLogRead

router = APIRouter(prefix="/activity-log", tags=["activity-log"])


@router.get("", response_model=ActivityLogList)
def list_activity_log(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    current_user: User = Depends(get_current_studio_user),
    db: Session = Depends(get_db),
) -> ActivityLogList:
    """Studio-only — backs the Admin "Recent Activity" screen
    (`recent_activity_screen.dart`), previously seeded in-memory by
    `InMemoryAdminDashboardRepository`. Newest first, same offset/limit
    envelope as `GET /chat/threads/{id}/messages`
    (`routes/chat.py::list_messages`) so pagination behaves the same
    way across the API.

    Entries themselves are written elsewhere, via `log_activity`
    (`app/core/activity_log.py`), by whichever route performed the
    underlying action — this endpoint is read-only.
    """
    total = (
        db.execute(
            select(func.count()).select_from(ActivityLog).where(ActivityLog.studio_id == current_user.id)
        ).scalar()
        or 0
    )

    stmt = (
        select(ActivityLog)
        .where(ActivityLog.studio_id == current_user.id)
        .order_by(ActivityLog.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    entries = db.execute(stmt).scalars().all()

    return ActivityLogList(
        items=[ActivityLogRead.model_validate(e) for e in entries],
        total=total,
        limit=limit,
        offset=offset,
    )
