"""Use BIGINT for media file sizes.

Revision ID: 7f8e9a0b1c2d
Revises: 650240dd91f0
"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


revision: str = "7f8e9a0b1c2d"
down_revision: Union[str, None] = "650240dd91f0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.alter_column(
        "media",
        "size_bytes",
        existing_type=sa.Integer(),
        type_=sa.BigInteger(),
        existing_nullable=False,
    )


def downgrade() -> None:
    op.alter_column(
        "media",
        "size_bytes",
        existing_type=sa.BigInteger(),
        type_=sa.Integer(),
        existing_nullable=False,
    )
