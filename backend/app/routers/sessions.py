import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.models.session import Session
from app.models.event import Event
from app.auth import get_current_user

router = APIRouter()


class SessionCreate(BaseModel):
    started_at: datetime


class SessionUpdate(BaseModel):
    ended_at: datetime | None = None
    duration_seconds: int | None = None
    posture_score: float | None = None
    expression_score: float | None = None
    habit_score: float | None = None
    speech_score: float | None = None
    overall_score: float | None = None


class EventCreate(BaseModel):
    type: str
    timestamp: datetime
    severity: str | None = None
    details: dict | None = None


class EventsBatch(BaseModel):
    events: list[EventCreate]


class SessionResponse(BaseModel):
    id: str
    started_at: datetime
    ended_at: datetime | None
    duration_seconds: int | None
    posture_score: float | None
    expression_score: float | None
    habit_score: float | None
    speech_score: float | None
    overall_score: float | None

    model_config = {"from_attributes": True}


@router.post("", response_model=SessionResponse)
async def create_session(
    body: SessionCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    session = Session(id=uuid.uuid4(), user_id=user.id, started_at=body.started_at)
    db.add(session)
    await db.commit()
    return SessionResponse(
        id=str(session.id),
        started_at=session.started_at,
        ended_at=None,
        duration_seconds=None,
        posture_score=None,
        expression_score=None,
        habit_score=None,
        speech_score=None,
        overall_score=None,
    )


@router.put("/{session_id}", response_model=SessionResponse)
async def update_session(
    session_id: uuid.UUID,
    body: SessionUpdate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.user_id == user.id)
    )
    session = result.scalar_one_or_none()
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    for field, value in body.model_dump(exclude_unset=True).items():
        setattr(session, field, value)
    await db.commit()

    return SessionResponse(
        id=str(session.id),
        started_at=session.started_at,
        ended_at=session.ended_at,
        duration_seconds=session.duration_seconds,
        posture_score=session.posture_score,
        expression_score=session.expression_score,
        habit_score=session.habit_score,
        speech_score=session.speech_score,
        overall_score=session.overall_score,
    )


@router.get("", response_model=list[SessionResponse])
async def list_sessions(
    limit: int = 20,
    offset: int = 0,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    result = await db.execute(
        select(Session)
        .where(Session.user_id == user.id)
        .order_by(Session.started_at.desc())
        .limit(limit)
        .offset(offset)
    )
    sessions = result.scalars().all()
    return [
        SessionResponse(
            id=str(s.id),
            started_at=s.started_at,
            ended_at=s.ended_at,
            duration_seconds=s.duration_seconds,
            posture_score=s.posture_score,
            expression_score=s.expression_score,
            habit_score=s.habit_score,
            speech_score=s.speech_score,
            overall_score=s.overall_score,
        )
        for s in sessions
    ]


@router.post("/{session_id}/events")
async def batch_create_events(
    session_id: uuid.UUID,
    body: EventsBatch,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    # Verify session belongs to user
    result = await db.execute(
        select(Session).where(Session.id == session_id, Session.user_id == user.id)
    )
    if not result.scalar_one_or_none():
        raise HTTPException(status_code=404, detail="Session not found")

    events = [
        Event(
            id=uuid.uuid4(),
            session_id=session_id,
            type=e.type,
            timestamp=e.timestamp,
            severity=e.severity,
            details=e.details,
        )
        for e in body.events
    ]
    db.add_all(events)
    await db.commit()

    return {"created": len(events)}
