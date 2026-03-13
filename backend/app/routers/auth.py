import uuid

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models.user import User
from app.auth.jwt import create_token, get_current_user

router = APIRouter()


class AppleSignInRequest(BaseModel):
    apple_user_id: str
    email: str | None = None
    display_name: str | None = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str


class UserResponse(BaseModel):
    id: str
    email: str | None
    display_name: str | None

    model_config = {"from_attributes": True}


@router.post("/apple", response_model=TokenResponse)
async def apple_sign_in(body: AppleSignInRequest, db: AsyncSession = Depends(get_db)):
    """Exchange Apple Sign-In credentials for a JWT."""
    # TODO: Validate Apple identity token in production
    result = await db.execute(select(User).where(User.apple_user_id == body.apple_user_id))
    user = result.scalar_one_or_none()

    if not user:
        user = User(
            id=uuid.uuid4(),
            apple_user_id=body.apple_user_id,
            email=body.email,
            display_name=body.display_name,
        )
        db.add(user)
        await db.commit()

    token = create_token(user.id)
    return TokenResponse(access_token=token, user_id=str(user.id))


@router.get("/me", response_model=UserResponse)
async def get_me(user: User = Depends(get_current_user)):
    return UserResponse(id=str(user.id), email=user.email, display_name=user.display_name)
