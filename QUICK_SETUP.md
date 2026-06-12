# FaceInsight - Setup Vercel & Render (Step-by-Step)

## Step 1: Push to GitHub

```bash
git add .
git commit -m "Setup deployment configuration"
git push -u origin main
```

Verify on github.com - your code should be there.

---

## PART A: SETUP RENDER BACKEND

### Step 2: Create Render Account

1. Go to [https://render.com](https://render.com)
2. Click **Sign up** → Sign with GitHub
3. Authorize Render to access GitHub

### Step 3: Deploy Backend via Render Blueprint

1. In Render Dashboard, click **Blueprints** (left sidebar)
2. Click **New Blueprint**
3. Select your `faceinsight` repository
4. Click **Create Blueprint**
5. Render auto-detects `render.yaml` ✅
6. Review the 5 services it will create:
   - PostgreSQL (Database)
   - Redis (Cache)
   - Qdrant (Vector DB)
   - faceinsight-api (Web Service)
   - faceinsight-celery (Worker)

### Step 4: Set Environment Variables for Render

When Render asks for environment variables, add **EXACTLY** these names:

#### For `faceinsight-api` (Web Service):

```
APP_ENV = production
APP_DEBUG = false
APP_SECRET_KEY = [generate: python -c "import secrets; print(secrets.token_urlsafe(32))"]
JWT_SECRET_KEY = [generate: python -c "import secrets; print(secrets.token_urlsafe(32))"]
GROQ_API_KEY = [get from https://console.groq.com]
DATABASE_URL = [auto-set by Render from PostgreSQL]
REDIS_URL = redis://[auto-set by Render]
CELERY_BROKER = redis://[auto-set by Render]:6379/0
CELERY_BACKEND = redis://[auto-set by Render]:6379/1
QDRANT_URL = http://[auto-set by Render]:6333
CORS_ORIGINS = http://localhost:3000,https://[YOUR-VERCEL-APP].vercel.app
ALLOWED_HOSTS = localhost,127.0.0.1,[YOUR-RENDER-APP].onrender.com
ML_DEVICE = cpu
MAX_UPLOAD_SIZE_MB = 10
```

#### For `faceinsight-postgres` (Database):

```
POSTGRES_USER = faceinsight
POSTGRES_PASSWORD = [generate: python -c "import secrets; print(secrets.token_urlsafe(24))"]
POSTGRES_DB = faceinsight_db
```

#### For `faceinsight-celery` (Worker):

Same as Web Service above

### Step 5: Deploy on Render

1. Click **Deploy Blueprint**
2. Wait 5-10 minutes for all services to start
3. You'll see green checkmarks when ready ✅

### Step 6: Get Backend URLs

Once deployed:

1. Go to Dashboard → **faceinsight-api** service
2. Look for **Render URL** (e.g., `https://faceinsight-api-xyz.onrender.com`)
3. **Copy this URL** - you'll need it for Vercel!

Full endpoints:
- API: `https://faceinsight-api-xyz.onrender.com/api/v1`
- WebSocket: `wss://faceinsight-api-xyz.onrender.com/ws`

### Step 7: Run Database Migrations

1. In Render Dashboard → **faceinsight-api** → **Shell** tab
2. Run:
```bash
cd backend
python -m alembic upgrade head
```

### Step 8: Test Backend is Working

In browser, visit:
```
https://faceinsight-api-xyz.onrender.com/api/v1/health
```

Should see: `{"status": "ok"}`

---

## PART B: SETUP VERCEL FRONTEND

### Step 9: Create Vercel Account

1. Go to [https://vercel.com](https://vercel.com)
2. Click **Sign up** → Sign with GitHub
3. Authorize Vercel to access GitHub

### Step 10: Create Vercel Project

1. In Vercel Dashboard, click **Add New** → **Project**
2. Find and select your `faceinsight` repository
3. Click **Import**
4. Configure project:
   - **Project Name**: `faceinsight-web` (or any name)
   - **Root Directory**: `flutter_app` ✅
   - **Framework**: Select **Other** (not auto-detected)
   - **Build Command**: Leave empty for now
   - Click **Deploy**

### Step 11: Add Vercel Environment Variables

1. Go to **Settings** → **Environment Variables**
2. Add **EXACTLY** these names:

```
API_BASE_URL = https://faceinsight-api-xyz.onrender.com/api/v1
WS_BASE_URL = wss://faceinsight-api-xyz.onrender.com/ws
```

(Replace `faceinsight-api-xyz` with your actual Render URL)

Click **Save**

### Step 12: Configure Build Command

Still in Settings → **Build & Development Settings**:

Set **Build Command** to:
```bash
cd flutter_app && flutter build web --web-renderer html --dart-define API_BASE_URL=$API_BASE_URL --dart-define WS_BASE_URL=$WS_BASE_URL --release
```

Or simpler (Vercel will auto-inject env vars):
```bash
flutter pub get && flutter build web --release
```

### Step 13: Deploy Frontend

1. Click **Deployments** tab
2. Click **Redeploy** on latest deployment
3. Wait for build to complete (~3-5 minutes)
4. Get your Vercel URL: `https://[PROJECT-NAME].vercel.app`

---

## PART C: CONNECT FRONTEND ↔ BACKEND

### Step 14: Update Render CORS Settings

Go back to Render Dashboard → **faceinsight-api** service → **Environment** tab

Update:
```
CORS_ORIGINS = http://localhost:3000,https://[YOUR-VERCEL-URL].vercel.app
```

Click **Save Changes** → Service auto-restarts

### Step 15: Update Vercel Environment Variables (if needed)

If Vercel build failed, update:

Go to Vercel Dashboard → **Settings** → **Environment Variables**

Verify:
```
API_BASE_URL = https://[YOUR-RENDER-URL].onrender.com/api/v1
WS_BASE_URL = wss://[YOUR-RENDER-URL].onrender.com/ws
```

Then **Redeploy** in Deployments tab.

---

## PART D: TEST END-TO-END

### Step 16: Test in Browser

1. Open: `https://[YOUR-VERCEL-URL].vercel.app`
2. Register a new account
3. Upload a test image
4. Wait for analysis (~30 seconds)
5. Verify results appear ✅

**If issues:**
- Check browser F12 console for errors
- Check Render logs: Dashboard → Service → **Logs** tab
- Check Vercel logs: Dashboard → **Logs**

---

## ENVIRONMENT VARIABLE REFERENCE

### Backend (Render) - Complete List

| Variable | Example | Type |
|----------|---------|------|
| `APP_ENV` | `production` | Text |
| `APP_DEBUG` | `false` | Text |
| `APP_SECRET_KEY` | `nK8x...` (32 chars) | Secret ⚠️ |
| `JWT_SECRET_KEY` | `aB9c...` (32 chars) | Secret ⚠️ |
| `DATABASE_URL` | Auto-set | Auto |
| `REDIS_URL` | Auto-set | Auto |
| `CELERY_BROKER` | Auto-set | Auto |
| `CELERY_BACKEND` | Auto-set | Auto |
| `QDRANT_URL` | Auto-set | Auto |
| `GROQ_API_KEY` | `gsk_...` | Secret ⚠️ |
| `CORS_ORIGINS` | `https://app.vercel.app` | Text |
| `ALLOWED_HOSTS` | `api.onrender.com` | Text |
| `ML_DEVICE` | `cpu` | Text |

### Frontend (Vercel) - Complete List

| Variable | Example | Type |
|----------|---------|------|
| `API_BASE_URL` | `https://api.onrender.com/api/v1` | Text |
| `WS_BASE_URL` | `wss://api.onrender.com/ws` | Text |

---

## ⚠️ IMPORTANT NOTES

1. **Secret Variables** (mark as "Encrypted" in Render):
   - `APP_SECRET_KEY`
   - `JWT_SECRET_KEY`
   - `POSTGRES_PASSWORD`
   - `GROQ_API_KEY`

2. **Auto-Set Variables** (Render handles):
   - `DATABASE_URL`
   - `REDIS_URL`
   - `CELERY_BROKER`
   - `CELERY_BACKEND`
   - `QDRANT_URL`

3. **Exact Names Matter**: Copy env var names EXACTLY (case-sensitive!)

4. **URLs Must Match**: Update both services with each other's URLs

---

## COMMON ISSUES & FIXES

### Backend won't start
```bash
# In Render Shell, test:
python -c "from core.config import get_settings; print(get_settings())"
```

### Frontend API calls fail
```javascript
// In browser console:
fetch('https://YOUR-BACKEND/api/v1/health').then(r => r.json()).then(console.log)
```

### CORS error
- Check `CORS_ORIGINS` in Render env
- Should include your Vercel URL exactly

### WebSocket connection fails
- Check `WS_BASE_URL` in Vercel env
- Should be `wss://` not `ws://`

---

## ✅ VERIFICATION CHECKLIST

- [ ] GitHub has your code pushed
- [ ] Render Blueprint deployed (5 services green)
- [ ] Database migrations ran successfully
- [ ] Render API responding to health check
- [ ] Vercel project created
- [ ] Environment variables set in both services
- [ ] Frontend builds successfully
- [ ] Frontend can reach backend API
- [ ] Can register account
- [ ] Can upload image
- [ ] Analysis completes
- [ ] Results display correctly

---

## 📞 HELP LINKS

- Render Docs: https://render.com/docs
- Vercel Docs: https://vercel.com/docs
- Flutter Web: https://flutter.dev/docs/deployment/web
- Groq Console: https://console.groq.com

---

**Done? Your app is live! 🎉**

Frontend: `https://[YOUR-APP].vercel.app`
Backend: `https://[YOUR-API].onrender.com`
