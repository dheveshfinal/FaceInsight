# ==============================================================
#  FaceInsight – backend/api/v1/endpoints/chat.py
#  AI Chat with RAG retrieval (context-aware skincare Q&A)
# ==============================================================

import uuid
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status, Header
from pydantic import BaseModel, Field
from loguru import logger
from sqlalchemy.ext.asyncio import AsyncSession

from core.dependecies import get_current_user_or_anonymous, get_db
from database.models import User
from services.ai_service import AIService

router = APIRouter()
ai_service = AIService()


# ── Request/Response Models ────────────────────────────────────

class ChatMessage(BaseModel):
    question: str


class ChatResponse(BaseModel):
    answer: str
    session_id: Optional[str] = Field(default=None, description="Session ID for anonymous users")


# ── Session Management ─────────────────────────────────────────

def get_or_create_session(x_session_id: str = Header(None)) -> str:
    """
    Get existing session ID from header or create new one for anonymous users.
    Anonymous sessions are identified by x-session-id header.
    """
    if x_session_id:
        logger.info(f"Using existing session: {x_session_id}")
        return x_session_id
    
    new_session_id = str(uuid.uuid4())
    logger.info(f"Created new session: {new_session_id}")
    return new_session_id


# ── POST /chat/ask – Ask AI skincare question (with RAG) ────────

@router.post("/ask", response_model=ChatResponse, tags=["Chat"])
async def ask_chat(
    msg: ChatMessage,
    current_user: User = Depends(get_current_user_or_anonymous),
    session_id: str = Depends(get_or_create_session),
    db: AsyncSession = Depends(get_db),
):
    """
    Ask an AI skincare question using RAG.
    
    For logged-in users: Retrieves their own historical recommendations.
    For anonymous users: Retrieves only their session's recommendations.
    
    Headers:
    - x-session-id (optional): Session ID for anonymous users
    
    Returns: { answer, session_id }
    """
    logger.info(f"Chat question: '{msg.question}' | user={current_user.id}, session={session_id}")
    
    if not msg.question or not msg.question.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Question cannot be empty"
        )
    
    user_id = current_user.id if hasattr(current_user, 'id') else None
    
    try:
        # Use RAG to get answer with user/session context
        answer = ai_service.chat_rag(
            user_question=msg.question,
            user_id=user_id,
            session_id=session_id
        )
        
        return ChatResponse(
            answer=answer,
            session_id=session_id if not user_id else None  # Only return session_id for anonymous
        )
        
    except Exception as e:
        logger.error(f"Error processing chat: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to process your question: {str(e)}"
        )


# ── DELETE /chat/session – Cleanup anonymous session on app close ──

@router.delete("/session", tags=["Chat"])
async def cleanup_session(
    x_session_id: str = Header(None),
):
    """
    Delete all temporary data for an anonymous session when app closes.
    
    Headers:
    - x-session-id (required): Session ID to clean up
    
    Only works for anonymous users. Logged-in user data is never deleted.
    """
    if not x_session_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="x-session-id header is required"
        )
    
    logger.info(f"Cleanup request for session: {x_session_id}")
    
    success = ai_service.cleanup_session(x_session_id)
    
    if success:
        return {"message": f"Session {x_session_id} cleaned up successfully"}
    else:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to cleanup session"
        )


# ── GET /chat/history – Get chat history (future enhancement) ─────

@router.get("/history", tags=["Chat"])
async def get_chat_history(
    limit: int = 10,
    offset: int = 0,
    current_user: User = Depends(get_current_user_or_anonymous),
    session_id: str = Depends(get_or_create_session),
):
    """
    Get previous chat messages and responses for the user/session.
    
    For logged-in users: Returns their entire chat history.
    For anonymous users: Returns only their current session's history.
    
    Note: Currently returns empty as history storage isn't implemented.
    """
    # TODO: Implement chat history storage in database
    return {
        "history": [],
        "total": 0,
        "message": "Chat history storage coming soon"
    }
