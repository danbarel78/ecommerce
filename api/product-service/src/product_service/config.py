"""Application settings, sourced from environment / Secrets Manager.

SQLite is used for tests/local dev; a real deployment points DATABASE_URL at Aurora
PostgreSQL (async driver). Auth settings describe the Cognito JWKS the API validates
tokens against (ARCHITECTURE.md §4.3.2)."""

from __future__ import annotations

from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="PRODUCT_API_", env_file=".env", extra="ignore")

    # --- Database ---
    # Async SQLAlchemy URL. Default = in-memory SQLite (tests/local).
    # Real: postgresql+asyncpg://<user>:<pass>@<aurora-proxy-endpoint>/ecommerce
    database_url: str = "sqlite+aiosqlite:///:memory:"

    # --- Auth (Cognito / OIDC) ---
    # When jwks_url is empty, auth runs in "local" mode: it verifies tokens against
    # auth_local_public_key (used by tests). In real deployments set jwks_url to the
    # Cognito JWKS endpoint and leave the local key unset.
    jwks_url: str = ""  # REQUIRES REAL VALUE — e.g. https://cognito-idp.<region>.amazonaws.com/<pool>/.well-known/jwks.json
    jwt_audience: str = "ecommerce-api"
    jwt_issuer: str = ""  # REQUIRES REAL VALUE — Cognito user-pool issuer URL
    jwt_algorithms: list[str] = Field(default_factory=lambda: ["RS256"])
    required_write_scope: str = "products:write"

    # PEM public key for local/test token verification (no live Cognito).
    auth_local_public_key: str = ""

    # --- Rate limiting ---
    rate_limit: str = "100/minute"  # slowapi token-bucket per client IP

    # --- App ---
    app_name: str = "product-service"
    log_level: str = "INFO"


@lru_cache
def get_settings() -> Settings:
    return Settings()
