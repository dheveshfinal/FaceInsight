# ==============================================================
#  FaceInsight – backend/schemas/result_schema.py
#  Pydantic models for analysis results
# ==============================================================

from typing import List, Optional
from pydantic import BaseModel


class SkinConditionItem(BaseModel):
    label: str  # "Acne", "Dark Circles", etc.
    value: str  # "Low", "Moderate", "Good", "Excellent"
    severity: str  # low, moderate, good, excellent


class ZoneAnalysisItem(BaseModel):
    zone: str  # "Forehead", "Eyes", etc.
    description: str
    score: float  # 0.0–1.0


class RecommendationGroup(BaseModel):
    title: str
    items: List[str]


class AnalysisResultResponse(BaseModel):
    """Complete analysis result for completed job"""

    job_id: str
    skin_health_score: int  # 0–100
    conditions: List[SkinConditionItem]
    zones: List[ZoneAnalysisItem]
    recommendations: List[RecommendationGroup]
    created_at: str  # ISO format timestamp

    class Config:
        json_schema_extra = {
            "example": {
                "job_id": "123",
                "skin_health_score": 82,
                "conditions": [
                    {"label": "Acne", "value": "Low", "severity": "low"},
                ],
                "zones": [
                    {"zone": "Forehead", "description": "Clear", "score": 0.94},
                ],
                "recommendations": [
                    {
                        "title": "Daily Skincare Routine",
                        "items": ["Use gentle cleanser"],
                    }
                ],
                "created_at": "2025-06-07T10:00:00Z",
            }
        }
