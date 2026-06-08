# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/__init__.py
#  Barrel export of all endpoint routers
# ==============================================================

from . import auth, upload, analysis, results, reports, websocket

__all__ = ["auth", "upload", "analysis", "results", "reports", "websocket"]
