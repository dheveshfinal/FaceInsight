# ==============================================================
#  FaceInsight – backend/database/base.py
#  Declarative base + shared mixin columns (id, timestamps)
# ==============================================================

from datetime import datetime, timezone

from sqlalchemy import DateTime, Integer, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class Base(DeclarativeBase):
    """Single declarative base shared by every model."""
    pass


class TimestampMixin:
    """
    Adds created_at + updated_at to any model.
    server_default / onupdate are DB-side so they work even on
    raw SQL inserts (e.g. migrations, seeds).
    """
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        onupdate=func.now(),
        nullable=False,
    )


class PKMixin:
    """Auto-incrementing integer primary key."""
    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)