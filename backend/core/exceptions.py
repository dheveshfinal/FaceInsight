# ==============================================================
#  FaceInsight – backend/core/exceptions.py
#  Custom exception classes + FastAPI exception handlers
# ==============================================================

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from loguru import logger


# ── Custom exception classes ───────────────────────────────────

class FaceInsightException(Exception):
    """Base exception for all app errors."""
    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


class NotFoundException(FaceInsightException):
    def __init__(self, resource: str, resource_id: str | int = ""):
        super().__init__(
            message=f"{resource} not found" + (f": {resource_id}" if resource_id else ""),
            status_code=404,
        )


class UnauthorizedException(FaceInsightException):
    def __init__(self, message: str = "Unauthorized"):
        super().__init__(message=message, status_code=401)


class ForbiddenException(FaceInsightException):
    def __init__(self, message: str = "Forbidden"):
        super().__init__(message=message, status_code=403)


class ValidationException(FaceInsightException):
    def __init__(self, message: str):
        super().__init__(message=message, status_code=422)


class ImageValidationException(FaceInsightException):
    def __init__(self, message: str):
        super().__init__(message=message, status_code=400)


class FaceDetectionException(FaceInsightException):
    def __init__(self, message: str = "No face detected in image"):
        super().__init__(message=message, status_code=422)


class MLPipelineException(FaceInsightException):
    def __init__(self, message: str):
        super().__init__(message=message, status_code=500)


class JobNotFoundException(NotFoundException):
    def __init__(self, job_id: str):
        super().__init__(resource="Analysis job", resource_id=job_id)


# ── Register handlers on FastAPI app ──────────────────────────

def register_exception_handlers(app: FastAPI) -> None:
    """Call this in main.py to wire up all exception handlers."""

    @app.exception_handler(FaceInsightException)
    async def faceinsight_exception_handler(
        request: Request, exc: FaceInsightException
    ) -> JSONResponse:
        logger.warning(f"[{exc.status_code}] {exc.message} | path={request.url.path}")
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": exc.message, "status_code": exc.status_code},
        )

    @app.exception_handler(Exception)
    async def generic_exception_handler(
        request: Request, exc: Exception
    ) -> JSONResponse:
        logger.exception(f"Unhandled error on {request.url.path}: {exc}")
        return JSONResponse(
            status_code=500,
            content={"error": "Internal server error", "status_code": 500},
        )