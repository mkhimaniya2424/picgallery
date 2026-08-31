"""add upi_id field to users

Revision ID: a3b5c7d9e1f2
Revises: z0a1b2c3d4e5
Create Date: 2026-07-30 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a3b5c7d9e1f2'
down_revision: Union[str, None] = 'z0a1b2c3d4e5'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Studio's own UPI VPA (e.g. "studio@okhdfcbank") — lets each studio
    # receive client invoice/booking payments directly into their own
    # UPI account instead of the old hardcoded platform placeholder.
    # Nullable/photographer-only, same convention as instagram_url etc.
    op.add_column(
        'users',
        sa.Column('upi_id', sa.String(length=100), nullable=True),
    )


def downgrade() -> None:
    op.drop_column('users', 'upi_id')
