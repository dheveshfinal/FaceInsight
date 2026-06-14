# ==============================================================
#  FaceInsight – backend/workers/tasks.py
#  Real ML analysis pipeline:
#    1. Load image (Pillow)
#    2. MediaPipe FaceMesh → 468 landmarks → symmetry score
#    3. Skin tone + brightness via PIL
#    4. InsightFace → age / gender / beauty (optional, may be slow first run)
#    5. Groq AI → natural-language recommendations
#    6. Write FaceAnalysis + SkinCondition + Recommendation rows to DB
#    7. Mark AnalysisJob as COMPLETED (or FAILED)
# ==============================================================

import os
import math
import asyncio
import time
import json
import sys
from pathlib import Path
from typing import Optional

# Ensure backend root is in PYTHONPATH
backend_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if backend_root not in sys.path:
    sys.path.insert(0, backend_root)

from loguru import logger
from celery import states

from workers.celery_app import celery_app

# Global cache for InsightFace to avoid loading ONNX weights on every task run
_insight_face_app = None



# ── Sync DB helper (Celery tasks are sync) ────────────────────

def _get_sync_session():
    """Create a *synchronous* SQLAlchemy session for use inside Celery."""
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker

    db_url = os.environ.get("DATABASE_URL", "")
    # asyncpg → psycopg2 for sync use
    sync_url = db_url.replace("postgresql+asyncpg://", "postgresql://")

    engine = create_engine(sync_url, pool_pre_ping=True)
    Session = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    return Session()


# ── Main task ─────────────────────────────────────────────────

