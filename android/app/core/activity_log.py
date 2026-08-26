"""Shared helper for writing Activity Log rows (Task 20.3).

Kept out of any single route module because several very different
endpoints — bookings, connections, media uploads, notifications, ... —
all need to append the same kind of row to a studio's Activity
Timeline. Centralizing the row-building here means every caller
produces identically-shaped entries instead of each route hand-rolling
its own `ActivityLog(...)`, same reasoning `record_download_event`
(`app/core/download_log.py`) uses for Download History rows.
"""

import uuid

from sqlalchemy.orm import Session

from app.models.activity_log import ActivityLog, ActivityType


def log_activity(
    db: Session,
    studio_id: uuid.UUID,
    type: ActivityType,
    title: str,
    subtitle: str = "",
) -> ActivityLog:
    """Builds and stages (via `db.add`) one Activity Log row. Does NOT
    commit — callers commit alongside whatever else they're already
    doing in the same request, so the activity entry lands in the same
    transaction as the action it's describing (and never gets recorded
    for an action that ultimately rolled back).
    """
    entry = ActivityLog(studio_id=studio_id, type=type, title=title, subtitle=subtitle)
    db.add(entry)
    return entry
