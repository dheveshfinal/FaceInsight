# ==============================================================
#  Model: AnalysisImage
#  Tracks file paths for both the raw upload and the
#  annotated/processed output image.
# ==============================================================

from typing import Optional

from sqlalchemy import ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database.base import Base, PKMixin, TimestampMixin


class AnalysisImage(PKMixin, TimestampMixin, Base):
    __tablename__ = "analysis_images"

    job_id: Mapped[int] = mapped_column(
        ForeignKey("analysis_jobs.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── File metadata ──────────────────────────────────────────
    original_filename: Mapped[str]  = mapped_column(String(255), nullable=False)
    stored_filename:   Mapped[str]  = mapped_column(String(255), nullable=False)   # UUID-based
    upload_path:       Mapped[str]  = mapped_column(String(500), nullable=False)
    processed_path:    Mapped[Optional[str]] = mapped_column(String(500))
    mime_type:         Mapped[str]  = mapped_column(String(50),  nullable=False)
    file_size_bytes:   Mapped[int]  = mapped_column(Integer,     nullable=False)

    # ── Image dimensions (filled after processing) ─────────────
    width_px:  Mapped[Optional[int]] = mapped_column(Integer)
    height_px: Mapped[Optional[int]] = mapped_column(Integer)

    # ── Relationship ───────────────────────────────────────────
    job: Mapped["AnalysisJob"] = relationship("AnalysisJob", back_populates="images")  # noqa: F821

    def __repr__(self) -> str:
        return f"<AnalysisImage id={self.id} job_id={self.job_id} file={self.stored_filename!r}>"