@celery_app.task(
    name="workers.tasks.run_analysis_pipeline",
    bind=True,
    max_retries=2,
    default_retry_delay=10,
    queue="ml_queue",
)
def run_analysis_pipeline(self, job_id: int, image_filename: str) -> dict:
    """
    Full ML analysis pipeline. Runs synchronously inside Celery worker.
    """
    task_start = time.time()
    logger.info(f"[Task {self.request.id}] ⏱️  Starting analysis: job_id={job_id}")

    db = _get_sync_session()
    try:
        from database.models import AnalysisJob, FaceAnalysis, SkinCondition, Recommendation
        from database.models.analysis_job import JobStatus

        # ── 0. Mark job as PROCESSING ─────────────────────────
        job = db.query(AnalysisJob).filter(AnalysisJob.id == job_id).first()
        if not job:
            raise ValueError(f"Job {job_id} not found in DB")

        job.status = JobStatus.PROCESSING
        job.celery_task_id = self.request.id
        db.commit()

        # Send initial progress
        self.update_state(state='PROGRESS', meta={'progress': 0.05, 'stage': 'Starting analysis…'})

        # ── 1. Load image ──────────────────────────────────────
        logger.info(f"[Task {self.request.id}] Downloading image from Cloudinary: {image_filename}")
        import urllib.request
        from io import BytesIO
        from PIL import Image as PILImage
        
        # Download the image from the Cloudinary URL
        req = urllib.request.Request(image_filename, headers={'User-Agent': 'Mozilla/5.0'})
        with urllib.request.urlopen(req) as response:
            image_data = response.read()
            
        pil_img = PILImage.open(BytesIO(image_data)).convert("RGB")
        width, height = pil_img.size

        # Update progress
        self.update_state(state='PROGRESS', meta={'progress': 0.15, 'stage': 'Detecting face…'})

        # ── 2. MediaPipe FaceMesh ──────────────────────────────
        symmetry_score    = None
        golden_ratio_score = None
        face_shape        = "oval"
        landmarks_json    = None
        bbox              = None

        try:
            import mediapipe as mp
            import numpy as np

            mp_face_mesh = mp.solutions.face_mesh
            img_np = np.array(pil_img)

            with mp_face_mesh.FaceMesh(
                static_image_mode=True,
                max_num_faces=1,
                refine_landmarks=True,
                min_detection_confidence=0.4,
            ) as face_mesh:
                results = face_mesh.process(img_np)

            if results.multi_face_landmarks:
                lm = results.multi_face_landmarks[0].landmark

                # Convert to pixel coords
                pts = [(int(p.x * width), int(p.y * height)) for p in lm]
                landmarks_json = [[p[0], p[1]] for p in pts]

                # Bounding box from landmarks
                xs = [p[0] for p in pts]
                ys = [p[1] for p in pts]
                bbox = (min(xs), min(ys), max(xs), max(ys))

                # ── Symmetry: compare left vs right eye distance ──
                # Left eye: landmark 33, Right eye: landmark 263 (approx)
                # Nose tip: 1, Chin: 152
                nose  = pts[1]
                chin  = pts[152]
                l_eye = pts[33]
                r_eye = pts[263]

                left_dist  = math.hypot(nose[0] - l_eye[0], nose[1] - l_eye[1])
                right_dist = math.hypot(nose[0] - r_eye[0], nose[1] - r_eye[1])

                if max(left_dist, right_dist) > 0:
                    ratio = min(left_dist, right_dist) / max(left_dist, right_dist)
                    symmetry_score = round(ratio, 3)

                # ── Golden ratio (face height / width) ───────────
                face_h = math.hypot(nose[0] - chin[0], nose[1] - chin[1]) * 2
                face_w = math.hypot(l_eye[0] - r_eye[0], l_eye[1] - r_eye[1]) * 2
                if face_w > 0:
                    gr = face_h / face_w
                    golden_ratio_score = round(1 - abs(gr - 1.618) / 1.618, 3)
                    golden_ratio_score = max(0.0, min(1.0, golden_ratio_score))

                # ── Face shape heuristic ──────────────────────────
                if face_w > 0:
                    aspect = face_h / face_w if face_w > 0 else 1.0
                    if   aspect < 1.1:  face_shape = "round"
                    elif aspect < 1.3:  face_shape = "oval"
                    elif aspect < 1.5:  face_shape = "oblong"
                    else:               face_shape = "square"

            logger.info(f"[Task {self.request.id}] MediaPipe done: symmetry={symmetry_score}")
        except Exception as e:
            logger.warning(f"[Task {self.request.id}] MediaPipe failed (skipping): {e}")

        # Update progress
        self.update_state(state='PROGRESS', meta={'progress': 0.35, 'stage': 'Analyzing skin…'})

        # ── 3. Skin tone via PIL ───────────────────────────────
        skin_tone_hex   = None
        skin_tone_label = None
        brightness      = None

        try:
            import numpy as np

            img_arr = np.array(pil_img)

            # Crop centre region (likely skin)
            cy, cx = height // 2, width // 2
            patch  = img_arr[cy - 40:cy + 40, cx - 40:cx + 40]
            if patch.size > 0:
                mean_r = int(patch[:, :, 0].mean())
                mean_g = int(patch[:, :, 1].mean())
                mean_b = int(patch[:, :, 2].mean())
                skin_tone_hex = f"#{mean_r:02X}{mean_g:02X}{mean_b:02X}"
                brightness    = round((mean_r * 0.299 + mean_g * 0.587 + mean_b * 0.114) / 255, 3)

                # Label by brightness
                if   brightness > 0.75: skin_tone_label = "fair"
                elif brightness > 0.55: skin_tone_label = "light"
                elif brightness > 0.40: skin_tone_label = "medium"
                elif brightness > 0.25: skin_tone_label = "tan"
                else:                   skin_tone_label = "deep"

            logger.info(f"[Task {self.request.id}] Skin tone: {skin_tone_hex} ({skin_tone_label})")
        except Exception as e:
            logger.warning(f"[Task {self.request.id}] Skin tone failed (skipping): {e}")

        # Update progress
        self.update_state(state='PROGRESS', meta={'progress': 0.50, 'stage': 'Detecting age & gender…'})

        # ── 4. InsightFace age / gender (optional) ────────────
        age_estimate        = None
        gender              = None
        gender_confidence   = None
        detection_confidence = None

        try:
            import insightface
            from insightface.app import FaceAnalysis as InsightApp
            import numpy as np

            global _insight_face_app
            if _insight_face_app is None:
                weights_dir = os.environ.get("ML_WEIGHTS_DIR", "/app/ml/weights")
                logger.info(f"[Task {self.request.id}] Loading InsightFace model into memory... (first time, may take 30-60s)")
                start_time = time.time()
                _insight_face_app = InsightApp(
                    name="buffalo_s",  # smaller model: ~60MB vs 500MB for buffalo_l
                    root=weights_dir,
                    providers=["CPUExecutionProvider"],
                )
                _insight_face_app.prepare(ctx_id=-1)  # -1 = CPU
                elapsed = time.time() - start_time
                logger.info(f"[Task {self.request.id}] ✅ InsightFace model loaded successfully (took {elapsed:.1f}s)")
            else:
                logger.info(f"[Task {self.request.id}] Using cached InsightFace model")

            img_bgr = np.array(pil_img)[:, :, ::-1]  # RGB→BGR
            faces   = _insight_face_app.get(img_bgr)

            if faces:
                f = faces[0]
                age_estimate        = float(f.age)
                gender              = "female" if f.gender == 0 else "male"
                gender_confidence   = float(f.det_score)
                detection_confidence = float(f.det_score)

            logger.info(
                f"[Task {self.request.id}] InsightFace: age={age_estimate}, gender={gender}"
            )
        except Exception as e:
            logger.warning(f"[Task {self.request.id}] InsightFace failed (skipping): {e}")

        # Update progress
        self.update_state(state='PROGRESS', meta={'progress': 0.70, 'stage': 'Detecting skin conditions…'})

        # ── 5. Detect skin conditions from brightness + heuristics ──
        conditions: list[dict] = []

        # Default/base severities
        acne_severity = "none"
        acne_conf = 0.95
        
        wrinkles_severity = "none"
        wrinkles_conf = 0.95
        
        dark_circles_severity = "none"
        dark_circles_conf = 0.95
        
        pores_severity = "low"
        pores_conf = 0.90

        # Heuristics based on brightness
        if brightness is not None:
            # Dark circles heuristic: low brightness under eyes
            if brightness < 0.45:
                dark_circles_severity = "moderate" if brightness < 0.35 else "mild"
                dark_circles_conf = round(1 - brightness, 2)
            else:
                dark_circles_severity = "none"
                dark_circles_conf = 0.90
                
            # Dryness / Oiliness estimates to affect pores/acne
            if brightness > 0.70:
                pores_severity = "moderate"
                pores_conf = round(brightness - 0.2, 2)
                # higher oiliness -> slight acne chance
                acne_severity = "mild"
                acne_conf = 0.75
            else:
                pores_severity = "low"
                pores_conf = 0.85

        # Heuristics based on age
        if age_estimate is not None:
            if age_estimate > 50:
                wrinkles_severity = "moderate"
                wrinkles_conf = 0.85
            elif age_estimate > 35:
                wrinkles_severity = "mild"
                wrinkles_conf = 0.75
            else:
                wrinkles_severity = "none"
                wrinkles_conf = 0.95

        conditions.append({
            "type": "acne",
            "severity": acne_severity,
            "confidence": acne_conf,
        })
        conditions.append({
            "type": "wrinkles",
            "severity": wrinkles_severity,
            "confidence": wrinkles_conf,
        })
        conditions.append({
            "type": "dark_circles",
            "severity": dark_circles_severity,
            "confidence": dark_circles_conf,
        })
        conditions.append({
            "type": "pores",
            "severity": pores_severity,
            "confidence": pores_conf,
        })

        # ── 6. Use static recommendations (fast) ─────────────────
        # NOTE: Groq recommendations will be generated async in background
        #       This ensures results appear immediately (in ~10-30 seconds)
        ai_recs = [
            {"category": "skincare",  "title": "Daily Cleanser",   "desc": "Use a gentle pH-balanced cleanser morning and night.",   "priority": 0},
            {"category": "skincare",  "title": "SPF Protection",   "desc": "Apply SPF 50 every morning, even on cloudy days.",        "priority": 1},
            {"category": "skincare",  "title": "Moisturiser",      "desc": "Apply a non-comedogenic moisturiser after cleansing.",    "priority": 2},
            {"category": "lifestyle", "title": "Hydration",        "desc": "Drink at least 2 litres of water daily.",                 "priority": 3},
            {"category": "lifestyle", "title": "Sleep Quality",    "desc": "Aim for 7-9 hours of sleep to support skin repair.",     "priority": 4},
        ]
        
        # Update progress
        self.update_state(state='PROGRESS', meta={'progress': 0.85, 'stage': 'Saving results…'})
        
        logger.info(f"[Task {self.request.id}] Using fast static recommendations")

        # ── 7. Persist results to DB ───────────────────────────
        face_rec = FaceAnalysis(
            job_id               = job_id,
            detection_confidence = detection_confidence,
            bbox_x1              = bbox[0] if bbox else None,
            bbox_y1              = bbox[1] if bbox else None,
            bbox_x2              = bbox[2] if bbox else None,
            bbox_y2              = bbox[3] if bbox else None,
            landmarks            = landmarks_json,
            age_estimate         = age_estimate,
            gender               = gender,
            gender_confidence    = gender_confidence,
            skin_tone_hex        = skin_tone_hex,
            skin_tone_label      = skin_tone_label,
            symmetry_score       = symmetry_score,
            golden_ratio_score   = golden_ratio_score,
            face_shape           = face_shape,
        )
        db.add(face_rec)
        db.flush()  # get face_rec.id

        for c in conditions:
            db.add(SkinCondition(
                face_analysis_id = face_rec.id,
                condition_type   = c["type"],
                severity         = c["severity"],
                confidence       = c["confidence"],
            ))

        for r in ai_recs:
            db.add(Recommendation(
                face_analysis_id = face_rec.id,
                category         = r["category"],
                title            = r["title"],
                description      = r["desc"],
                priority         = r["priority"],
            ))

        # ── 8. Queue async Groq recommendations ─────────────────
        # These run in background without blocking analysis results
        ml_summary = {
            "symmetry_score":     symmetry_score,
            "golden_ratio_score": golden_ratio_score,
            "skin_tone":          skin_tone_label,
            "brightness":         brightness,
            "age_estimate":       age_estimate,
            "gender":             gender,
            "face_shape":         face_shape,
            "conditions":         [c["type"] for c in conditions],
        }
        
        try:
            # Queue Groq recommendation generation as background task
            generate_groq_recommendations.apply_async(
                args=[job_id, json.dumps(ml_summary)],
                queue="default",
            )
            logger.info(f"[Task {self.request.id}] Queued async Groq recommendations generation")
        except Exception as e:
            logger.warning(f"[Task {self.request.id}] Could not queue Groq task: {e}")

        # ── 9. Mark job COMPLETED ──────────────────────────────
        job.status = JobStatus.COMPLETED
        db.commit()

        # Final progress update
        self.update_state(state='PROGRESS', meta={'progress': 1.0, 'stage': 'Complete!'})

        total_elapsed = time.time() - task_start
        logger.info(f"[Task {self.request.id}] ✅ Analysis COMPLETE for job_id={job_id} (total time: {total_elapsed:.1f}s)")
        return {"job_id": job_id, "status": "completed", "task_id": self.request.id}

    except Exception as exc:
        logger.error(f"[Task {self.request.id}] Analysis FAILED: {exc}")
        try:
            from database.models import AnalysisJob
            from database.models.analysis_job import JobStatus
            job = db.query(AnalysisJob).filter(AnalysisJob.id == job_id).first()
            if job:
                job.status        = JobStatus.FAILED
                job.error_message = str(exc)[:500]
                db.commit()
        except Exception:
            pass
        raise self.retry(exc=exc)
    finally:
        db.close()


