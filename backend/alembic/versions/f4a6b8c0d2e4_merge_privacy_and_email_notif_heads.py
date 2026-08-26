"""merge privacy fields branch with email_notifications branch

This merges the two divergent alembic heads that resulted from
parallel feature work off z0a1b2c3d4e5 (create_album_client_shares_table):

  - c294bb6c5ebf (add_privacy_fields, reached via the fcm_token /
    payments / studio_backups branch and the 0ed11a01d853 merge point)
  - z1a2b3c4d5e6 (add_email_notifications_field, sibling branch off
    z0a1b2c3d4e5 that was never folded back in)

This is a no-op merge itself: no schema changes, just joins the two
heads into one so `alembic upgrade head` has a single unambiguous
target again.

Revision ID: f4a6b8c0d2e4
Revises: c294bb6c5ebf, z1a2b3c4d5e6
Create Date: 2026-08-26 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f4a6b8c0d2e4'
down_revision: Union[str, None] = ('c294bb6c5ebf', 'z1a2b3c4d5e6')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass