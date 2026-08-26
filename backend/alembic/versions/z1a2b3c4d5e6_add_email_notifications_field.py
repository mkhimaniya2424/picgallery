"""add email_notifications_enabled field to users

Revision ID: z1a2b3c4d5e6
Revises: z0a1b2c3d4e5
Create Date: 2026-08-26 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'z1a2b3c4d5e6'
down_revision: Union[str, None] = 'z0a1b2c3d4e5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Notification Settings screen — "Email Notifications" toggle.
    # Previously stored only in the local Hive SettingsModel, so it never
    # synced across devices/reinstalls — same class of bug as app_language
    # and other device-local-only settings before their fixes.
    # Defaults to True (opt-out rather than opt-in) since email notifications
    # were always sent before this setting existed.
    op.add_column(
        'users',
        sa.Column('email_notifications_enabled', sa.Boolean(), nullable=False, server_default='true'),
    )
    # Drop the server default once existing rows are backfilled — new
    # inserts already supply the value via the SQLAlchemy model default.
    op.alter_column('users', 'email_notifications_enabled', server_default=None)


def downgrade() -> None:
    op.drop_column('users', 'email_notifications_enabled')