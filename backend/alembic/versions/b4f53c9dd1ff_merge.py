"""merge

Revision ID: b4f53c9dd1ff
Revises: a7c2d4e6f8b1, h9i0j1k2l3m4
Create Date: 2026-09-12 01:10:22.460889

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b4f53c9dd1ff'
down_revision: Union[str, None] = ('a7c2d4e6f8b1', 'h9i0j1k2l3m4')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
