# ==============================================================
#  Model: Recommendation
#  Personalised skincare advice derived from FaceAnalysis.
#  One row per advice card; ordered by priority.
# ==============================================================

from typing import Optional

from sqlalchemy import ForeignKey, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database.base import Base, PKMixin, TimestampMixin


class Recommendation(PKMixin, TimestampMixin, Base):
    __tablename__ = "recommendations"

    face_analysis_id: Mapped[int] = mapped_column(
        ForeignKey("face_analyses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Content ────────────────────────────────────────────────
    category: Mapped[str]  = mapped_column(String(50), nullable=False)
    # e.g. "cleanser", "moisturiser", "spf", "lifestyle", "diet"

    title:       Mapped[str]           = mapped_column(String(200), nullable=False)
    description: Mapped[str]           = mapped_column(Text,        nullable=False)
    priority:    Mapped[int]           = mapped_column(Integer, default=0)   # lower = higher priority
    source_condition: Mapped[Optional[str]] = mapped_column(String(50))      # which condition triggered this

    # ── Relationship ───────────────────────────────────────────
    face_analysis: Mapped["FaceAnalysis"] = relationship(  # noqa: F821
        "FaceAnalysis", back_populates="recommendations"
    )

    def __repr__(self) -> str:
        return (
            f"<Recommendation id={self.id} category={self.category!r} "
            f"title={self.title!r} priority={self.priority}>"
        )