# FaceInsight Deployment Guide - Overview

This document summarizes all deployment configurations and files created for deploying FaceInsight to Vercel (Frontend) and Render (Backend).

## 📦 Files Created

### Environment Files

- **`backend/.env.example`** - Template for backend environment variables
- **`flutter_app/.env.example`** - Template for frontend environment variables

### Deployment Configurations

- **`render.yaml`** - Infrastructure-as-Code for Render backend deployment
- **`flutter_app/vercel.json`** - Vercel deployment configuration
- **`.github/workflows/deploy.yml`** - GitHub Actions CI/CD pipeline
- **`.gitignore`** - Prevents sensitive files from being committed

### Documentation

- **`DEPLOYMENT.md`** - Comprehensive step-by-step deployment guide (30+ minutes read)
- **`DEPLOYMENT_CHECKLIST.md`** - Quick reference checklist (5 minutes read)
- **`setup-deployment.sh`** - Automated setup script for Linux/macOS
- **`setup-deployment.ps1`** - Automated setup script for Windows

### Code Changes

- **`flutter_app/lib/shared/services/api_client.dart`** - Updated to read API URL from environment
- **`backend/core/config.py`** - Added Cloudinary configuration support

---

## 🚀 Quick Start

### For Windows Users

```powershell
# Run the setup script
powershell -ExecutionPolicy Bypass -File setup-deployment.ps1

# Then follow the printed instructions
```

### For macOS/Linux Users

```bash
# Make script executable
chmod +x setup-deployment.sh

# Run the setup script
./setup-deployment.sh

# Then follow the printed instructions
```

### Manual Setup

1. **Copy environment templates:**
   ```bash
   cp backend/.env.example backend/.env
   cp flutter_app/.env.example flutter_app/.env
   ```

2. **Generate secrets:**
   ```bash
   # Generate APP_SECRET_KEY
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   
   # Generate JWT_SECRET_KEY
   python -c "import secrets; print(secrets.token_urlsafe(32))"
   ```

3. **Edit `.env` files** with your secrets and API keys

4. **Test locally:**
   ```bash
   cd backend
   python -m uvicorn main:app --reload
   ```

---

## 📋 Deployment Steps Summary

### Backend (Render)

