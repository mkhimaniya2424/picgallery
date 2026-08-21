"""add fcm_token to users

Revision ID: a0b1c2d3e4f5
Revises: z0a1b2c3d4e5
Create Date: 2026-08-21 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a0b1c2d3e4f5'
down_revision: Union[str, None] = 'z0a1b2c3d4e5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Firebase Cloud Messaging token — nullable because a user may not
    # have the app installed / may not have granted push permissions yet.
    op.add_column(
        'users',
        sa.Column('fcm_token', sa.String(length=500), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('users', 'fcm_token')
