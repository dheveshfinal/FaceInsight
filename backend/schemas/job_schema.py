# ==============================================================
#  FaceInsight – backend/schemas/job_schema.py
#  Pydantic models for job status responses
# ==============================================================

from typing import Optional
from pydantic import BaseModel


class JobStatusResponse(BaseModel):
    """Response for job status polling endpoint"""

    job_id: str
    status: str  # pending, processing, completed, failed
    progress: Optional[float] = None  # 0.0–1.0
    stage: Optional[str] = None  # Human-readable stage
    error_message: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "job_id": "123",
                "status": "processing",
                "progress": 0.45,
                "stage": "Mapping facial landmarks…",
                "error_message": None,
            }
        }
