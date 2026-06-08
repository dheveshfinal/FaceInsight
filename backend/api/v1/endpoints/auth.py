# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/auth.py
#  Authentication endpoints: login, register, logout, refresh
# ==============================================================

import uuid
from fastapi import APIRouter, Depends, HTTPException, status
from loguru import logger
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from pydantic import BaseModel, EmailStr

from core.dependecies import get_db, get_current_user
from core.security import (
    hash_password,
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_refresh_token,
)
from database.models import User

router = APIRouter()


# ── Request Models ───────────────────────────────────────────

class AuthRequest(BaseModel):
    email: str
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


# ── POST /auth/login – User login ──────────────────────────────

@router.post("/login", tags=["Auth"])
async def login(
    req: AuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Authenticate user and return access token.
    """
    logger.info(f"Login attempt: {req.email}")
    
    # Find user by email
    stmt = select(User).filter(User.email == req.email.strip().lower())
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(req.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
        
    access_token = create_access_token(user.id, user.email)
    refresh_token = create_refresh_token(user.id)
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user_id": user.id,
        "email": user.email,
    }


# ── POST /auth/register – User registration ────────────────────

@router.post("/register", tags=["Auth"])
async def register(
    req: AuthRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Register a new user.
    """
    email = req.email.strip().lower()
    logger.info(f"Register attempt: {email}")
    
    # Check if email is already taken
    stmt = select(User).filter(User.email == email)
    result = await db.execute(stmt)
    existing_user = result.scalar_one_or_none()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email already exists",
        )
        
    # Generate unique username
    base_username = email.split("@")[0]
    # Clean username to only alphanumeric/underscores/dashes and under 50 chars
    username = "".join(c for c in base_username if c.isalnum() or c in ("_", "-"))[:40]
    if not username:
        username = f"user_{uuid.uuid4().hex[:8]}"
        
    # Check username collision
    user_stmt = select(User).filter(User.username == username)
    user_res = await db.execute(user_stmt)
    if user_res.scalar_one_or_none():
        username = f"{username}_{uuid.uuid4().hex[:4]}"
        
    # Create user
    user = User(
        email=email,
        username=username,
        hashed_password=hash_password(req.password),
    )
    db.add(user)
    await db.flush()  # Get user.id
    
    access_token = create_access_token(user.id, user.email)
    refresh_token = create_refresh_token(user.id)
    
    logger.info(f"Registered user: {username} (ID: {user.id})")
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user_id": user.id,
        "email": user.email,
    }


# ── POST /auth/guest – Anonymous Guest Login ───────────────────

@router.post("/guest", tags=["Auth"])
async def guest_login(
    db: AsyncSession = Depends(get_db),
):
    """
    Create a temporary guest user and return credentials.
    Allows user to try the analysis without full registration.
    """
    guest_id = uuid.uuid4().hex[:8]
    email = f"guest_{guest_id}@guest.faceinsight.com"
    username = f"guest_{guest_id}"
    
    logger.info(f"Guest login attempt: {username}")
    
    user = User(
        email=email,
        username=username,
        hashed_password=hash_password(uuid.uuid4().hex), # random password
    )
    db.add(user)
    await db.flush()
    
    access_token = create_access_token(user.id, user.email)
    refresh_token = create_refresh_token(user.id)
    
    logger.info(f"Created guest user: {username} (ID: {user.id})")
    
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user_id": user.id,
        "email": user.email,
    }


# ── POST /auth/logout – User logout ────────────────────────────

@router.post("/logout", tags=["Auth"])
async def logout(
    current_user: User = Depends(get_current_user),
):
    """
    Logout user (invalidate token).
    """
    logger.info(f"Logout: {current_user.email}")
    return {"status": "logged_out"}


# ── POST /auth/refresh – Refresh access token ──────────────────

@router.post("/refresh", tags=["Auth"])
async def refresh_token(
    req: RefreshRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Refresh access token using refresh token.
    """
    payload = decode_refresh_token(req.refresh_token)
    if not payload:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )
        
    try:
        user_id = int(payload["sub"])
    except (KeyError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token payload",
        )
        
    stmt = select(User).filter(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()
    
    if not user:
         raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found",
         )
         
    access_token = create_access_token(user.id, user.email)
    
    return {
        "access_token": access_token,
        "refresh_token": req.refresh_token,
        "user_id": user.id,
        "email": user.email,
    }
