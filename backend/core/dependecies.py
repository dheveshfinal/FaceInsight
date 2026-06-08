# ==============================================================
#  FaceInsight – backend/core/dependencies.py
#  Reusable FastAPI dependencies (DB session, current user, etc.)
# ==============================================================

from typing import AsyncGenerator

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from core.security import decode_access_token
from database.session import AsyncSessionLocal
from database.models import User

# ── Bearer token scheme ────────────────────────────────────────
bearer_scheme = HTTPBearer(auto_error=False)


# ── Database session ───────────────────────────────────────────
async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Yield an async SQLAlchemy session per request.
    Commits on success, rolls back on exception, always closes.
    """
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()


# Alias for get_db (used in some places as get_db_async)
get_db_async = get_db


# ── Current user ID ────────────────────────────────────────────
async def get_current_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> int:
    """
    Extract and validate the JWT from the Authorization header.
    Returns the user_id (int) on success.
    Raises 401 on missing / invalid token.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )

    if not credentials:
        raise credentials_exception

    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise credentials_exception

    try:
        user_id = int(payload["sub"])
    except (KeyError, ValueError):
        raise credentials_exception

    return user_id


# ── Current user object ────────────────────────────────────────
async def get_current_user(
    user_id: int = Depends(get_current_user_id),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Get the current authenticated user as a User object.
    Raises 404 if user not found (shouldn't happen if token is valid).
    """
    stmt = select(User).filter(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
        )

    return user


# ── Optional current user (for public endpoints) ───────────────
async def get_optional_user_id(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> int | None:
    """
    Like get_current_user_id but returns None instead of raising
    when no/invalid token is present. Use on semi-public endpoints.
    """
    if not credentials:
        return None
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        return None
    try:
        return int(payload["sub"])
    except (KeyError, ValueError):
        return None


# ── Current user or anonymous system user ────────────────────────
async def get_current_user_or_anonymous(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db),
) -> User:
    """
    Get the current authenticated user, or return/create a special
    anonymous system user if no token is present.
    """
    user_id = None
    if credentials:
        payload = decode_access_token(credentials.credentials)
        if payload is not None:
            try:
                user_id = int(payload["sub"])
            except (KeyError, ValueError):
                pass

    if user_id is not None:
        stmt = select(User).filter(User.id == user_id)
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()
        if user:
            return user

    # Fallback to a special anonymous user
    stmt = select(User).filter(User.email == "anonymous@faceinsight.com")
    result = await db.execute(stmt)
    anon_user = result.scalar_one_or_none()
    
    if not anon_user:
        from core.security import hash_password
        import uuid
        anon_user = User(
            email="anonymous@faceinsight.com",
            username="anonymous",
            hashed_password=hash_password(uuid.uuid4().hex),
        )
        db.add(anon_user)
        await db.flush()  # get anon_user.id
        
    return anon_user