"""add password reset fields

Revision ID: f1a2b3c4d5e6
Revises: e7f2a3c9d1b5
Create Date: 2026-07-10 10:30:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'f1a2b3c4d5e6'
down_revision: Union[str, None] = 'e7f2a3c9d1b5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Forgot/Reset Password flow (Task 11) — mirrors the email
    # verification token columns/index exactly.
    op.add_column('users', sa.Column('reset_password_token', sa.String(length=64), nullable=True))
    op.add_column('users', sa.Column('reset_password_sent_at', sa.DateTime(timezone=True), nullable=True))
    op.create_index(
        op.f('ix_users_reset_password_token'), 'users', ['reset_password_token'], unique=False
    )


def downgrade() -> None:
    op.drop_index(op.f('ix_users_reset_password_token'), table_name='users')
    op.drop_column('users', 'reset_password_sent_at')
    op.drop_column('users', 'reset_password_token')