@celery_app.task(bind=True, name="tasks.generate_groq_recommendations")
def generate_groq_recommendations(self, job_id: int, ml_summary_json: str):
    """
    Async task to generate Groq recommendations in background.
    Runs after analysis completes, doesn't block UI.
    """
    logger.info(f"[Groq Task {self.request.id}] Starting for job_id={job_id}")
    
    from database.session import SessionLocal
    db = SessionLocal()
    try:
        import json
        from database.models import FaceAnalysis, Recommendation
        from services.ai_service import AIService
        
        # Parse ML summary
        ml_summary = json.loads(ml_summary_json)
        
        # Query face analysis record
        face_rec = db.query(FaceAnalysis).filter(FaceAnalysis.job_id == job_id).first()
        if not face_rec:
            logger.warning(f"[Groq Task {self.request.id}] Face analysis not found")
            return
        
        # Get job user
        from database.models import AnalysisJob
        job = db.query(AnalysisJob).filter(AnalysisJob.id == job_id).first()
        if not job:
            logger.warning(f"[Groq Task {self.request.id}] Job not found")
            return
        
        # Generate Groq recommendations
        logger.info(f"[Groq Task {self.request.id}] Calling Groq AI...")
        start = time.time()
        
        ai = AIService()
        suggestions = ai.generate_suggestions(
            ml_outputs=ml_summary,
            user_id=job.user_id  # Store with user_id for Qdrant
        )
        
        elapsed = time.time() - start
        logger.info(f"[Groq Task {self.request.id}] ✅ Groq completed in {elapsed:.1f}s")
        
        # Store AI recommendations
        ai_recs = []
        for i, s in enumerate(suggestions.get("skincare_suggestions", [])[:3]):
            ai_recs.append({
                "category": "skincare",
                "title":    f"Skincare Tip {i + 1}",
                "desc":     s,
                "priority": i,
            })
        for i, s in enumerate(suggestions.get("lifestyle_suggestions", [])[:2]):
            ai_recs.append({
                "category": "lifestyle",
                "title":    f"Lifestyle Tip {i + 1}",
                "desc":     s,
                "priority": i + 3,
            })
        
        # Update database
        for i, rec in enumerate(ai_recs):
            recommendation = Recommendation(
                face_analysis_id=face_rec.id,
                category=rec["category"],
                title=rec["title"],
                description=rec["desc"],
                priority=rec["priority"],
            )
            db.add(recommendation)
        
        db.commit()
        logger.info(f"[Groq Task {self.request.id}] Stored {len(ai_recs)} Groq recommendations")
        
    except Exception as e:
        logger.error(f"[Groq Task {self.request.id}] Failed: {e}")
        # Groq failure is non-blocking, log and continue
    finally:
        db.close()
