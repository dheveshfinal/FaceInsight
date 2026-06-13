#!/bin/bash
set -e
alembic upgrade head
celery -A workers.celery_app worker --loglevel=info --concurrency=1 &
uvicorn main:app --host 0.0.0.0 --port $PORT