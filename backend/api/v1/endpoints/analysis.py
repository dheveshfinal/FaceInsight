# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/analysis.py
#  Job status polling + job management
# ==============================================================

from fastapi import APIRouter, Depends, HTTPException
from loguru import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.dependecies import get_current_user, get_current_user_or_anonymous, get_db
from database.models import User, AnalysisJob, JobStatus
from schemas.job_schema import JobStatusResponse

router = APIRouter()

# ── GET /analyze/job/{job_id} – Get job status + progress ─────


@router.get("/job/{job_id}", response_model=JobStatusResponse, tags=["Analysis"])
async def get_job_status(
    job_id: int,
    current_user: User = Depends(get_current_user_or_anonymous),
    db: AsyncSession = Depends(get_db),
):
    """
    Get current status of an analysis job.
    
    Returns: { job_id, status, progress, stage, error_message }
    - progress: 0.0–1.0 if processing, null if pending/completed/failed
    - stage: Human-readable processing stage (e.g., "Detecting face…")
    """
    # Fetch job & verify ownership
    stmt = select(AnalysisJob).filter(
        AnalysisJob.id == job_id,
        AnalysisJob.user_id == current_user.id,
    )
    result = await db.execute(stmt)
    job = result.scalar_one_or_none()

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    logger.info(f"Job {job_id} status: {job.status}")

    # Build response with progress + stage based on job metadata
    progress = None
    stage = None

    # NOTE: In production, get progress from Celery task result backend
    # For now, return basic status
    if job.status == JobStatus.PROCESSING:
        # Placeholder: In real app, query task result for progress
        progress = 0.5
        stage = "Analyzing…"
    elif job.status == JobStatus.COMPLETED:
        progress = 1.0
        stage = "Complete!"
    elif job.status == JobStatus.FAILED:
        stage = "Failed"

    return JobStatusResponse(
        job_id=str(job_id),
        status=job.status.value,
        progress=progress,
        stage=stage,
        error_message=job.error_message,
    )


# ── GET /analyze/job – List all jobs for current user ─────────


@router.get("/job", tags=["Analysis"])
async def list_jobs(
    limit: int = 10,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    List analysis jobs for the current user (paginated).
    """
    stmt = (
        select(AnalysisJob)
        .filter(AnalysisJob.user_id == current_user.id)
        .order_by(AnalysisJob.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    jobs = result.scalars().all()

    return {
        "jobs": [
            {
                "job_id": str(j.id),
                "status": j.status.value,
                "created_at": j.created_at.isoformat(),
            }
            for j in jobs
        ],
        "count": len(jobs),
    }
