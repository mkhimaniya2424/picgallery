"""create notifications table

Revision ID: m8n9o0p1q2r3
Revises: l7m8n9o0p1q2
Create Date: 2026-07-23 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

# revision identifiers, used by Alembic.
revision: str = "m8n9o0p1q2r3"
down_revision: Union[str, None] = "l7m8n9o0p1q2"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # Create ENUM only if it doesn't already exist
    notification_type_enum = postgresql.ENUM(
        "reminder",
        "approval",
        "booking",
        "gallery",
        "connection",
        "system",
        name="notification_type",
        create_type=False,
    )

    notification_type_enum.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "notifications",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "user_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "type",
            notification_type_enum,
            nullable=False,
        ),
        sa.Column(
            "title",
            sa.String(length=150),
            nullable=False,
        ),
        sa.Column(
            "subtitle",
            sa.String(length=500),
            nullable=False,
        ),
        sa.Column(
            "data",
            postgresql.JSONB(),
            nullable=True,
        ),
        sa.Column(
            "is_read",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
    )

    op.create_index(
        "ix_notifications_user_id",
        "notifications",
        ["user_id"],
    )

    op.create_index(
        "ix_notifications_created_at",
        "notifications",
        ["created_at"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_notifications_created_at",
        table_name="notifications",
    )

    op.drop_index(
        "ix_notifications_user_id",
        table_name="notifications",
    )

    op.drop_table("notifications")

    postgresql.ENUM(
        name="notification_type"
    ).drop(
        op.get_bind(),
        checkfirst=True,
    )