"""create payment tables (transactions, invoices, payment_methods)

Revision ID: b2c3d4e5f6a7
Revises: a3b5c7d9e1f2
Create Date: 2026-07-31 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "b2c3d4e5f6a7"
down_revision: Union[str, None] = "a3b5c7d9e1f2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


payment_type = postgresql.ENUM(
    "subscription",
    "invoice",
    name="payment_type",
    create_type=False,
)

transaction_status = postgresql.ENUM(
    "pending",
    "submitted",
    "completed",
    "failed",
    "refunded",
    name="transaction_status",
    create_type=False,
)

invoice_status = postgresql.ENUM(
    "paid",
    "unpaid",
    "overdue",
    "cancelled",
    name="invoice_status",
    create_type=False,
)

payment_method_type = postgresql.ENUM(
    "creditCard",
    "debitCard",
    "bankAccount",
    "paypal",
    name="payment_method_type",
    create_type=False,
)


def upgrade() -> None:
    payment_type.create(op.get_bind(), checkfirst=True)
    transaction_status.create(op.get_bind(), checkfirst=True)
    invoice_status.create(op.get_bind(), checkfirst=True)
    payment_method_type.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "transactions",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "owner_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("transaction_ref", sa.String(length=64), nullable=False),
        sa.Column("payment_type", payment_type, nullable=False),
        sa.Column("status", transaction_status, nullable=False, server_default="pending"),
        sa.Column("description", sa.String(length=255), nullable=False, server_default=""),
        sa.Column("client_name", sa.String(length=150), nullable=False, server_default=""),
        sa.Column("amount", sa.Numeric(10, 2), nullable=False),
        sa.Column("invoice_id", sa.String(length=100), nullable=True),
        sa.Column("payee_vpa", sa.String(length=100), nullable=False),
        sa.Column("payee_name", sa.String(length=150), nullable=False),
        sa.Column("upi_txn_id", sa.String(length=100), nullable=True),
        sa.Column("upi_txn_ref", sa.String(length=100), nullable=True),
        sa.Column("upi_response_code", sa.String(length=50), nullable=True),
        sa.Column("upi_raw_status", sa.String(length=50), nullable=True),
        sa.Column("upi_approval_ref", sa.String(length=100), nullable=True),
        sa.Column("reported_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("confirmed_at", sa.DateTime(timezone=True), nullable=True),
        sa.Column("confirmed_by", postgresql.UUID(as_uuid=True), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_unique_constraint("uq_transactions_transaction_ref", "transactions", ["transaction_ref"])
    op.create_index("ix_transactions_owner_id", "transactions", ["owner_id"])
    op.create_index("ix_transactions_transaction_ref", "transactions", ["transaction_ref"])
    op.create_index("ix_transactions_status", "transactions", ["status"])
    op.create_index("ix_transactions_invoice_id", "transactions", ["invoice_id"])

    op.create_table(
        "invoices",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "owner_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("invoice_number", sa.String(length=30), nullable=False),
        sa.Column("client_id", sa.String(length=100), nullable=True),
        sa.Column("client_name", sa.String(length=150), nullable=False, server_default=""),
        sa.Column("date", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()),
        sa.Column("due_date", sa.DateTime(timezone=True), nullable=False),
        sa.Column("amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("paid_amount", sa.Numeric(10, 2), nullable=False, server_default="0"),
        sa.Column("status", invoice_status, nullable=False, server_default="unpaid"),
        sa.Column("line_items", postgresql.JSONB(), nullable=False, server_default="[]"),
        sa.Column("notes", sa.Text(), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
        sa.Column("updated_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_invoices_owner_id", "invoices", ["owner_id"])
    op.create_index("ix_invoices_client_id", "invoices", ["client_id"])
    op.create_index("ix_invoices_status", "invoices", ["status"])

    op.create_table(
        "payment_methods",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "owner_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("type", payment_method_type, nullable=False),
        sa.Column("last_four_digits", sa.String(length=4), nullable=False, server_default=""),
        sa.Column("expiry_date", sa.String(length=10), nullable=True),
        sa.Column("cardholder_name", sa.String(length=150), nullable=False, server_default=""),
        sa.Column("is_default", sa.Boolean(), nullable=False, server_default=sa.false()),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )
    op.create_index("ix_payment_methods_owner_id", "payment_methods", ["owner_id"])


def downgrade() -> None:
    op.drop_index("ix_payment_methods_owner_id", table_name="payment_methods")
    op.drop_table("payment_methods")

    op.drop_index("ix_invoices_status", table_name="invoices")
    op.drop_index("ix_invoices_client_id", table_name="invoices")
    op.drop_index("ix_invoices_owner_id", table_name="invoices")
    op.drop_table("invoices")

    op.drop_index("ix_transactions_invoice_id", table_name="transactions")
    op.drop_index("ix_transactions_status", table_name="transactions")
    op.drop_index("ix_transactions_transaction_ref", table_name="transactions")
    op.drop_constraint("uq_transactions_transaction_ref", "transactions", type_="unique")
    op.drop_table("transactions")

    payment_method_type.drop(op.get_bind(), checkfirst=True)
    invoice_status.drop(op.get_bind(), checkfirst=True)
    transaction_status.drop(op.get_bind(), checkfirst=True)
    payment_type.drop(op.get_bind(), checkfirst=True)
