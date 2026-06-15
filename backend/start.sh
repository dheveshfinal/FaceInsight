#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting FaceInsight Backend"
echo "=========================================="

# Run migrations
echo "📦 Running database migrations..."
alembic upgrade head



# Start Celery worker in the background with an auto-restart loop
echo "🚀 Starting embedded Celery worker..."
(
  while true; do
    echo "Starting celery..."
    celery -A workers.celery_app worker -Q celery,ml_queue,default --loglevel=info --concurrency=1 --max-tasks-per-child=10
    echo "Celery worker exited, restarting in 5s..."
    sleep 5
  done
) &

# Start API server (use PORT env var or default to 8000)
PORT=${PORT:-8000}
echo "🚀 Starting Uvicorn API on port $PORT..."
uvicorn main:app --host 0.0.0.0 --port $PORT
