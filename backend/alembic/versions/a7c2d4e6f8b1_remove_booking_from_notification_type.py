"""remove unused 'booking' value from notification_type enum

The `notification_type` Postgres enum (created in
m8n9o0p1q2r3_create_notifications_table) was created with a 'booking'
value that the Python `NotificationType` model enum
(app/models/notification.py) never defined and no route ever writes.
Dropping it here so the DB type matches the model exactly — leaving a
value only the DB knows about invites a `LookupError` the moment any
row ever gets it (manual insert, future migration, admin script,
etc.).

Postgres can't drop a single value from an existing enum type
in-place, so this recreates the type without 'booking':
  1. Defensively reassign any existing 'booking' rows to 'system'
     (belt-and-suspenders — no known code path ever wrote 'booking',
     so this should be a no-op in practice).
  2. Rename the old type out of the way.
  3. Create the new type with the trimmed value set.
  4. Repoint the column at the new type via a text cast.
  5. Drop the old type.

Revision ID: a7c2d4e6f8b1
Revises: f4a6b8c0d2e4
Create Date: 2026-08-26 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = 'a7c2d4e6f8b1'
down_revision: Union[str, None] = 'f4a6b8c0d2e4'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

OLD_VALUES = ('reminder', 'approval', 'booking', 'gallery', 'connection', 'system')
NEW_VALUES = ('reminder', 'approval', 'gallery', 'connection', 'system')


def upgrade() -> None:
    # Defensive: reassign any 'booking' rows before the type stops
    # accepting that value. No code path currently writes 'booking',
    # so this should affect zero rows.
    op.execute("UPDATE notifications SET type = 'system' WHERE type = 'booking'")

    op.execute("ALTER TYPE notification_type RENAME TO notification_type_old")

    new_enum = postgresql.ENUM(*NEW_VALUES, name="notification_type")
    new_enum.create(op.get_bind(), checkfirst=True)

    op.execute(
        "ALTER TABLE notifications "
        "ALTER COLUMN type TYPE notification_type "
        "USING type::text::notification_type"
    )

    op.execute("DROP TYPE notification_type_old")


def downgrade() -> None:
    op.execute("ALTER TYPE notification_type RENAME TO notification_type_new")

    old_enum = postgresql.ENUM(*OLD_VALUES, name="notification_type")
    old_enum.create(op.get_bind(), checkfirst=True)

    op.execute(
        "ALTER TABLE notifications "
        "ALTER COLUMN type TYPE notification_type "
        "USING type::text::notification_type"
    )

    op.execute("DROP TYPE notification_type_new")