1. Push code to GitHub
2. Go to [render.com](https://render.com)
3. Create new Blueprint deployment
4. Select your `faceinsight` repository
5. Render auto-detects `render.yaml`
6. Set environment variables
7. Deploy! ✅

### Frontend (Vercel)

1. Install Vercel CLI: `npm install -g vercel`
2. Build Flutter web with API URL
3. Deploy: `vercel --prod`
4. Update environment variables
5. Redeploy ✅

**For detailed steps, see [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)**

---

## 🔑 Key Configuration Points

### Backend Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `DATABASE_URL` | PostgreSQL connection | `postgresql://user:pass@host/db` |
| `REDIS_URL` | Cache & task queue | `redis://host:6379` |
| `GROQ_API_KEY` | LLM for recommendations | `gsk_...` |
| `QDRANT_URL` | Vector database | `http://qdrant:6333` |
| `CORS_ORIGINS` | Frontend URLs | `https://app.vercel.app` |

### Frontend Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `API_BASE_URL` | Backend API endpoint | `https://api.onrender.com/api/v1` |
| `WS_BASE_URL` | WebSocket endpoint | `wss://api.onrender.com/ws` |

---

## ✨ Features of This Setup

✅ **No Hardcoded URLs** - All APIs use environment variables
✅ **Automated CI/CD** - GitHub Actions for testing and deployment
✅ **Scalable Infrastructure** - Render handles horizontal scaling
✅ **Vector Database** - Qdrant for semantic search
✅ **Async Tasks** - Celery workers for background jobs
✅ **Real-time Updates** - WebSocket support
✅ **AI Integration** - Groq API for smart recommendations
✅ **Cloud Storage** - Optional Cloudinary integration
✅ **Secure** - Secrets managed via environment variables

---

## 🔍 Architecture

```
┌──────────────────────────────────────┐
│         Vercel (Frontend)            │
│  Flutter Web Application             │
│  https://your-app.vercel.app         │
└────────────────┬─────────────────────┘
                 │ HTTPS + WebSocket
                 ▼
┌──────────────────────────────────────┐
│      Render (Backend Infrastructure) │
├──────────────────────────────────────┤
│ • FastAPI Web Service                │
│ • PostgreSQL Database                │
│ • Redis Cache                        │
│ • Qdrant Vector DB                   │
│ • Celery Workers                     │
└──────┬────────────┬────────────┬─────┘
       │            │            │
       ▼            ▼            ▼
   ┌────────┐  ┌──────────┐  ┌────────┐
   │ Groq   │  │Cloudinary│  │ OpenCV │
   │(LLM)   │  │(Images)  │  │ (ML)   │
   └────────┘  └──────────┘  └────────┘
```

---

## 🎯 Environment-Based Configuration

### Development (Local)
```env
API_BASE_URL=http://localhost:8000/api/v1
WS_BASE_URL=ws://localhost:8000/ws
APP_DEBUG=true
```

### Production (Render + Vercel)
```env
API_BASE_URL=https://your-backend.onrender.com/api/v1
WS_BASE_URL=wss://your-backend.onrender.com/ws
APP_DEBUG=false
```

Changes automatically picked up on rebuild!

---

## 📚 Documentation Structure

1. **DEPLOYMENT_CHECKLIST.md** (Quick Start)
   - 5-10 minute quick reference
   - Step-by-step commands
   - Troubleshooting tips

2. **DEPLOYMENT.md** (Complete Guide)
   - 30+ minute comprehensive guide
   - Architecture overview
   - Detailed explanations
   - Cost estimation
   - Monitoring setup

3. **This File** (Overview)
   - High-level summary
   - Key files reference
   - Quick start guide

---

## 🛠️ Troubleshooting Quick Links

| Issue | Solution |
|-------|----------|
| Backend not starting | See DEPLOYMENT.md → Troubleshooting |
| CORS errors | Check `CORS_ORIGINS` in backend env |
| WebSocket failures | Verify `WS_BASE_URL` in frontend |
| Database issues | Run migrations in Render shell |
| Image upload fails | Check Cloudinary settings |

---

## 🔐 Security Checklist

- [ ] Generate strong secrets (not using defaults)
- [ ] Never commit `.env` files
- [ ] Use HTTPS for all URLs
- [ ] Enable CORS for your frontend domain only
- [ ] Rotate secrets regularly
- [ ] Use strong database passwords
- [ ] Enable database backups

---

## 💰 Cost Estimation

| Service | Free Tier | Paid |
|---------|-----------|------|
| Vercel | $0 (generous) | $20/mo |
| Render | Limited | $15+/mo |
| PostgreSQL | - | $15/mo |
| Groq API | $0 (generous) | Usage-based |
| **Total** | ~$0 | ~$50-100/mo |

---

## 📞 Support Resources

- [Render Docs](https://render.com/docs)
- [Vercel Docs](https://vercel.com/docs)
- [Groq Docs](https://console.groq.com/docs)
- [Flutter Web](https://flutter.dev/docs/deployment/web)
- [FastAPI Docs](https://fastapi.tiangolo.com)

---

## ✅ Next Steps

1. **Set Up Locally**
   ```bash
   ./setup-deployment.sh  # or setup-deployment.ps1 on Windows
   ```

2. **Test Locally**
   ```bash
   python -m uvicorn backend.main:app --reload
   flutter run -d chrome
   ```

3. **Create GitHub Repo**
   ```bash
   git init && git add . && git commit -m "Initial commit"
   git remote add origin https://github.com/YOUR_USERNAME/faceinsight.git
   git push -u origin main
   ```

4. **Follow DEPLOYMENT_CHECKLIST.md**
   - Deploy backend to Render
   - Deploy frontend to Vercel
   - Test end-to-end

5. **Monitor & Maintain**
   - Check logs regularly
   - Monitor performance
   - Update dependencies
   - Rotate secrets

---

## 📝 Notes

- All configuration is now environment-based, no hardcoded URLs
- Docker support ready for Render deployment
- CI/CD pipeline included for automated tests and deployment
- Scalable from 1 to many concurrent users
- Vector database support for semantic search
- Async task processing for long operations

---

**🎉 Ready to deploy? Start with [DEPLOYMENT_CHECKLIST.md](./DEPLOYMENT_CHECKLIST.md)!**
