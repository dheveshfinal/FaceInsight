# ==============================================================
#  FaceInsight – backend/services/ml_service.py
#  Queue ML pipeline tasks via Celery (real dispatch)
# ==============================================================

from loguru import logger
from celery.exceptions import OperationalError
from workers.tasks import run_analysis_pipeline


class MLService:
    """Queue ML pipeline tasks via Celery"""

    async def queue_analysis_task(self, job_id: int, image_filename: str) -> str:
        """
        Queue image analysis task via Celery.
        Returns: celery_task_id
        """
        logger.info(f"Dispatching Celery task: job_id={job_id}, image={image_filename}")

        try:
            # Dispatch real Celery task
            task = run_analysis_pipeline.apply_async(
                args=[job_id, image_filename],
                queue="ml_queue",
            )

            logger.info(f"✅ Celery task queued successfully: {task.id}")
            return task.id
        except OperationalError as e:
            logger.error(f"❌ Celery broker connection failed: {e}")
            logger.error("Make sure Redis/Celery worker is running!")
            raise
        except Exception as e:
            logger.error(f"❌ Failed to queue Celery task: {e}")
            raise
