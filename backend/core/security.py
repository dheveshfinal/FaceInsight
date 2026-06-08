# ==============================================================
#  FaceInsight – backend/core/security.py
#  JWT creation/verification + bcrypt password hashing
# ==============================================================

from datetime import datetime, timedelta, timezone
from typing import Optional, Union

from jose import JWTError, jwt
from passlib.context import CryptContext
from loguru import logger

from core.config import get_settings

settings = get_settings()

# ── Password hashing ───────────────────────────────────────────
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def hash_password(plain_password: str) -> str:
    """Hash a plain-text password using bcrypt."""
    return pwd_context.hash(plain_password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a plain-text password against a bcrypt hash."""
    return pwd_context.verify(plain_password, hashed_password)


# ── Token helpers ──────────────────────────────────────────────
def _create_token(
    subject: Union[str, int],
    token_type: str,           # "access" | "refresh"
    expires_delta: timedelta,
    extra_claims: Optional[dict] = None,
) -> str:
    """
    Internal token factory.
    All tokens carry: sub, type, iat, exp.
    """
    now = datetime.now(timezone.utc)
    payload = {
        "sub": str(subject),
        "type": token_type,
        "iat": now,
        "exp": now + expires_delta,
    }
    if extra_claims:
        payload.update(extra_claims)

    return jwt.encode(
        payload,
        settings.JWT_SECRET_KEY,
        algorithm=settings.JWT_ALGORITHM,
    )


def create_access_token(user_id: int, email: str) -> str:
    """Create a short-lived access token."""
    return _create_token(
        subject=user_id,
        token_type="access",
        expires_delta=timedelta(
            minutes=settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES
        ),
        extra_claims={"email": email},
    )


def create_refresh_token(user_id: int) -> str:
    """Create a long-lived refresh token."""
    return _create_token(
        subject=user_id,
        token_type="refresh",
        expires_delta=timedelta(
            days=settings.JWT_REFRESH_TOKEN_EXPIRE_DAYS
        ),
    )


def decode_access_token(token: str) -> Optional[dict]:
    """
    Decode and validate an access token.
    Returns the payload dict on success, None on any failure.
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        if payload.get("type") != "access":
            logger.warning("Token type mismatch — expected 'access'")
            return None
        return payload
    except JWTError as e:
        logger.warning(f"JWT decode error: {e}")
        return None


def decode_refresh_token(token: str) -> Optional[dict]:
    """
    Decode and validate a refresh token.
    Returns the payload dict on success, None on any failure.
    """
    try:
        payload = jwt.decode(
            token,
            settings.JWT_SECRET_KEY,
            algorithms=[settings.JWT_ALGORITHM],
        )
        if payload.get("type") != "refresh":
            logger.warning("Token type mismatch — expected 'refresh'")
            return None
        return payload
    except JWTError as e:
        logger.warning(f"JWT refresh decode error: {e}")
        return None