import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, DateTime, Float
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Session(Base):
    __tablename__ = "sessions"

    id: Mapped[uuid.UUID] = mapped_column(primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("users.id"), index=True)
    started_at: Mapped[datetime] = mapped_column(DateTime)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    duration_seconds: Mapped[int | None] = mapped_column(nullable=True)
    posture_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    expression_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    habit_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    speech_score: Mapped[float | None] = mapped_column(Float, nullable=True)
    overall_score: Mapped[float | None] = mapped_column(Float, nullable=True)

    user: Mapped["User"] = relationship(back_populates="sessions")
    events: Mapped[list["Event"]] = relationship(back_populates="session", cascade="all, delete-orphan")
