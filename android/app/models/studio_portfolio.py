import uuid
from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class StudioPortfolioImage(Base):
    """One image in a studio's "Showcase Portfolio" grid, shown on its
    public profile (Edit Studio Profile screen -> Showcase Portfolio
    card, and the client-facing studio_profile_screen.dart gallery).

    `owner_id` is always a photographer-role `User` row — enforced in
    the route layer (`get_current_studio_user` in
    `api/routes/studios.py`), same pattern as `StudioFavorite.studio_id`.
    `display_order` lets the studio reorder the grid later; images are
    listed newest-first by default (see GET /studios/me/portfolio),
    ties broken by `display_order`.
    """

    __tablename__ = "studio_portfolio_images"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True
    )
    relative_path: Mapped[str] = mapped_column(String(500), nullable=False)
    display_order: Mapped[int] = mapped_column(Integer, default=0, nullable=False)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=func.now())