"""Async SQLAlchemy engine/session setup and the declarative base.

The engine is built from Settings.database_url so the same code runs against in-memory
SQLite (tests) and Aurora PostgreSQL (real). A single shared in-memory SQLite connection
is used when the URL targets :memory: so schema + data persist across sessions in a test."""

from collections.abc import AsyncGenerator

from sqlalchemy.ext.asyncio import (
    AsyncEngine,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import StaticPool

from product_service.config import get_settings


class Base(DeclarativeBase):
    pass


def _build_engine() -> AsyncEngine:
    url = get_settings().database_url
    if url.startswith("sqlite"):
        # StaticPool keeps a single connection so an in-memory DB survives between sessions.
        return create_async_engine(
            url,
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
        )
    return create_async_engine(url, pool_pre_ping=True)


engine = _build_engine()
SessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


async def init_models() -> None:
    """Create tables. Real deployments manage schema via migrations, not this."""
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)


async def get_session() -> AsyncGenerator[AsyncSession, None]:
    async with SessionLocal() as session:
        yield session
