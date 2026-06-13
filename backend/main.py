# ==============================================================
#  FaceInsight – backend/main.py
#  FastAPI application entry point
# ==============================================================

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.staticfiles import StaticFiles
from loguru import logger
import sys
import os

from core.config import get_settings
from core.exceptions import register_exception_handlers
from database.session import init_db
from api.v1.endpoints import (
    auth,
    upload,
    analysis,
    results,
    reports,
    websocket,
    chat,
)

settings = get_settings()

# ── Loguru setup ───────────────────────────────────────────────
logger.remove()
logger.add(
    sys.stdout,
    format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | "
           "<level>{level: <8}</level> | "
           "<cyan>{name}</cyan>:<cyan>{line}</cyan> | "
           "<level>{message}</level>",
    level="DEBUG" if settings.APP_DEBUG else "INFO",
    colorize=True,
)


# ── Lifespan (startup / shutdown) ──────────────────────────────
@asynccontextmanager
async def lifespan(app: FastAPI):
    # ── Startup ────────────────────────────────────────────────
    logger.info(f"Starting {settings.APP_NAME} [{settings.APP_ENV}]")

    # Ensure media directories exist
    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    os.makedirs(settings.PROCESSED_DIR, exist_ok=True)
    os.makedirs(settings.ML_WEIGHTS_DIR, exist_ok=True)
    logger.info("Media directories ready")

    # Test DB connection
    await init_db()
    logger.info("Database connection verified")

    # Test Celery connection
    try:
        from workers.celery_app import celery_app
        celery_app.connection()
        logger.info(f"✅ Celery broker connected: {settings.CELERY_BROKER}")
    except Exception as e:
        logger.warning(f"⚠️  Celery broker unavailable (workers may be down): {e}")

    logger.info(f"{settings.APP_NAME} is ready on port {settings.BACKEND_PORT}")

    yield

    # ── Shutdown ───────────────────────────────────────────────
    logger.info(f"{settings.APP_NAME} shutting down...")


# ── App factory ────────────────────────────────────────────────
def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        description="AI Skin & Facial Analysis Platform API",
        version="1.0.0",
        docs_url="/docs" if not settings.is_production else None,
        redoc_url="/redoc" if not settings.is_production else None,
        openapi_url="/openapi.json" if not settings.is_production else None,
        lifespan=lifespan,
    )

    # ── Middleware ─────────────────────────────────────────────
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins_list,
        allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=settings.allowed_hosts_list + ["*"],
    )

    # ── Exception handlers ─────────────────────────────────────
    register_exception_handlers(app)

    # ── Routers ────────────────────────────────────────────────
    prefix = settings.API_V1_PREFIX

    app.include_router(auth.router,      prefix=f"{prefix}/auth",     tags=["Auth"])
    app.include_router(upload.router,    prefix=f"{prefix}/upload",   tags=["Upload"])
    app.include_router(analysis.router,  prefix=f"{prefix}/analyze",  tags=["Analysis"])
    app.include_router(results.router,   prefix=f"{prefix}/results",  tags=["Results"])
    app.include_router(reports.router,   prefix=f"{prefix}/report",   tags=["Reports"])
    app.include_router(chat.router,      prefix=f"{prefix}/chat",     tags=["Chat"])
    app.include_router(websocket.router, prefix="/ws",                 tags=["WebSocket"])

    # ── Health check ───────────────────────────────────────────
    @app.get("/health", tags=["Health"])
    async def health_check():
        return {
            "status": "ok",
            "app": settings.APP_NAME,
            "env": settings.APP_ENV,
        }

    return app


app = create_app()