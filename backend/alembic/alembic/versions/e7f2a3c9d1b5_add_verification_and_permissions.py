"""add verification tokens and permission grant flags

Revision ID: e7f2a3c9d1b5
Revises: d4e1f9a2b6c3
Create Date: 2026-07-10 09:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'e7f2a3c9d1b5'
down_revision: Union[str, None] = 'd4e1f9a2b6c3'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Email verification (item 21 — Verification Pending screen)
    op.add_column('users', sa.Column('email_verification_token', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('email_verification_sent_at', sa.DateTime(timezone=True), nullable=True))
    op.create_index(
        op.f('ix_users_email_verification_token'), 'users', ['email_verification_token'], unique=False
    )

    # Onboarding permission prompts (items 15-17). Existing rows default to
    # not-granted rather than backfilling a guess.
    op.add_column(
        'users',
        sa.Column('camera_permission_granted', sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        'users',
        sa.Column('photo_library_permission_granted', sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    op.add_column(
        'users',
        sa.Column('push_notifications_enabled', sa.Boolean(), nullable=False, server_default=sa.false()),
    )
    # Drop the server defaults once existing rows are backfilled — new
    # inserts already supply the value via the SQLAlchemy model default.
    op.alter_column('users', 'camera_permission_granted', server_default=None)
    op.alter_column('users', 'photo_library_permission_granted', server_default=None)
    op.alter_column('users', 'push_notifications_enabled', server_default=None)


def downgrade() -> None:
    op.drop_column('users', 'push_notifications_enabled')
    op.drop_column('users', 'photo_library_permission_granted')
    op.drop_column('users', 'camera_permission_granted')
    op.drop_index(op.f('ix_users_email_verification_token'), table_name='users')
    op.drop_column('users', 'email_verification_sent_at')
    op.drop_column('users', 'email_verification_token')
