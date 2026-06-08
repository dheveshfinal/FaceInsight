# ==============================================================
#  Model: FaceAnalysis
#  InsightFace output: one row per job (one face analysed).
#  Stores bounding box, landmarks, and scalar predictions.
# ==============================================================

from typing import Optional

from sqlalchemy import Float, ForeignKey, Integer, JSON, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database.base import Base, PKMixin, TimestampMixin


class FaceAnalysis(PKMixin, TimestampMixin, Base):
    __tablename__ = "face_analyses"

    job_id: Mapped[int] = mapped_column(
        ForeignKey("analysis_jobs.id", ondelete="CASCADE"),
        nullable=False,
        unique=True,    # one-to-one with AnalysisJob
        index=True,
    )

    # ── Detection ──────────────────────────────────────────────
    detection_confidence: Mapped[Optional[float]] = mapped_column(Float)

    # Bounding box — stored as four columns (fast range queries)
    bbox_x1: Mapped[Optional[int]] = mapped_column(Integer)
    bbox_y1: Mapped[Optional[int]] = mapped_column(Integer)
    bbox_x2: Mapped[Optional[int]] = mapped_column(Integer)
    bbox_y2: Mapped[Optional[int]] = mapped_column(Integer)

    # 5 or 68-point landmarks as JSON [[x,y], ...]
    landmarks: Mapped[Optional[dict]] = mapped_column(JSON)

    # ── Attributes ─────────────────────────────────────────────
    age_estimate:    Mapped[Optional[float]] = mapped_column(Float)
    gender:          Mapped[Optional[str]]   = mapped_column(String(10))   # "male"/"female"
    gender_confidence: Mapped[Optional[float]] = mapped_column(Float)

    # ── Skin tone ──────────────────────────────────────────────
    skin_tone_hex:   Mapped[Optional[str]]   = mapped_column(String(7))    # "#RRGGBB"
    skin_tone_label: Mapped[Optional[str]]   = mapped_column(String(50))   # e.g. "medium"

    # ── Geometry scores (0-1 floats) ───────────────────────────
    symmetry_score:    Mapped[Optional[float]] = mapped_column(Float)
    golden_ratio_score:Mapped[Optional[float]] = mapped_column(Float)
    face_shape:        Mapped[Optional[str]]   = mapped_column(String(30))  # oval/round/…

    # ── Relationships ──────────────────────────────────────────
    job: Mapped["AnalysisJob"] = relationship(  # noqa: F821
        "AnalysisJob", back_populates="face_analysis"
    )
    skin_conditions: Mapped[list["SkinCondition"]] = relationship(  # noqa: F821
        "SkinCondition",
        back_populates="face_analysis",
        cascade="all, delete-orphan",
    )
    recommendations: Mapped[list["Recommendation"]] = relationship(  # noqa: F821
        "Recommendation",
        back_populates="face_analysis",
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return (
            f"<FaceAnalysis id={self.id} job_id={self.job_id} "
            f"age={self.age_estimate} gender={self.gender!r}>"
        )