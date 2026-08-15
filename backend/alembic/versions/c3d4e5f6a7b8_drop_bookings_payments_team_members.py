"""drop bookings, payments, team members, custom roles, upi_id

Feature removal: Bookings, Billing & Payouts, and Team Members are
being dropped from the product. This migration removes the tables
(and the enum types / column they depend on) that backed those
features. The original create-migrations
(`u5v6w7x8y9z0_create_bookings_table`,
`b2c3d4e5f6a7_create_payment_tables`,
`o0p1q2r3s4t5_create_team_members_table`,
`t4u5v6w7x8y9_create_custom_roles_table`,
`a3b5c7d9e1f2_add_upi_id_field`) are left in place as history rather
than deleted, since later migrations chain off them — this migration
just undoes their effect on top of the current schema.

Uses `DROP TABLE IF EXISTS ... CASCADE` / `DROP TYPE IF EXISTS ...
CASCADE` rather than mirroring each original migration's downgrade()
line-by-line, so this is safe to run even if indexes/constraints were
renamed or added since those tables were created.

Revision ID: c3d4e5f6a7b8
Revises: b2c3d4e5f6a7
Create Date: 2026-08-07 00:00:00.000000

"""
from typing import Sequence, Union

from alembic import op

# revision identifiers, used by Alembic.
revision: str = "c3d4e5f6a7b8"
down_revision: Union[str, None] = "b2c3d4e5f6a7"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # --- Payments / Billing & Payouts ---
    op.execute("DROP TABLE IF EXISTS payment_methods CASCADE")
    op.execute("DROP TABLE IF EXISTS invoices CASCADE")
    op.execute("DROP TABLE IF EXISTS transactions CASCADE")
    op.execute("DROP TYPE IF EXISTS payment_method_type CASCADE")
    op.execute("DROP TYPE IF EXISTS invoice_status CASCADE")
    op.execute("DROP TYPE IF EXISTS transaction_status CASCADE")
    op.execute("DROP TYPE IF EXISTS payment_type CASCADE")

    # --- Bookings ---
    op.execute("DROP TABLE IF EXISTS bookings CASCADE")
    op.execute("DROP TYPE IF EXISTS booking_type CASCADE")
    op.execute("DROP TYPE IF EXISTS booking_payment_status CASCADE")
    op.execute("DROP TYPE IF EXISTS booking_status CASCADE")

    # --- Team Members (+ studio custom roles, part of Team Management) ---
    op.execute("DROP TABLE IF EXISTS team_members CASCADE")
    op.execute("DROP TYPE IF EXISTS team_role CASCADE")
    op.execute("DROP TABLE IF EXISTS custom_roles CASCADE")

    # --- Studio UPI VPA (payments-only field on users) ---
    op.execute("ALTER TABLE users DROP COLUMN IF EXISTS upi_id")


def downgrade() -> None:
    raise NotImplementedError(
        "This migration intentionally drops the Bookings/Payments/Team "
        "Members feature tables. Restore from a pre-migration backup if "
        "you need this data back — there is no automatic downgrade."
    )
