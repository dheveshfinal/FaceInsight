#!/bin/bash
set -e

echo "=========================================="
echo "🚀 Starting FaceInsight Backend"
echo "=========================================="

# Run migrations
echo "📦 Running database migrations..."
alembic upgrade head



# Start API server (use PORT env var or default to 8000)
PORT=${PORT:-8000}
echo "🚀 Starting Uvicorn API on port $PORT..."
uvicorn main:app --host 0.0.0.0 --port $PORT
