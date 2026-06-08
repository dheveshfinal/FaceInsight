# ==============================================================
#  FaceInsight – backend/database/session.py
#  Async SQLAlchemy engine + session factory
# ==============================================================

from typing import AsyncGenerator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import (
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.pool import NullPool

from core.config import get_settings

settings = get_settings()

# ── Engine ─────────────────────────────────────────────────────
# NullPool is recommended for async + pgbouncer/serverless envs.
# For long-running servers swap to AsyncAdaptedQueuePool.
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=settings.APP_DEBUG,          # SQL logging in dev
    future=True,
    poolclass=NullPool,
)

# ── Session factory ────────────────────────────────────────────
AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,           # safe for async; avoids lazy-load errors
    autoflush=False,
    autocommit=False,
)


# ── Startup health-check ───────────────────────────────────────
async def init_db() -> None:
    """Verify the database is reachable at application startup."""
    async with engine.connect() as conn:
        await conn.execute(text("SELECT 1"))


# ── FastAPI dependency ─────────────────────────────────────────
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Yield an AsyncSession; roll back on error, always close."""
    async with AsyncSessionLocal() as session:
        try:
            yield session
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()