"""create activity log table

Revision ID: v6w7x8y9z0a1
Revises: u5v6w7x8y9z0
Create Date: 2026-07-28 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "v6w7x8y9z0a1"
down_revision: Union[str, None] = "u5v6w7x8y9z0"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


activity_type = postgresql.ENUM(
    "upload",
    "album",
    "client",
    "booking",
    "gallery",
    "profile",
    "qr",
    "report",
    name="activity_type",
    create_type=False,
)


def upgrade() -> None:
    activity_type.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "activity_log",
        sa.Column("id", postgresql.UUID(as_uuid=True), primary_key=True),
        sa.Column(
            "studio_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column("type", activity_type, nullable=False),
        sa.Column("title", sa.String(length=150), nullable=False),
        sa.Column("subtitle", sa.String(length=500), nullable=False, server_default=""),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now()),
    )

    op.create_index("ix_activity_log_studio_id", "activity_log", ["studio_id"])
    op.create_index("ix_activity_log_created_at", "activity_log", ["created_at"])


def downgrade() -> None:
    op.drop_index("ix_activity_log_created_at", table_name="activity_log")
    op.drop_index("ix_activity_log_studio_id", table_name="activity_log")

    op.drop_table("activity_log")

    activity_type.drop(op.get_bind(), checkfirst=True)
