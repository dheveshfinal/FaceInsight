#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting Celery Worker (Free Tier Mode)"
echo "=========================================="

# Export PYTHONPATH to ensure Python can find the 'database' module
export PYTHONPATH=$(pwd)

# Start Celery worker in background
echo "🚀 Starting Celery..."
celery -A workers.celery_app worker -Q celery,ml_queue,default --loglevel=info --concurrency=1 --max-tasks-per-child=10 &
CELERY_PID=$!
echo "✅ Celery worker started (PID: $CELERY_PID)"

# ── FREE TIER HACK ─────────────────────────────────────────────
# Render's free tier requires a Web Service, which MUST bind to 
# a port within 60 seconds. Celery is not a web server.
# We run a dummy HTTP server so Render thinks it's a web service.
PORT=${PORT:-8000}
echo "🚀 Starting dummy web server on port $PORT to satisfy Render..."
python -m http.server $PORT &
HTTP_PID=$!

# Cleanup on exit
trap "kill $CELERY_PID $HTTP_PID" EXIT

# Wait indefinitely so the script doesn't exit
wait
