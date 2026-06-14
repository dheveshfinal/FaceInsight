# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/upload.py
#  Image upload endpoint → creates AnalysisJob + queues task
# ==============================================================

from fastapi import APIRouter, File, UploadFile, Depends, HTTPException
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from core.dependecies import get_current_user_or_anonymous, get_db
from database.models import User, AnalysisJob, AnalysisImage
from services.upload_service import UploadService
from services.ml_service import MLService

router = APIRouter()

# ── POST /upload/image – Upload image + create job ────────────


@router.post("/image", tags=["Upload"])
async def upload_image(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user_or_anonymous),
    db: AsyncSession = Depends(get_db),
):
    """
    Upload an image and create an AnalysisJob.
    
    Returns: { job_id, status, created_at }
    """
    if not file.content_type or "image" not in file.content_type:
        raise HTTPException(status_code=400, detail="File must be an image")

    try:
        # Validate + save image to Cloudinary
        upload_svc = UploadService()
        image_info = await upload_svc.save_image(
            file=file,
            user_id=current_user.id,
        )
        logger.info(f"Image uploaded to Cloudinary: {image_info['url']} for user {current_user.id}")

        mime_type = file.content_type or "image/jpeg"

        # Create AnalysisJob
        job = AnalysisJob(
            user_id=current_user.id,
            status="pending",
        )
        db.add(job)
        await db.flush()  # Get job.id before commit
        job_id = job.id

        # Create AnalysisImage link
        image = AnalysisImage(
            job_id=job_id,
            stored_filename=image_info["filename"],  # Cloudinary public_id
            original_filename=file.filename or "unknown",
            upload_path=image_info["url"],           # Cloudinary secure_url
            mime_type=mime_type,
            file_size_bytes=image_info["size_bytes"],
        )
        db.add(image)
        await db.commit()

        # Queue Celery task to run ML pipeline
        ml_svc = MLService()
        await ml_svc.queue_analysis_task(
            job_id=job_id,
            image_filename=image_info["url"],
        )
        logger.info(f"Queued ML task for job {job_id}")

        return {
            "job_id": str(job_id),
            "status": "pending",
            "created_at": job.created_at.isoformat(),
        }

    except Exception as e:
        logger.error(f"Upload failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))
