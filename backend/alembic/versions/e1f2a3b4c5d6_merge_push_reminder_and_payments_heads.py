"""merge push/reminder branch with payments branch

This merges the two divergent alembic heads that resulted from
parallel feature work off z0a1b2c3d4e5 (create_album_client_shares_table):

  - h1i2j3k4l5m6 (studio_backups / Task 6 cloud backup, via the
    website-field branch -> last_reminder_days branch)
  - c1d2e3f4a5b6 (add_last_reminder_days_field, tip of the same branch
    as h1i2j3k4l5m6's parent chain)

The sibling duplicate d5e6f7a8b9c0_create_studio_backups_table.py has
been deleted rather than merged: it created the same studio_backups
table with a different (unique-per-owner, overwrite-style) shape that
does not match the live StudioBackup model, so it was an orphaned
duplicate, not a second real feature.

This is a no-op merge: no schema changes, just joins the two heads
into one so `alembic upgrade head` has a single unambiguous target
again.

Revision ID: e1f2a3b4c5d6
Revises: h1i2j3k4l5m6, c1d2e3f4a5b6
Create Date: 2026-08-19 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e1f2a3b4c5d6'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None

# Merge revision — combines both parent heads. Alembic represents this
# as a tuple on down_revision rather than the single-string form used
# by every other migration in this history.
down_revision = ('h1i2j3k4l5m6', 'c1d2e3f4a5b6')


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass