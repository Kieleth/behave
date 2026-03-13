from fastapi import FastAPI
from contextlib import asynccontextmanager

from app.database import engine, Base
from app.routers import auth, sessions, coaching, health


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: create tables (alembic handles migrations in prod)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    # Shutdown
    await engine.dispose()


app = FastAPI(
    title="Behave API",
    version="2.0.0",
    lifespan=lifespan,
)

app.include_router(health.router)
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(sessions.router, prefix="/api/sessions", tags=["sessions"])
app.include_router(coaching.router, prefix="/api/coaching", tags=["coaching"])
