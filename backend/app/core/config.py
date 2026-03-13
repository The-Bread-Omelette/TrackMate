from pydantic_settings import BaseSettings, SettingsConfigDict
from typing import List
import json


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
    )

    # Database
    DATABASE_URL: str

    # JWT
    SECRET_KEY: str
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 7

    # Cookie config
    COOKIE_SECURE: bool = False
    COOKIE_SAMESITE: str = "lax"  # can be 'none', 'lax', or 'strict'

    # App
    APP_ENV: str = "development"
    APP_HOST: str = "0.0.0.0"
    APP_PORT: int = 8000
    CORS_ORIGINS: str = '["*"]'

    @property
    def cors_origins_list(self) -> List[str]:
        try:
            print("hello")
            return json.loads(self.CORS_ORIGINS)
        except Exception:
            return ["http://localhost:3000", "http://localhost:62140"]

    @property
    def is_development(self) -> bool:
        return self.APP_ENV == "development"


settings = Settings()
