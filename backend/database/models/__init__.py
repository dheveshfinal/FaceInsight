# Import every model here so Alembic sees them all when it calls
# `from database import Base` and inspects Base.metadata.
from .user import User
from .analysis_job import AnalysisJob, JobStatus
from .face_analysis import FaceAnalysis
from .skin_condition import SkinCondition
from .recommendation import Recommendation
from .analysis_image import AnalysisImage

__all__ = [
    "User",
    "AnalysisJob",
    "JobStatus",
    "FaceAnalysis",
    "SkinCondition",
    "Recommendation",
    "AnalysisImage",
]