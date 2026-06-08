# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/results.py
#  Fetch real analysis results + history from DB
# ==============================================================

from fastapi import APIRouter, Depends, HTTPException
from loguru import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from core.dependecies import get_optional_user_id, get_current_user, get_db
from database.models import User, AnalysisJob, FaceAnalysis, JobStatus

router = APIRouter()


# ── GET /results/analysis/{job_id} ────────────────────────────

@router.get("/analysis/{job_id}", tags=["Results"])
async def get_analysis_result(
    job_id: int,
    optional_user_id: int | None = Depends(get_optional_user_id),
    db: AsyncSession = Depends(get_db),
):
    """
    Get complete analysis result for a job (only if COMPLETED).
    Works for both authenticated and anonymous users.
    Authenticated users can only see their own jobs.
    Anonymous users can see any job by job_id (they rely on the URL/job_id as the token).
    """
    # Fetch the job
    stmt = select(AnalysisJob).filter(AnalysisJob.id == job_id)
    result = await db.execute(stmt)
    job = result.scalar_one_or_none()

    if not job:
        raise HTTPException(status_code=404, detail="Job not found")

    # Ownership check: if the caller is authenticated, they may only see their own jobs.
    # If the caller is anonymous (no token), allow access by job_id alone.
    if optional_user_id is not None and job.user_id != optional_user_id:
        raise HTTPException(status_code=403, detail="Access denied")

    if job.status != JobStatus.COMPLETED:
        raise HTTPException(
            status_code=400,
            detail=f"Job not completed yet (status: {job.status.value})",
        )

    # Fetch FaceAnalysis with related conditions + recommendations
    face_stmt = (
        select(FaceAnalysis)
        .options(
            selectinload(FaceAnalysis.skin_conditions),
            selectinload(FaceAnalysis.recommendations),
        )
        .filter(FaceAnalysis.job_id == job_id)
    )
    face_result = await db.execute(face_stmt)
    fa = face_result.scalar_one_or_none()

    if not fa:
        raise HTTPException(status_code=404, detail="No analysis data found for this job")

    logger.info(f"Returning real results for job {job_id}")

    # ── Compute skin health score (0–100) ──────────────────────
    score_components = []
    if fa.symmetry_score is not None:
        score_components.append(fa.symmetry_score * 100)
    if fa.golden_ratio_score is not None:
        score_components.append(fa.golden_ratio_score * 100)

    if score_components:
        base_score = sum(score_components) / len(score_components)
    else:
        base_score = 70.0

    # Deduct points for detected conditions
    severity_penalty = {"mild": 3, "moderate": 8, "severe": 15, "none": 0}
    for cond in fa.skin_conditions:
        base_score -= severity_penalty.get(cond.severity or "none", 0)

    skin_health_score = max(20, min(100, round(base_score)))

    # ── Build conditions list ──────────────────────────────────
    conditions = []
    severity_labels = {"mild": "Low", "moderate": "Moderate", "severe": "High", "none": "None"}
    for c in fa.skin_conditions:
        conditions.append({
            "label":    c.condition_type.replace("_", " ").title(),
            "value":    severity_labels.get(c.severity or "none", "Low"),
            "severity": c.severity or "none",
        })

    # ── Build face zones from detected skin conditions + geometry ──
    severity_values = {"none": 1.0, "low": 0.90, "mild": 0.85, "moderate": 0.70, "high": 0.50, "severe": 0.40}
    
    acne_sev = "none"
    wrinkles_sev = "none"
    dark_circles_sev = "none"
    pores_sev = "none"
    
    for c in fa.skin_conditions:
        t = c.condition_type.lower()
        sev = (c.severity or "none").lower()
        if t == "acne":
            acne_sev = sev
        elif t == "wrinkles":
            wrinkles_sev = sev
        elif t == "dark_circles":
            dark_circles_sev = sev
        elif t == "pores":
            pores_sev = sev

    # 1. Forehead
    forehead_score = min(severity_values.get(acne_sev, 1.0), severity_values.get(wrinkles_sev, 1.0))
    if forehead_score >= 0.90:
        forehead_desc = "Smooth, healthy texture"
    elif wrinkles_sev != "none":
        forehead_desc = f"Expression lines detected (Wrinkles: {wrinkles_sev.title()})"
    else:
        forehead_desc = f"Congestion detected (Acne: {acne_sev.title()})"

    # 2. Eyes
    eyes_score = severity_values.get(dark_circles_sev, 1.0)
    if eyes_score >= 0.90:
        eyes_desc = "Clear and bright eye contour"
    else:
        eyes_desc = f"{dark_circles_sev.title()} dark circles detected"

    # 3. Cheeks
    cheeks_score = min(severity_values.get(acne_sev, 1.0), severity_values.get(pores_sev, 1.0) + 0.1)
    cheeks_score = max(0.2, min(1.0, cheeks_score))
    if cheeks_score >= 0.90:
        cheeks_desc = "Optimal hydration and clear texture"
    elif acne_sev != "none":
        cheeks_desc = f"Acne spots detected (Severity: {acne_sev.title()})"
    else:
        cheeks_desc = f"Enlarged pores detected (Severity: {pores_sev.title()})"

    # 4. Nose & Chin
    nose_chin_score = severity_values.get(pores_sev, 1.0)
    if nose_chin_score >= 0.90:
        nose_chin_desc = "Clear and balanced T-zone"
    else:
        nose_chin_desc = f"Visible pores in T-zone (Pores: {pores_sev.title()})"

    zones = [
        {
            "zone": "Forehead",
            "description": forehead_desc,
            "score": round(forehead_score, 2),
        },
        {
            "zone": "Eyes",
            "description": eyes_desc,
            "score": round(eyes_score, 2),
        },
        {
            "zone": "Cheeks",
            "description": cheeks_desc,
            "score": round(cheeks_score, 2),
        },
        {
            "zone": "Nose & Chin",
            "description": nose_chin_desc,
            "score": round(nose_chin_score, 2),
        },
    ]

    # Include Geometry Scores if available
    if fa.symmetry_score is not None:
        zones.append({
            "zone":        "Facial Symmetry",
            "description": _score_desc(fa.symmetry_score),
            "score":       fa.symmetry_score,
        })
    if fa.golden_ratio_score is not None:
        zones.append({
            "zone":        "Golden Ratio",
            "description": _score_desc(fa.golden_ratio_score),
            "score":       fa.golden_ratio_score,
        })

    # ── Build recommendations ──────────────────────────────────
    recs = sorted(fa.recommendations, key=lambda r: r.priority)
    recommendations = []
    seen_categories: dict[str, list] = {}
    for r in recs:
        if r.category not in seen_categories:
            seen_categories[r.category] = []
        seen_categories[r.category].append(f"{r.title}: {r.description}")

    for cat, items in seen_categories.items():
        recommendations.append({
            "title": cat.replace("_", " ").title(),
            "items": items,
        })

    return {
        "job_id":            str(job_id),
        "skin_health_score": skin_health_score,
        "age_estimate":      fa.age_estimate,
        "gender":            fa.gender,
        "skin_tone":         fa.skin_tone_label,
        "skin_tone_hex":     fa.skin_tone_hex,
        "face_shape":        fa.face_shape,
        "symmetry_score":    fa.symmetry_score,
        "golden_ratio_score":fa.golden_ratio_score,
        "conditions":        conditions,
        "zones":             zones,
        "recommendations":   recommendations,
        "created_at":        job.created_at.isoformat(),
    }


def _score_desc(score: float) -> str:
    if score >= 0.85: return "Excellent"
    if score >= 0.70: return "Good"
    if score >= 0.55: return "Fair"
    return "Needs attention"


# ── GET /results/history ──────────────────────────────────────

@router.get("/history", tags=["Results"])
async def get_analysis_history(
    limit: int = 10,
    offset: int = 0,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Get user's completed analysis history."""
    stmt = (
        select(AnalysisJob)
        .options(selectinload(AnalysisJob.face_analysis))
        .filter(
            AnalysisJob.user_id == current_user.id,
            AnalysisJob.status == JobStatus.COMPLETED,
        )
        .order_by(AnalysisJob.created_at.desc())
        .limit(limit)
        .offset(offset)
    )
    result = await db.execute(stmt)
    jobs = result.scalars().all()

    history = []
    for j in jobs:
        fa = j.face_analysis
        score = None
        if fa and fa.symmetry_score is not None:
            score = round(fa.symmetry_score * 100)
        history.append({
            "job_id":   str(j.id),
            "date":     j.created_at.isoformat(),
            "score":    score,
            "tone":     fa.skin_tone_label if fa else None,
        })

    return {"history": history, "count": len(history)}
