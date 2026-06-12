# FaceInsight Deployment Guide

Complete guide to deploy FaceInsight using Vercel (Frontend) and Render (Backend).

## Architecture Overview

```
┌─────────────────────────────────┐
│  Vercel (Flutter Web Frontend)  │
│  https://your-app.vercel.app    │
└────────────────┬────────────────┘
                 │ HTTPS/WebSocket
                 ▼
┌─────────────────────────────────┐
│  Render (FastAPI Backend)       │
│  https://faceinsight-api...     │
├─────────────────────────────────┤
│  • PostgreSQL Database          │
│  • Redis Cache/Queue            │
│  • Qdrant Vector DB             │
│  • Celery Worker                │
└─────────────────────────────────┘
                 │
        ┌────────┼────────┐
        ▼        ▼        ▼
    ┌───────┬────────┬──────────┐
    │ Groq  │Cloudinary│ OpenCV │
    │ (LLM) │ (Images)│ (ML)   │
    └───────┴────────┴──────────┘
```

---

## Prerequisites

Before deploying, ensure you have:

1. **Render Account** - [render.com](https://render.com)
2. **Vercel Account** - [vercel.com](https://vercel.com)
3. **GitHub Repository** - Push code to GitHub for CI/CD
4. **API Keys:**
   - Groq API Key - [console.groq.com](https://console.groq.com)
   - (Optional) Cloudinary - [cloudinary.com](https://cloudinary.com)
5. **Flutter SDK** - Installed locally
6. **Git** - For version control

---

## Part 1: Deploy Backend to Render

### Step 1: Push Code to GitHub

```bash
git init
git add .
git commit -m "Initial commit: FaceInsight application"
git branch -M main
git remote add origin https://github.com/yourusername/faceinsight.git
git push -u origin main
```

### Step 2: Create Render Account & Connect GitHub

1. Go to [render.com](https://render.com)
2. Sign up with GitHub
3. Authorize Render to access your repositories
4. Create a new Blueprint deployment

### Step 3: Deploy Using render.yaml

1. In Render Dashboard → **Blueprints** → **New Blueprint**
2. Select your `faceinsight` repository
3. Render will auto-detect `render.yaml`
4. Review the configuration:
   - 4 services will be deployed:
     - PostgreSQL
     - Redis
     - Qdrant
     - FastAPI Backend
     - Celery Worker

### Step 4: Configure Environment Variables

In Render Dashboard, set these for each service:

**Backend Service (`faceinsight-api`):**

```env
APP_ENV=production
APP_DEBUG=false
APP_SECRET_KEY=<generate-with: python -c "import secrets; print(secrets.token_urlsafe(32))">
JWT_SECRET_KEY=<generate-with: python -c "import secrets; print(secrets.token_urlsafe(32))">
GROQ_API_KEY=<your-groq-api-key>
CORS_ORIGINS=https://your-app.vercel.app,http://localhost:3000
ALLOWED_HOSTS=faceinsight-api.onrender.com,localhost
ML_DEVICE=cpu
```

**PostgreSQL Service:**

```env
POSTGRES_USER=faceinsight
POSTGRES_PASSWORD=<generate-strong-password>
POSTGRES_DB=faceinsight_db
```

### Step 5: Run Database Migrations

Once services are deployed:

1. Go to your API service dashboard
2. Click **Shell** tab
3. Run migrations:

```bash
cd backend
python -m alembic upgrade head
```

### Step 6: Verify Backend is Running

```bash
# Test the health endpoint
curl https://faceinsight-api.onrender.com/api/v1/health

# Expected response: {"status": "ok"}
```

### Step 7: Obtain Backend URLs

From Render Dashboard, note:
- **API URL**: `https://faceinsight-api.onrender.com`
- **WebSocket URL**: `wss://faceinsight-api.onrender.com/ws`

---

## Part 2: Deploy Frontend to Vercel

### Step 1: Install Vercel CLI

```bash
npm install -g vercel
# or
curl https://cli.vercel.com -fsSL | sh
```

### Step 2: Login to Vercel

```bash
vercel login
```

### Step 3: Configure Environment Variables

Create `.env.local` in the `flutter_app` directory:

```env
API_BASE_URL=https://faceinsight-api.onrender.com/api/v1
WS_BASE_URL=wss://faceinsight-api.onrender.com/ws
```

Or set in Vercel Dashboard:

1. Go to **Project Settings** → **Environment Variables**
2. Add:
   - `API_BASE_URL` = `https://faceinsight-api.onrender.com/api/v1`
   - `WS_BASE_URL` = `wss://faceinsight-api.onrender.com/ws`

### Step 4: Build Flutter Web

```bash
cd flutter_app

# Build with environment variables
flutter build web \
  --web-renderer html \
  --dart-define API_BASE_URL=https://faceinsight-api.onrender.com/api/v1 \
  --dart-define WS_BASE_URL=wss://faceinsight-api.onrender.com/ws \
  --release
```

### Step 5: Deploy to Vercel

```bash
# From flutter_app directory
vercel --prod

# Answer prompts:
# - Project name: faceinsight-flutter-web
# - Directory: ./build/web
# - Build command: (skip, already built)
# - Output directory: (default)
```

### Step 6: Set Vercel Environment Variables

In Vercel Dashboard:

1. Go to **Project Settings** → **Environment Variables**
2. Add:
   ```
   API_BASE_URL=https://faceinsight-api.onrender.com/api/v1
   WS_BASE_URL=wss://faceinsight-api.onrender.com/ws
   ```

### Step 7: Enable Auto-Deployment

1. In Vercel Dashboard → **Settings** → **Git**
2. Connect GitHub repository
3. Set production branch to `main`
4. Enable **Automatic Deployments**

Now every git push triggers a new build automatically!

---

## Part 3: Connect Frontend ↔ Backend

### Update Backend CORS Settings

In Render environment variables, update:

```env
CORS_ORIGINS=https://your-app.vercel.app,http://localhost:3000
```

### Update Frontend API URL

In Flutter app, the `ApiClient` will read from dart-define:

```bash
# Rebuild with new API URL
flutter build web \
  --dart-define API_BASE_URL=https://faceinsight-api.onrender.com/api/v1 \
  --dart-define WS_BASE_URL=wss://faceinsight-api.onrender.com/ws \
  --release
```

---

## Part 4: Cloudinary Integration (Optional)

For image storage in the cloud:

### Step 1: Create Cloudinary Account

1. Go to [cloudinary.com](https://cloudinary.com)
2. Sign up (free tier available)
3. Go to **Dashboard** → copy:
   - Cloud Name
   - API Key
   - API Secret

### Step 2: Add to Backend Environment

In Render, add:

```env
CLOUDINARY_CLOUD_NAME=your-cloud-name
CLOUDINARY_API_KEY=your-api-key
CLOUDINARY_API_SECRET=your-api-secret
```

### Step 3: Update Upload Service

Modify `backend/services/upload_service.py`:

```python
import cloudinary
import cloudinary.uploader

# Configure Cloudinary
cloudinary.config(
    cloud_name=settings.CLOUDINARY_CLOUD_NAME,
    api_key=settings.CLOUDINARY_API_KEY,
    api_secret=settings.CLOUDINARY_API_SECRET
)

async def upload_to_cloudinary(file_bytes):
    result = cloudinary.uploader.upload(file_bytes, folder="faceinsight")
    return result['secure_url']
```

---

## Troubleshooting

### Backend not responding

```bash
# Check logs in Render
curl https://faceinsight-api.onrender.com/api/v1/health

# If 502, check database connection
# In Render Shell:
python -c "from database.session import SessionLocal; db = SessionLocal(); print('DB OK')"
```

### Frontend API calls failing

1. Check browser console (F12) for CORS errors
2. Verify `API_BASE_URL` is set in Vercel env vars
3. Ensure backend CORS includes frontend URL

```bash
# Test API from frontend
curl -H "Origin: https://your-app.vercel.app" \
  https://faceinsight-api.onrender.com/api/v1/health
```

### WebSocket connection issues

```bash
# Test WebSocket from browser console
const ws = new WebSocket('wss://faceinsight-api.onrender.com/ws/job-progress');
ws.onopen = () => console.log('Connected');
```

### Groq API not working

1. Verify `GROQ_API_KEY` is set in Render env
2. Test from backend shell:

```bash
python -c "from services.ai_service import AIService; ai = AIService(); print('Groq OK')"
```

---

## Monitoring & Logs

### View Backend Logs

Render Dashboard → Service → **Logs** tab

### View Frontend Logs

Vercel Dashboard → Project → **Logs** or **Overview**

### Monitor Database

Render Dashboard → PostgreSQL service → **Datadog integration** (premium)

---

## Cost Estimation

| Service | Plan | Cost/Month |
|---------|------|-----------|
| Vercel  | Pro  | $20       |
| Render  | Standard | $15-50 |
| PostgreSQL | 1GB RAM | $15 |
| Redis   | Included | $0 |
| Qdrant  | 10GB Disk | Included |
| Groq    | Free tier | $0* |
| **Total** | | **$50-85/mo** |

*Groq has generous free tier for API calls

---

## Next Steps

1. ✅ Deploy backend to Render
2. ✅ Deploy frontend to Vercel
3. ✅ Configure environment variables
4. ✅ Test API connectivity
5. ✅ (Optional) Setup Cloudinary
6. ✅ Monitor logs and errors
7. ✅ Create CI/CD pipeline for auto-deployments

---

## Local Development

To test locally before deploying:

```bash
# Terminal 1: Backend
cd backend
python -m uvicorn main:app --reload

# Terminal 2: Frontend
cd flutter_app
flutter run -d chrome --dart-define API_BASE_URL=http://localhost:8000/api/v1
```

---

## Useful Commands

```bash
# View Render logs
render logs -s faceinsight-api

# Deploy specific service
vercel deploy --prod

# Clear Vercel cache
vercel env pull

# Check Flutter build size
flutter build web --analyze-size
```

---

**Questions? Check the [FaceInsight README](./README.md) or open an issue on GitHub.**
