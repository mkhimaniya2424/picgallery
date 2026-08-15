"""drop bookings, team, and payment tables

Revision ID: z1b2c3d4e5f6
Revises: z0a1b2c3d4e5
Create Date: 2026-08-07 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "z1b2c3d4e5f6"
down_revision: Union[str, None] = "z0a1b2c3d4e5"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    """Drop tables related to bookings, team members, and payments."""
    # Drop bookings table
    op.drop_table("bookings")
    
    # Drop payment-related tables
    op.drop_table("invoices")
    op.drop_table("transactions")
    op.drop_table("payment_methods")
    op.drop_table("payments")
    
    # Drop team tables
    op.drop_table("team_members")
    op.drop_table("custom_roles")


def downgrade() -> None:
    """Recreate tables (not recommended in production)."""
    # This is a destructive operation; downgrade is intentionally minimal
    # to prevent accidental recreation. Users should restore from backup.
    pass
