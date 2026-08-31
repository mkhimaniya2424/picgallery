"""add complete profile fields (incl. studio specializations)

Revision ID: d4e1f9a2b6c3
Revises: c76a4c5b71e8
Create Date: 2026-07-09 18:20:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'd4e1f9a2b6c3'
down_revision: Union[str, None] = 'c76a4c5b71e8'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Shared Complete Profile fields (both roles)
    op.add_column('users', sa.Column('avatar_url', sa.String(length=500), nullable=True))
    op.add_column('users', sa.Column('country', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('state', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('city', sa.String(length=100), nullable=True))
    op.add_column('users', sa.Column('address', sa.String(length=255), nullable=True))
    op.add_column('users', sa.Column('bio', sa.String(length=500), nullable=True))

    # Studio business details — photographer role only, nullable for clients.
    # Stored as a comma-separated string of the fixed chip set defined in
    # the Flutter app (kStudioSpecializations: Wedding, Portrait, Event,
    # Product) and exposed back to the API as a list.
    op.add_column('users', sa.Column('specializations', sa.String(length=255), nullable=True))


def downgrade() -> None:
    op.drop_column('users', 'specializations')
    op.drop_column('users', 'bio')
    op.drop_column('users', 'address')
    op.drop_column('users', 'city')
    op.drop_column('users', 'state')
    op.drop_column('users', 'country')
    op.drop_column('users', 'avatar_url')
