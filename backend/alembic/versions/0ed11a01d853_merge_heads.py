"""merge heads

Revision ID: 0ed11a01d853
Revises: a0b1c2d3e4f5, e1f2a3b4c5d6
Create Date: 2026-08-21 10:38:19.567009

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '0ed11a01d853'
down_revision: Union[str, None] = ('a0b1c2d3e4f5', 'e1f2a3b4c5d6')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
