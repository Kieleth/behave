from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql+asyncpg://behave:behave@localhost:5432/behave"
    jwt_secret: str = "change-me-in-production"
    jwt_algorithm: str = "HS256"
    jwt_expire_hours: int = 720  # 30 days

    claude_api_key: str = ""
    claude_model: str = "claude-sonnet-4-20250514"

    apple_team_id: str = ""
    apple_key_id: str = ""
    apple_bundle_id: str = "com.kieleth.behave"

    model_config = {"env_prefix": "BEHAVE_"}


settings = Settings()
