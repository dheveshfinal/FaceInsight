# ==============================================================
#  Model: SkinCondition
#  YOLO / classifier detections — one row per detected region.
#  Multiple rows per FaceAnalysis (acne spots, dark circles, …)
# ==============================================================

from typing import Optional

from sqlalchemy import Float, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database.base import Base, PKMixin, TimestampMixin


class SkinCondition(PKMixin, TimestampMixin, Base):
    __tablename__ = "skin_conditions"

    face_analysis_id: Mapped[int] = mapped_column(
        ForeignKey("face_analyses.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Detection ──────────────────────────────────────────────
    condition_type: Mapped[str]  = mapped_column(String(50), nullable=False, index=True)
    # e.g. "acne", "dark_circles", "wrinkle", "hyperpigmentation"

    severity: Mapped[Optional[str]]   = mapped_column(String(20))   # mild/moderate/severe
    confidence: Mapped[Optional[float]] = mapped_column(Float)

    # YOLO bounding box for localised conditions (nullable for global)
    bbox_x1: Mapped[Optional[int]] = mapped_column(Integer)
    bbox_y1: Mapped[Optional[int]] = mapped_column(Integer)
    bbox_x2: Mapped[Optional[int]] = mapped_column(Integer)
    bbox_y2: Mapped[Optional[int]] = mapped_column(Integer)

    # Arbitrary extra attributes per condition type
    extra_data: Mapped[Optional[dict]] = mapped_column(JSON)

    # ── Relationship ───────────────────────────────────────────
    face_analysis: Mapped["FaceAnalysis"] = relationship(  # noqa: F821
        "FaceAnalysis", back_populates="skin_conditions"
    )

    def __repr__(self) -> str:
        return (
            f"<SkinCondition id={self.id} type={self.condition_type!r} "
            f"severity={self.severity!r} conf={self.confidence}>"
        )