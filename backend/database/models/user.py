# ==============================================================
#  Model: User
#  Stores credentials + profile metadata.
#  Passwords are NEVER stored plain — only bcrypt hashes.
# ==============================================================

from typing import List, Optional

from sqlalchemy import Boolean, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database.base import Base, PKMixin, TimestampMixin


class User(PKMixin, TimestampMixin, Base):
    __tablename__ = "users"

    # ── Identity ───────────────────────────────────────────────
    email: Mapped[str] = mapped_column(
        String(255), unique=True, index=True, nullable=False
    )
    username: Mapped[str] = mapped_column(
        String(50), unique=True, index=True, nullable=False
    )
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)

    # ── Profile ────────────────────────────────────────────────
    full_name: Mapped[Optional[str]] = mapped_column(String(100))
    bio: Mapped[Optional[str]] = mapped_column(Text)
    avatar_url: Mapped[Optional[str]] = mapped_column(String(500))
    skin_type: Mapped[Optional[str]] = mapped_column(String(50))   # oily/dry/combination/normal

    # ── Account state ──────────────────────────────────────────
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, nullable=False)
    is_verified: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)
    is_admin: Mapped[bool] = mapped_column(Boolean, default=False, nullable=False)

    # ── Relationships ──────────────────────────────────────────
    analysis_jobs: Mapped[List["AnalysisJob"]] = relationship(  # noqa: F821
        "AnalysisJob",
        back_populates="user",
        cascade="all, delete-orphan",
        lazy="select",
    )

    def __repr__(self) -> str:
        return f"<User id={self.id} email={self.email!r}>"