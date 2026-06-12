# ==============================================================
#  FaceInsight – backend/core/config.py
#  All settings loaded from .env via pydantic-settings
# ==============================================================

from functools import lru_cache
from typing import List
from pydantic import field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ── App ────────────────────────────────────────────────────
    APP_NAME: str = "FaceInsight"
    APP_ENV: str = "development"
    APP_DEBUG: bool = True
    APP_SECRET_KEY: str
    ALLOWED_HOSTS: str = "localhost,127.0.0.1"

    # ── API ────────────────────────────────────────────────────
    API_V1_PREFIX: str = "/api/v1"
    BACKEND_PORT: int = 8000

    # ── JWT ────────────────────────────────────────────────────
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    JWT_ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    JWT_REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # ── PostgreSQL ─────────────────────────────────────────────
    DATABASE_URL: str
    POSTGRES_USER: str = "faceinsight"
    POSTGRES_PASSWORD: str = "faceinsight_password"
    POSTGRES_DB: str = "faceinsight_db"
    POSTGRES_HOST: str = "postgres"
    POSTGRES_PORT: int = 5432

    # ── Redis ──────────────────────────────────────────────────
    REDIS_URL: str
    REDIS_HOST: str = "redis"
    REDIS_PORT: int = 6379
    REDIS_PASSWORD: str = ""

    # ── Celery ─────────────────────────────────────────────────
    CELERY_BROKER: str
    CELERY_BACKEND: str
    CELERY_TASK_ALWAYS_EAGER: bool = False

    # ── File Storage ───────────────────────────────────────────
    UPLOAD_DIR: str = "/app/media/uploads"
    PROCESSED_DIR: str = "/app/media/processed"
    MAX_UPLOAD_SIZE_MB: int = 10
    ALLOWED_IMAGE_TYPES: str = "image/jpeg,image/png,image/webp"

    # ── ML Models ──────────────────────────────────────────────
    ML_WEIGHTS_DIR: str = "/app/ml/weights"
    INSIGHTFACE_MODEL: str = "buffalo_l"
    YOLO_ACNE_MODEL: str = "yolov8n.pt"
    ML_DEVICE: str = "cpu"

    # ── WebSocket ──────────────────────────────────────────────
    WS_HEARTBEAT_INTERVAL: int = 30

    # ── Rate Limiting ──────────────────────────────────────────
    RATE_LIMIT_PER_MINUTE: int = 60
    RATE_LIMIT_UPLOAD_PER_HOUR: int = 20

    # ── CORS ───────────────────────────────────────────────────
    CORS_ORIGINS: str = "http://localhost,http://localhost:80"

    # ── Generative AI ──────────────────────────────────────────
    GROQ_API_KEY: str = ""
    QDRANT_URL: str = "http://qdrant:6333"

    # ── Cloudinary (Image Storage) ─────────────────────────────
    CLOUDINARY_CLOUD_NAME: str = ""
    CLOUDINARY_API_KEY: str = ""
    CLOUDINARY_API_SECRET: str = ""

    # ── Computed helpers ───────────────────────────────────────
    @property
    def allowed_hosts_list(self) -> List[str]:
        return [h.strip() for h in self.ALLOWED_HOSTS.split(",")]

    @property
    def cors_origins_list(self) -> List[str]:
        return [o.strip() for o in self.CORS_ORIGINS.split(",")]

    @property
    def allowed_image_types_list(self) -> List[str]:
        return [t.strip() for t in self.ALLOWED_IMAGE_TYPES.split(",")]

    @property
    def max_upload_size_bytes(self) -> int:
        return self.MAX_UPLOAD_SIZE_MB * 1024 * 1024

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"


@lru_cache()
def get_settings() -> Settings:
    """
    Cached settings instance.
    Use: from core.config import get_settings; settings = get_settings()
    """
    return Settings()