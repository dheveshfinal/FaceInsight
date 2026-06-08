# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/reports.py
#  Report generation + export
# ==============================================================

from fastapi import APIRouter, Depends, HTTPException
from loguru import logger

from core.dependecies import get_current_user
from database.models import User

router = APIRouter()

# ── GET /report/{job_id} – Generate PDF/JSON report ──────────


@router.get("/{job_id}", tags=["Reports"])
async def get_report(
    job_id: int,
    format: str = "json",
    current_user: User = Depends(get_current_user),
):
    """
    Generate a report for analysis results.
    format: 'json' or 'pdf'
    TODO: Implement report generation
    """
    logger.info(f"Report request: job_id={job_id}, format={format}")
    raise HTTPException(status_code=501, detail="Reports not yet implemented")
