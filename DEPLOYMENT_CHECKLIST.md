# FaceInsight Deployment Checklist

Quick reference for deploying to Vercel & Render.

## 🔐 Pre-Deployment: Generate Secrets

```bash
# Generate APP_SECRET_KEY
python -c "import secrets; print('APP_SECRET_KEY=' + secrets.token_urlsafe(32))"

# Generate JWT_SECRET_KEY
python -c "import secrets; print('JWT_SECRET_KEY=' + secrets.token_urlsafe(32))"

# Generate POSTGRES_PASSWORD
python -c "import secrets; print('POSTGRES_PASSWORD=' + secrets.token_urlsafe(24))"
```

## 📝 Step 1: Prepare Local Environment

```bash
# Clone/navigate to project
cd faceinsight

# Create local .env for testing (DON'T COMMIT)
cp backend/.env.example backend/.env
cp flutter_app/.env.example flutter_app/.env

# Edit values locally for testing
# backend/.env:
#   - DATABASE_URL=postgresql://user:pass@localhost:5432/faceinsight_db
#   - GROQ_API_KEY=your-test-key

# flutter_app/.env:
#   - API_BASE_URL=http://localhost:8000/api/v1
#   - WS_BASE_URL=ws://localhost:8000/ws
```

## 🚀 Step 2: Push to GitHub

```bash
# Ensure git is initialized
git init
git add .
git commit -m "Configure for Vercel/Render deployment"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/faceinsight.git
git push -u origin main
```

## 🏗️ Step 3: Deploy Backend to Render

### Via render.yaml (Recommended)

1. Go to [render.com](https://render.com)
2. Sign in with GitHub
3. Click **Blueprints** → **New Blueprint**
4. Select your `faceinsight` repository
5. Click **Create Blueprint**
6. Render detects `render.yaml` automatically
7. Fill in environment variables when prompted:

**Required Variables:**
- `APP_SECRET_KEY` - Generate above
- `JWT_SECRET_KEY` - Generate above
- `POSTGRES_PASSWORD` - Generate above
- `GROQ_API_KEY` - From groq.com
- `CORS_ORIGINS` - Will update after Vercel deployment

### Via Manual Setup (Alternative)

1. Create PostgreSQL service
2. Create Redis service
3. Create Qdrant service
4. Create Web service (FastAPI)
5. Create Background Worker (Celery)

## ✅ Step 4: Verify Backend

```bash
# Test API health endpoint (replace with your Render URL)
curl https://YOUR_BACKEND.onrender.com/api/v1/health

# Should return: {"status": "ok"}
```

## 🎨 Step 5: Deploy Frontend to Vercel

### Via Vercel CLI

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Navigate to flutter_app
cd flutter_app

# Deploy
vercel --prod
```

### Via Vercel Dashboard

1. Go to [vercel.com](https://vercel.com)
2. Sign in with GitHub
3. Click **Add New** → **Project**
4. Select `faceinsight` repository
5. Set build command:
```bash
cd flutter_app && flutter build web --web-renderer html --dart-define API_BASE_URL=https://YOUR_BACKEND.onrender.com/api/v1 --dart-define WS_BASE_URL=wss://YOUR_BACKEND.onrender.com/ws --release
```
6. Deploy!

## 🔗 Step 6: Connect Frontend to Backend

### Update Backend CORS

In Render Dashboard for `faceinsight-api` service:

**Environment Variables** → Add/Update:
```env
CORS_ORIGINS=https://YOUR_FRONTEND.vercel.app,http://localhost:3000
```

### Update Frontend API URL

In Vercel Dashboard for your project:

**Settings** → **Environment Variables** → Add:
```
API_BASE_URL=https://YOUR_BACKEND.onrender.com/api/v1
WS_BASE_URL=wss://YOUR_BACKEND.onrender.com/ws
```

Then **Redeploy** the Vercel project.

## 🧪 Step 7: Test End-to-End

1. Open your Vercel app in browser
2. Login / Register
3. Upload an image
4. Wait for analysis
5. Check if results appear

**If issues:**
- Check browser console (F12) for errors
- Check Render logs in dashboard
- Check Vercel logs in dashboard
- Verify CORS is configured correctly

## 🔄 Step 8: Enable Auto-Deploy

### Vercel Auto-Deploy
- Automatic on every push to `main`
- Already configured

### Render Auto-Deploy
- Enable in Service → Settings → **Redeploy on push**

### GitHub Actions
- CI/CD pipeline already in `.github/workflows/deploy.yml`
- Runs tests and deploys on push to `main`

## 📊 Monitoring

### View Logs

**Render:**
- Dashboard → Service → **Logs** tab

**Vercel:**
- Dashboard → Project → **Deployments**

### Monitor Performance

- Render: Built-in monitoring
- Vercel: Analytics and Performance tabs

## 💾 Backups

### Database Backups

Render PostgreSQL:
- Automatic daily backups
- Dashboard → Database → **Backups** tab
- 7-day retention (free tier)

### Manual Backup

```bash
# From Render shell
pg_dump -U faceinsight faceinsight_db > backup.sql
```

## 🆘 Troubleshooting

### Backend not starting
```bash
# In Render shell
cd backend
python -m alembic upgrade head  # Run migrations
python -c "from core.config import get_settings; print(get_settings())"
```

### Frontend can't reach API
```bash
# In browser console
fetch('https://YOUR_BACKEND.onrender.com/api/v1/health')
  .then(r => r.json())
  .then(console.log)
```

### WebSocket connection fails
```bash
# In browser console
new WebSocket('wss://YOUR_BACKEND.onrender.com/ws/job-progress')
```

### Database migrations failed
```bash
# In Render shell
python -m alembic current
python -m alembic history
```

## 📚 Useful Resources

- [Render Documentation](https://render.com/docs)
- [Vercel Documentation](https://vercel.com/docs)
- [Groq API Docs](https://console.groq.com/docs)
- [Qdrant Docs](https://qdrant.tech/documentation/)
- [Flutter Web Deployment](https://flutter.dev/docs/deployment/web)

## ✨ Done!

Your application is now deployed! Share your Vercel URL:

```
https://YOUR_APP.vercel.app
```

---

**Questions?** Check [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed guide.
