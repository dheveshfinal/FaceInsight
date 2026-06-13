#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting FaceInsight Backend"
echo "=========================================="

# Run migrations
echo "📦 Running database migrations..."
alembic upgrade head

# Start Celery worker in background
echo "🚀 Starting Celery worker..."
celery -A workers.celery_app worker --loglevel=info --concurrency=1 &
CELERY_PID=$!
echo "✅ Celery worker started (PID: $CELERY_PID)"

# Give Celery a moment to connect
sleep 2

# Start API server (use PORT env var or default to 8000)
PORT=${PORT:-8000}
echo "🚀 Starting Uvicorn API on port $PORT..."
uvicorn main:app --host 0.0.0.0 --port $PORT

# Cleanup on exit
trap "kill $CELERY_PID" EXIT