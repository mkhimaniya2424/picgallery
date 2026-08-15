"""create bookings table

Revision ID: u5v6w7x8y9z0
Revises: t4u5v6w7x8y9
Create Date: 2026-07-27 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "u5v6w7x8y9z0"
down_revision: Union[str, None] = "t4u5v6w7x8y9"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


booking_status = postgresql.ENUM(
    "inquiry",
    "pending",
    "confirmed",
    "rescheduled",
    "inProgress",
    "completed",
    "cancelled",
    name="booking_status",
    create_type=False,
)

booking_payment_status = postgresql.ENUM(
    "unpaid",
    "partial",
    "paid",
    "overdue",
    name="booking_payment_status",
    create_type=False,
)

booking_type = postgresql.ENUM(
    "wedding",
    "preWedding",
    "birthday",
    "maternity",
    "portrait",
    "corporate",
    "product",
    "other",
    name="booking_type",
    create_type=False,
)


def upgrade() -> None:
    booking_status.create(op.get_bind(), checkfirst=True)
    booking_payment_status.create(op.get_bind(), checkfirst=True)
    booking_type.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "bookings",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "studio_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("booking_number", sa.String(length=30), nullable=False),
        sa.Column("title", sa.String(length=200), nullable=False),
        sa.Column("client_id", sa.String(length=100), nullable=False),
        sa.Column("booking_type", booking_type, nullable=False),
        sa.Column("start_datetime", sa.DateTime(timezone=True), nullable=False),
        sa.Column("end_datetime", sa.DateTime(timezone=True), nullable=False),
        sa.Column("venue_name", sa.String(length=200), nullable=False, server_default=""),
        sa.Column("address", sa.String(length=500), nullable=False, server_default=""),
        sa.Column("location_details", sa.String(length=500), nullable=False, server_default=""),
        sa.Column("description", sa.Text(), nullable=False, server_default=""),
        sa.Column("status", booking_status, nullable=False, server_default="inquiry"),
        sa.Column(
            "payment_status", booking_payment_status, nullable=False, server_default="unpaid"
        ),
        sa.Column("total_amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("paid_amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("invoice_id", sa.String(length=100), nullable=True),
        sa.Column("team_member_ids", sa.String(length=1000), nullable=True),
        sa.Column("album_id", sa.String(length=100), nullable=True),
        sa.Column("gallery_id", sa.String(length=100), nullable=True),
        sa.Column("internal_notes", sa.Text(), nullable=False, server_default=""),
        sa.Column("client_notes", sa.Text(), nullable=False, server_default=""),
        sa.Column("cancelled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("cancellation_reason", sa.Text(), nullable=False, server_default=""),
        sa.Column("rescheduled_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("reschedule_reason", sa.Text(), nullable=False, server_default=""),
        sa.Column("payment_due_date", sa.DateTime(timezone=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    op.create_index("ix_bookings_studio_id", "bookings", ["studio_id"])
    op.create_index("ix_bookings_client_id", "bookings", ["client_id"])
    op.create_index("ix_bookings_status", "bookings", ["status"])
    op.create_index("ix_bookings_start_datetime", "bookings", ["start_datetime"])


def downgrade() -> None:
    op.drop_index("ix_bookings_start_datetime", table_name="bookings")
    op.drop_index("ix_bookings_status", table_name="bookings")
    op.drop_index("ix_bookings_client_id", table_name="bookings")
    op.drop_index("ix_bookings_studio_id", table_name="bookings")

    op.drop_table("bookings")

    booking_type.drop(op.get_bind(), checkfirst=True)
    booking_payment_status.drop(op.get_bind(), checkfirst=True)
    booking_status.drop(op.get_bind(), checkfirst=True)
