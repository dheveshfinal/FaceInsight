# ==============================================================
#  Model: AnalysisJob
#  One job = one user-submitted image going through the ML
#  pipeline. Tracks Celery task state end-to-end.
# ==============================================================

import enum
from typing import List, Optional

from sqlalchemy import Enum, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from database.base import Base, PKMixin, TimestampMixin


class JobStatus(str, enum.Enum):
    PENDING    = "pending"
    PROCESSING = "processing"
    COMPLETED  = "completed"
    FAILED     = "failed"


class AnalysisJob(PKMixin, TimestampMixin, Base):
    __tablename__ = "analysis_jobs"

    # ── Ownership ──────────────────────────────────────────────
    user_id: Mapped[int] = mapped_column(
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )

    # ── Celery task tracking ───────────────────────────────────
    celery_task_id: Mapped[Optional[str]] = mapped_column(String(255), index=True)
    status: Mapped[JobStatus] = mapped_column(
        Enum(JobStatus, name="job_status"),
        default=JobStatus.PENDING,
        nullable=False,
        index=True,
    )
    error_message: Mapped[Optional[str]] = mapped_column(Text)

    # ── Relationships ──────────────────────────────────────────
    user: Mapped["User"] = relationship("User", back_populates="analysis_jobs")  # noqa: F821

    images: Mapped[List["AnalysisImage"]] = relationship(  # noqa: F821
        "AnalysisImage",
        back_populates="job",
        cascade="all, delete-orphan",
    )
    face_analysis: Mapped[Optional["FaceAnalysis"]] = relationship(  # noqa: F821
        "FaceAnalysis",
        back_populates="job",
        uselist=False,          # one-to-one
        cascade="all, delete-orphan",
    )

    def __repr__(self) -> str:
        return f"<AnalysisJob id={self.id} status={self.status} user_id={self.user_id}>"