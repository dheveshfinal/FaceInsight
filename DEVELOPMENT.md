# FaceInsight - Development & Hot Reload Guide

## Problem: "I should not run docker compose every time to refresh the page"

### Solution 1: Flutter Web Hot Reload (RECOMMENDED)

Hot reload enables instant UI updates without restarting. Perfect for frontend development.

#### Setup:

```bash
# Terminal 1: Start backend (if needed)
cd backend
docker compose up  # or run directly if not using Docker for development

# Terminal 2: Run Flutter web in hot reload mode
cd flutter_app
flutter pub get
flutter run -d chrome --web-port=3000 --web-hostname=localhost
```

#### How it works:

- Changes to Flutter code (UI, logic, animations) are reflected in the browser **instantly**
- **NO docker compose restart needed** for frontend changes
- Backend runs separately in Docker (or standalone)

#### Hot reload limitations:

- **Supported:** Widget code, styling, animations, logic changes
- **NOT supported:** Changes requiring full app restart (dependency changes, code generation)

#### Keyboard shortcuts in Chrome:

```
r  = Hot reload (refresh UI)
R  = Full app restart
q  = Quit
```

---

### Solution 2: Docker Compose Hot Reload (Backend Development)

For backend changes without full Docker restart:

```bash
# Run with volume mounts to watch backend code changes
docker compose up -d

# For Python hot reload, use Uvicorn's watch mode:
# (In Dockerfile, change CMD to include --reload flag)
# CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# Check logs:
docker compose logs -f backend
```

---

### Solution 3: Hybrid Development (Recommended for Full Stack Work)

**Best approach** for simultaneous frontend + backend development:

```bash
# Terminal 1: Backend (with hot reload)
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload

# Terminal 2: Frontend (with hot reload)
cd flutter_app
flutter run -d chrome --web-port=3000 --web-hostname=localhost

# Optional Terminal 3: Database (Docker)
docker compose up -d postgres redis
```

This way:
- ✅ **Frontend changes**: Instant with hot reload
- ✅ **Backend changes**: Instant Uvicorn reload
- ✅ **No full Docker restart needed**
- ✅ **Much faster development cycle**

---

## Current API Flow (Real Job Polling)

### Before (Simulated):
```
AnalysisLoadingPage (local timer) 
  → Fake progress updates every 900ms
  → No backend communication
  → Always worked but not realistic
```

### After (Real API):
```
Home Page (click "START ANALYSIS")
  → Upload image → AnalysisService.uploadImage()
  → Get job_id from backend ✅
  → Navigate to AnalysisLoadingPage(jobId)
  → Poll backend every 2 seconds → AnalysisService.pollJobStatus()
  → Display real progress from backend ✅
  → Auto-navigate to results when complete ✅
```

---

## Quick Start (Fastest Way)

### 1. Start backend (terminal 1):
```bash
cd backend
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 2. Start Flutter web (terminal 2):
```bash
cd flutter_app
flutter pub get
flutter run -d chrome --web-port=3000 --web-hostname=localhost
```

### 3. Development workflow:
- Edit Flutter UI → `r` in terminal 2 (hot reload)
- Edit Python backend → Auto-reload from Uvicorn (see `python_logging.log`)
- **NO** `docker compose down && docker compose up` needed! 🎉

---

## Configuration Files

### Docker Compose Setup:
- `docker-compose.yml` - Services orchestration
- `backend/Dockerfile` - Backend image build
- `flutter_app/Dockerfile` - Flutter web image build
- `nginx/conf.d/default.conf` - Nginx config (serves Flutter web)

### API Configuration:
- Flutter calls backend via `AppConstants` - all URLs centralized
- `API_BASE_URL` can be set via `--dart-define` in build
- Default: `http://localhost:8000/api/v1`

### Environment Files:
- `backend/.env` - Backend config (create if missing)
  ```env
  APP_SECRET_KEY=your_secret_key
  JWT_SECRET_KEY=your_jwt_secret
  DATABASE_URL=postgresql+asyncpg://...
  REDIS_URL=redis://localhost:6379
  CELERY_BROKER=redis://localhost:6379/0
  CELERY_BACKEND=redis://localhost:6379/1
  ```

---

## Troubleshooting

### Flutter can't connect to backend?
Check:
- Backend running on `localhost:8000`
- CORS configured correctly in `backend/core/config.py`
- Chrome DevTools → Network tab for 401/403/404 errors

### Hot reload not working?
```bash
# Option 1: Full app restart
flutter run -d chrome --web-port=3000 --web-hostname=localhost

# Option 2: Stop and restart
# Kill previous: Ctrl+C, then re-run above command
```

### Backend still showing old code?
```bash
# Python cache:
rm -rf backend/__pycache__
rm -rf backend/*/__pycache__

# Then restart:
python -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## Files Modified for API Integration

1. **Flutter Frontend:**
   - `pubspec.yaml` - Added `http` package
   - `lib/core/utils/app_constants.dart` - Created (API URLs)
   - `lib/modules/analysis/service/analysis_service.dart` - Created (polling logic)
   - `lib/modules/analysis/types/analysis_types.dart` - Created (DTOs)
   - `lib/modules/analysis/layout/analysis_loading_page.dart` - Updated (real API polling)
   - `lib/core/router/app_router.dart` - Updated (pass jobId parameter)

2. **Backend:**
   - `backend/api/v1/endpoints/__init__.py` - Created
   - `backend/api/v1/endpoints/upload.py` - Created (image upload)
   - `backend/api/v1/endpoints/analysis.py` - Created (job status polling)
   - `backend/api/v1/endpoints/results.py` - Created (fetch results)
   - `backend/api/v1/endpoints/auth.py` - Created (placeholder)
   - `backend/api/v1/endpoints/reports.py` - Created (placeholder)
   - `backend/api/v1/endpoints/websocket.py` - Created (placeholder)
   - `backend/schemas/job_schema.py` - Created (job status response)
   - `backend/schemas/result_schema.py` - Created (analysis result response)
   - `backend/services/upload_service.py` - Created (image storage)
   - `backend/services/ml_service.py` - Created (Celery task queuing)
   - `backend/core/dependecies.py` - Updated (added get_current_user)

---

## Next Steps

- [ ] Implement image upload UI in home_page.dart
- [ ] Implement authentication (login/register) - currently placeholders
- [ ] Implement ML pipeline (Celery tasks for image analysis)
- [ ] Connect real progress tracking from Celery to frontend
- [ ] Implement WebSocket for real-time updates (optional, polling works)
