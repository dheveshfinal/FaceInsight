#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting FaceInsight Backend"
echo "=========================================="

# Default PORT for supervisord's %(ENV_PORT)s substitution
export PORT=${PORT:-8000}

# Run DB migrations
echo "📦 Running database migrations..."
alembic upgrade head

# Hand off to supervisord — it manages Uvicorn + Celery independently.
# If Celery crashes, only Celery restarts. If Uvicorn crashes, only
# Uvicorn restarts. SIGTERM to supervisord does a graceful shutdown
# of both children, then supervisord exits cleanly.
echo "🚀 Starting supervisord (manages Uvicorn + Celery)..."
exec supervisord -c /app/supervisord.conf
