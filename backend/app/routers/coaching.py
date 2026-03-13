import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import httpx

from app.config import settings
from app.database import get_db
from app.models.user import User
from app.models.coaching import CoachingMessage
from app.auth import get_current_user

router = APIRouter()

SYSTEM_PROMPT = """You are Behave, an AI coaching assistant that helps people improve their 
professional presence during remote work. You analyze behavioral data from camera and speech 
monitoring to provide actionable, science-backed feedback.

Your coaching style is:
- Direct and constructive, not patronizing
- Grounded in behavioral science and ergonomics research
- Focused on actionable micro-improvements
- Encouraging progress while being honest about patterns

When given session data, analyze patterns and suggest specific improvements.
When asked general questions, provide evidence-based guidance on posture, 
facial expressions, habits, and communication skills."""


class ChatRequest(BaseModel):
    message: str
    session_id: str | None = None


class ChatResponse(BaseModel):
    message: str


class MessageResponse(BaseModel):
    id: str
    role: str
    content: str
    created_at: datetime

    model_config = {"from_attributes": True}


@router.post("/chat", response_model=ChatResponse)
async def chat(
    body: ChatRequest,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    if not settings.claude_api_key:
        raise HTTPException(status_code=503, detail="Coaching not configured")

    # Save user message
    user_msg = CoachingMessage(
        id=uuid.uuid4(),
        user_id=user.id,
        session_id=uuid.UUID(body.session_id) if body.session_id else None,
        role="user",
        content=body.message,
    )
    db.add(user_msg)

    # Get recent conversation history
    result = await db.execute(
        select(CoachingMessage)
        .where(CoachingMessage.user_id == user.id)
        .order_by(CoachingMessage.created_at.desc())
        .limit(20)
    )
    history = list(reversed(result.scalars().all()))

    # Build messages for Claude
    messages = [
        {"role": msg.role, "content": msg.content}
        for msg in history
    ]
    messages.append({"role": "user", "content": body.message})

    # Call Claude API
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://api.anthropic.com/v1/messages",
            headers={
                "x-api-key": settings.claude_api_key,
                "anthropic-version": "2023-06-01",
                "content-type": "application/json",
            },
            json={
                "model": settings.claude_model,
                "max_tokens": 1024,
                "system": SYSTEM_PROMPT,
                "messages": messages,
            },
            timeout=30.0,
        )

    if response.status_code != 200:
        raise HTTPException(status_code=502, detail="Coaching service unavailable")

    assistant_content = response.json()["content"][0]["text"]

    # Save assistant response
    assistant_msg = CoachingMessage(
        id=uuid.uuid4(),
        user_id=user.id,
        session_id=uuid.UUID(body.session_id) if body.session_id else None,
        role="assistant",
        content=assistant_content,
    )
    db.add(assistant_msg)
    await db.commit()

    return ChatResponse(message=assistant_content)


@router.get("/history", response_model=list[MessageResponse])
async def get_history(
    limit: int = 50,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(CoachingMessage)
        .where(CoachingMessage.user_id == user.id)
        .order_by(CoachingMessage.created_at.desc())
        .limit(limit)
    )
    messages = list(reversed(result.scalars().all()))
    return [
        MessageResponse(
            id=str(m.id), role=m.role, content=m.content, created_at=m.created_at
        )
        for m in messages
    ]
