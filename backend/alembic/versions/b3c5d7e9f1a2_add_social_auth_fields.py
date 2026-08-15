"""add social auth fields (google/apple sign-in)

Revision ID: b3c5d7e9f1a2
Revises: a1b2c3d4e5f6
Create Date: 2026-07-14 09:00:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'b3c5d7e9f1a2'
down_revision: Union[str, None] = 'a2b4c6d8e0f1'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


auth_provider_enum = sa.Enum('local', 'google', 'apple', name='auth_provider')


def upgrade() -> None:
    # Google/Apple sign-in accounts have no password — hashed_password
    # was previously NOT NULL, which would reject them outright.
    op.alter_column('users', 'hashed_password', existing_type=sa.String(length=255), nullable=True)

    auth_provider_enum.create(op.get_bind(), checkfirst=True)
    op.add_column(
        'users',
        sa.Column('auth_provider', auth_provider_enum, nullable=False, server_default='local'),
    )
    op.add_column('users', sa.Column('provider_user_id', sa.String(length=255), nullable=True))
    op.create_index(op.f('ix_users_provider_user_id'), 'users', ['provider_user_id'], unique=False)

    # Drop the server_default now that existing rows are backfilled —
    # new rows always set it explicitly via the model's Python default.
    op.alter_column('users', 'auth_provider', server_default=None)


def downgrade() -> None:
    op.drop_index(op.f('ix_users_provider_user_id'), table_name='users')
    op.drop_column('users', 'provider_user_id')
    op.drop_column('users', 'auth_provider')
    auth_provider_enum.drop(op.get_bind(), checkfirst=True)
    op.alter_column('users', 'hashed_password', existing_type=sa.String(length=255), nullable=False)
