# ==============================================================
#  FaceInsight – backend/workers/celery_app.py
#  Celery application instance
# ==============================================================

from celery import Celery
from core.config import get_settings

settings = get_settings()

# ── Celery App ─────────────────────────────────────────────────
celery_app = Celery(
    "faceinsight",
    broker=settings.CELERY_BROKER,
    backend=settings.CELERY_BACKEND,
    include=[
        "workers.tasks",  # task modules to auto-discover
    ],
)

# ── Configuration ──────────────────────────────────────────────
celery_app.conf.update(
    # Serialisation
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",

    # Timezone
    timezone="UTC",
    enable_utc=True,

    # Task routing
    task_routes={
        "workers.tasks.run_analysis_pipeline": {"queue": "ml_queue"},
    },

    # Result expiry (24 h)
    result_expires=86400,

    # Retry / reliability
    task_acks_late=True,
    task_reject_on_worker_lost=True,

    # Redis broker options (Upstash compatibility)
    broker_connection_retry_on_startup=True,
    broker_pool_limit=None,
    broker_connection_retry=True,
    broker_connection_max_retries=10,

    # Beat scheduler (redbeat)
    beat_scheduler="redbeat.RedBeatScheduler",
    redbeat_redis_url=settings.CELERY_BROKER,

    # Always-eager mode for tests (overridden by env)
    task_always_eager=settings.CELERY_TASK_ALWAYS_EAGER,
)

# ── Make importable as `celery_app` or `app` ──────────────────
app = celery_app
