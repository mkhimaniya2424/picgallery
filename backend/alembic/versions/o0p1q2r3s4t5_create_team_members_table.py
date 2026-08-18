"""create team_members table

Revision ID: o0p1q2r3s4t5
Revises: n9o0p1q2r3s4
Create Date: 2026-07-23 00:00:00.000000

"""

from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa
from sqlalchemy.dialects import postgresql


# revision identifiers, used by Alembic.
revision: str = "o0p1q2r3s4t5"
down_revision: Union[str, None] = "n9o0p1q2r3s4"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


team_role = postgresql.ENUM(
    "admin",
    "manager",
    "photographer",
    "editor",
    "viewer",
    name="team_role",
    create_type=False,
)


def upgrade() -> None:
    # Create enum only if it doesn't already exist
    team_role.create(op.get_bind(), checkfirst=True)

    op.create_table(
        "team_members",
        sa.Column(
            "id",
            postgresql.UUID(as_uuid=True),
            primary_key=True,
        ),
        sa.Column(
            "studio_id",
            postgresql.UUID(as_uuid=True),
            sa.ForeignKey("users.id", ondelete="CASCADE"),
            nullable=False,
        ),
        sa.Column(
            "full_name",
            sa.String(length=150),
            nullable=False,
        ),
        sa.Column(
            "email",
            sa.String(length=255),
            nullable=False,
        ),
        sa.Column(
            "phone",
            sa.String(length=30),
            nullable=False,
            server_default="",
        ),
        sa.Column(
            "role",
            team_role,
            nullable=False,
        ),
        sa.Column(
            "permissions",
            sa.String(length=500),
            nullable=True,
        ),
        sa.Column(
            "is_active",
            sa.Boolean(),
            nullable=False,
            server_default=sa.true(),
        ),
        sa.Column(
            "joined_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.Column(
            "updated_at",
            sa.DateTime(timezone=True),
            server_default=sa.func.now(),
        ),
        sa.UniqueConstraint(
            "studio_id",
            "email",
            name="uq_team_members_studio_email",
        ),
    )

    op.create_index( 
        "ix_team_members_studio_id",
        "team_members",
        ["studio_id"],
    )


def downgrade() -> None:
    op.drop_index(
        "ix_team_members_studio_id",
        table_name="team_members",
    )

    op.drop_table("team_members")

    team_role.drop(
        op.get_bind(),
        checkfirst=True,
    )