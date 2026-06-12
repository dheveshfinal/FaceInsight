# Render & Vercel Manual Setup - Copy/Paste Values

## 🏗️ RENDER - Environment Variables

### PostgreSQL Service (`faceinsight-postgres`)
```
POSTGRES_USER = faceinsight
POSTGRES_PASSWORD = [Generate: python -c "import secrets; print(secrets.token_urlsafe(24))"]
POSTGRES_DB = faceinsight_db
POSTGRES_INITDB_ARGS = -c max_connections=200
```

### Backend API Service (`faceinsight-api`)
```
PORT = 8000
APP_ENV = production
APP_DEBUG = false
APP_SECRET_KEY = [Generate: python -c "import secrets; print(secrets.token_urlsafe(32))"]
JWT_SECRET_KEY = [Generate: python -c "import secrets; print(secrets.token_urlsafe(32))"]
GROQ_API_KEY = [YOUR_GROQ_KEY from https://console.groq.com]
QDRANT_URL = https://your-cluster.qdrant.io
QDRANT_API_KEY = [YOUR_API_KEY from Qdrant Cloud dashboard]
CORS_ORIGINS = http://localhost:3000,https://YOUR-VERCEL-APP.vercel.app
ALLOWED_HOSTS = faceinsight-api.onrender.com,localhost
ML_DEVICE = cpu
MAX_UPLOAD_SIZE_MB = 10
```

### Celery Worker Service (`faceinsight-celery`)
```
APP_ENV = production
GROQ_API_KEY = [Same as above]
QDRANT_URL = https://your-cluster.qdrant.io
QDRANT_API_KEY = [Same as above]
ML_DEVICE = cpu
```

**DATABASE_URL, REDIS_URL, CELERY_BROKER, CELERY_BACKEND, QDRANT_URL** = Auto-set by Render ✅

---

## 🎨 VERCEL - Environment Variables

```
API_BASE_URL = https://faceinsight-api-XYZ.onrender.com/api/v1
WS_BASE_URL = wss://faceinsight-api-XYZ.onrender.com/ws
```

**Replace `faceinsight-api-XYZ` with your actual Render service URL**

---

## 📋 Manual Steps for Render

1. **Create PostgreSQL Service**
   - Type: PostgreSQL
   - Name: `faceinsight-postgres`
   - Add environment variables from above

2. **Create Redis Service**
   - Type: Redis
   - Name: `faceinsight-redis`

3. **Create Qdrant Service**
   - Type: Qdrant
   - Name: `faceinsight-qdrant`
   - Disk: 10GB at `/qdrant/storage`

4. **Create Web Service**
   - Type: Web Service
   - Name: `faceinsight-api`
   - GitHub: `https://github.com/dheveshfinal/faceinsight`
   - Root Directory: `backend`
   - Dockerfile: `./Dockerfile` (or `Dockerfile`)
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`
   - Add environment variables from above

5. **Create Background Worker Service**
   - Type: Background Worker
   - Name: `faceinsight-celery`
   - GitHub: `https://github.com/dheveshfinal/faceinsight`
   - Root Directory: `backend`
   - Dockerfile: `./Dockerfile` (or `Dockerfile`)
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `celery -A workers.celery_app worker --loglevel=info --concurrency=2`
   - Add environment variables from above

---

## 📋 Manual Steps for Vercel

1. Go to https://vercel.com
2. Click **Add New** → **Project**
3. Select `faceinsight` repository
4. Settings:
   - **Project Name**: `faceinsight-web`
   - **Root Directory**: `flutter_app`
   - **Framework**: Other
   - **Build Command**: `flutter build web --release`
5. Add Environment Variables:
   ```
   API_BASE_URL = https://faceinsight-api-XYZ.onrender.com/api/v1
   WS_BASE_URL = wss://faceinsight-api-XYZ.onrender.com/ws
   ```
6. Click **Deploy**

---

## 🔄 After Deploying Both

1. **Get your Vercel URL**: `https://your-app.vercel.app`
2. **Update Render CORS**:
   - Go to `faceinsight-api` service
   - Edit environment variable: `CORS_ORIGINS`
   - Set to: `http://localhost:3000,https://your-app.vercel.app`
   - Save & restart service

3. **Test**:
   - Open `https://your-app.vercel.app` in browser
   - Register account
   - Upload image
   - Check if it works ✅

---

## 🔑 Generate Secrets (Copy Commands)

Run in PowerShell:

```powershell
# APP_SECRET_KEY
python -c "import secrets; print(secrets.token_urlsafe(32))"

# JWT_SECRET_KEY  
python -c "import secrets; print(secrets.token_urlsafe(32))"

# POSTGRES_PASSWORD
python -c "import secrets; print(secrets.token_urlsafe(24))"
```

Copy each output into Render env vars.

---

## 📝 Summary Table

| Service | Name | Type |
|---------|------|------|
| Database | `faceinsight-postgres` | PostgreSQL |
| Cache | `faceinsight-redis` | Redis |
| Vector DB | `faceinsight-qdrant` | Qdrant |
| API | `faceinsight-api` | Web Service |
| Worker | `faceinsight-celery` | Background Worker |
| Frontend | `faceinsight-web` | Vercel Project |

---

**That's it! All the info you need for manual setup.** 🚀
