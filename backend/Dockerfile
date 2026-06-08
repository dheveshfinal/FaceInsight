# ==============================================================
#  FaceInsight – backend/Dockerfile
#  Base: Python 3.11 slim (Debian Bookworm)
#  ML stack: InsightFace + MediaPipe + Ultralytics YOLO + OpenCV
# ==============================================================

# ── Stage 1: base system deps ──────────────────────────────────
FROM python:3.11-slim-bookworm AS base

# Prevent .pyc files and enable stdout logs immediately
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# System libraries required by OpenCV, InsightFace, MediaPipe
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential \
    cmake \
    git \
    # OpenCV runtime deps
    libglib2.0-0 \
    libsm6 \
    libxrender1 \
    libxext6 \
    libgl1 \
    libglvnd0 \
    # Image codecs
    libjpeg-dev \
    libpng-dev \
    libwebp-dev \
    libtiff-dev \
    # InsightFace / onnxruntime deps
    libgomp1 \
    libatlas-base-dev \
    # networking
    curl \
    wget \
    # clean up
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── Stage 2: Python deps ───────────────────────────────────────
FROM base AS builder

WORKDIR /install

COPY requirements.txt .

# Install in strict order to avoid conflicts:
# 1. numpy first (many ML libs need a specific numpy at build time)
# 2. PyTorch CPU (no CUDA on Windows Docker Desktop)
# 3. onnxruntime
# 4. opencv-python-headless (no GUI needed in Docker)
# 5. mediapipe
# 6. insightface
# 7. ultralytics (YOLO)
# 8. everything else

RUN pip install --upgrade pip setuptools wheel && \
    # Step 1 – numpy pinned version for compatibility
    pip install "numpy>=1.24,<2.0" && \
    # Step 2 – PyTorch CPU only (keeps image size manageable)
    pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu && \
    # Step 3 – onnxruntime CPU
    pip install onnxruntime && \
    # Step 4 – OpenCV headless
    pip install opencv-python-headless && \
    # Step 5 – MediaPipe (must come after opencv)
    pip install mediapipe && \
    # Step 6 – InsightFace (must come after onnxruntime + opencv)
    pip install insightface && \
    # Step 7 – Ultralytics YOLO (must come after torch)
    pip install ultralytics && \
    # Step 8 – everything else from requirements.txt
    pip install -r requirements.txt

# ── Stage 3: final runtime image ──────────────────────────────
FROM base AS runtime

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages /usr/local/lib/python3.11/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

# Copy application source
COPY . .

# Create media directories
RUN mkdir -p /app/media/uploads /app/media/processed /app/ml/weights

# Non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser && \
    chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# Default command (overridden by docker-compose)
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]