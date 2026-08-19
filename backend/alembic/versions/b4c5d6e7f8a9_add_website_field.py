"""add website field to users

Revision ID: b4c5d6e7f8a9
Revises: z0a1b2c3d4e5
Create Date: 2026-08-18 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b4c5d6e7f8a9'
down_revision: Union[str, None] = 'z0a1b2c3d4e5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('users', sa.Column('website', sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'website')
