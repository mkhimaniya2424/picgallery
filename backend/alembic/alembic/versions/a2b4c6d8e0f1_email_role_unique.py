"""allow one email across two roles (composite email+role unique)

Revision ID: a2b4c6d8e0f1
Revises: f1a2b3c4d5e6
Create Date: 2026-07-10 11:15:00.000000

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = 'a2b4c6d8e0f1'
down_revision: Union[str, None] = 'f1a2b3c4d5e6'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # The same email may now back two accounts — one client, one
    # photographer — so uniqueness moves from `email` alone to the
    # (email, role) pair. Drop the old unique index, replace it with a
    # plain (non-unique) index for lookups that still filter by email
    # only, then add the composite unique constraint.
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=False)
    op.create_unique_constraint('uq_users_email_role', 'users', ['email', 'role'])


def downgrade() -> None:
    op.drop_constraint('uq_users_email_role', 'users', type_='unique')
    op.drop_index(op.f('ix_users_email'), table_name='users')
    op.create_index(op.f('ix_users_email'), 'users', ['email'], unique=True)
