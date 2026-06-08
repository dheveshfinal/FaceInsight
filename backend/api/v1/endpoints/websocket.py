# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/websocket.py
#  WebSocket for real-time job progress updates
# ==============================================================

from fastapi import APIRouter, WebSocket, Depends
from loguru import logger
import json

from core.dependecies import get_current_user, get_db_async
from database.models import User

router = APIRouter()

# ── WS /ws/job-progress – Real-time job progress ───────────────


@router.websocket("/job-progress")
async def websocket_job_progress(
    websocket: WebSocket,
    job_id: int,
    token: str,
):
    """
    WebSocket endpoint for real-time job progress updates.
    
    Connect:
        ws://localhost/ws/job-progress?job_id=123&token=<JWT>
    
    Receive messages:
        { "status": "processing", "progress": 0.5, "stage": "Analyzing…" }
    
    TODO: Implement real WebSocket logic with Celery task result streaming
    """
    try:
        await websocket.accept()
        logger.info(f"WS connected: job_id={job_id}")

        # TODO: Subscribe to Celery task updates + stream to client
        # For now, just accept connection

        while True:
            data = await websocket.receive_text()
            logger.info(f"WS received: {data}")

    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        await websocket.close()
