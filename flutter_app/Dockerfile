# ==============================================================
#  FaceInsight – flutter_app/Dockerfile
#  Builds Flutter web and serves via nginx-alpine
# ==============================================================

# ── Stage 1: Build Flutter Web ─────────────────────────────────
FROM debian:bookworm-slim AS builder

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    xz-utils \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter SDK
ENV FLUTTER_VERSION=3.22.2
ENV FLUTTER_HOME=/flutter
ENV PATH="$FLUTTER_HOME/bin:$PATH"

RUN git clone --depth 1 --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git ${FLUTTER_HOME} && \
    flutter config --no-analytics && \
    flutter precache --web

WORKDIR /app
COPY . .

# Get packages and build for web
RUN flutter pub get && \
    flutter build web --release \
        --dart-define=API_BASE_URL=/api/v1 \
        --dart-define=WS_BASE_URL=/ws

# ── Stage 2: Serve with nginx ─────────────────────────────────
FROM nginx:alpine AS runtime

# Copy built Flutter web output
COPY --from=builder /app/build/web /usr/share/nginx/html

# Simple nginx config for SPA routing
RUN echo 'server { \
    listen 3000; \
    root /usr/share/nginx/html; \
    index index.html; \
    location / { \
        try_files $uri $uri/ /index.html; \
    } \
}' > /etc/nginx/conf.d/default.conf

EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]