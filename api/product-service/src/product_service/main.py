"""Product Management API — the Catalog microservice's product CRUD surface.

Endpoints (ARCHITECTURE.md §4.2 catalog):
  GET    /products         list (paginated, filterable) — public
  GET    /products/{id}    fetch one — public
  POST   /products         create — requires products:write scope
  PUT    /products/{id}    update — requires products:write scope
  DELETE /products/{id}    delete — requires products:write scope
  GET    /healthz          liveness/readiness probe

Auth = JWT Bearer verified against Cognito JWKS. Rate limiting = slowapi per IP.
"""
# for testing purposes only. i will merge changes 
from __future__ import annotations

import logging
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from typing import Any

from fastapi import Depends, FastAPI, HTTPException, Query, Request, Response, status
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.middleware import SlowAPIMiddleware
from sqlalchemy.ext.asyncio import AsyncSession

from product_service import __version__, crud
from product_service.auth import require_write_scope
from product_service.config import get_settings
from product_service.db import get_session, init_models
from product_service.deps import get_product_or_404
from product_service.models import Product
from product_service.ratelimit import limiter
from product_service.schemas import ProductCreate, ProductList, ProductOut, ProductUpdate

settings = get_settings()
logging.basicConfig(level=settings.log_level)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(_app: FastAPI) -> AsyncGenerator[None]:
    # Convenience for local/dev/test. Real deployments manage schema via migrations.
    await init_models()
    yield


def _rate_limit_handler(request: Request, exc: Exception) -> Response:
    # Thin, correctly-typed adapter over slowapi's handler (which declares a narrower
    # RateLimitExceeded signature than Starlette's exception-handler contract).
    assert isinstance(exc, RateLimitExceeded)
    return _rate_limit_exceeded_handler(request, exc)


app = FastAPI(title="Product Management API", version=__version__, lifespan=lifespan)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_handler)
app.add_middleware(SlowAPIMiddleware)


@app.get("/healthz", tags=["ops"])
async def healthz() -> dict[str, str]:
    return {"status": "ok", "service": settings.app_name}


@app.get("/products", response_model=ProductList, tags=["products"])
async def list_products(
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    q: str | None = Query(default=None, description="Case-insensitive title filter"),
    session: AsyncSession = Depends(get_session),
) -> ProductList:
    items, total = await crud.list_products(session, limit=limit, offset=offset, q=q)
    return ProductList(
        items=[ProductOut.model_validate(item) for item in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@app.get("/products/{product_id}", response_model=ProductOut, tags=["products"])
async def get_product(product: Product = Depends(get_product_or_404)) -> Product:
    return product


@app.post(
    "/products",
    response_model=ProductOut,
    status_code=status.HTTP_201_CREATED,
    tags=["products"],
)
async def create_product(
    payload: ProductCreate,
    session: AsyncSession = Depends(get_session),
    _claims: dict[str, Any] = Depends(require_write_scope),
) -> Product:
    existing = await crud.get_product_by_sku(session, payload.sku)
    if existing is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=f"SKU {payload.sku} already exists",
        )
    return await crud.create_product(session, payload)


@app.put("/products/{product_id}", response_model=ProductOut, tags=["products"])
async def update_product(
    payload: ProductUpdate,
    product: Product = Depends(get_product_or_404),
    session: AsyncSession = Depends(get_session),
    _claims: dict[str, Any] = Depends(require_write_scope),
) -> Product:
    return await crud.update_product(session, product, payload)


@app.delete(
    "/products/{product_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    tags=["products"],
)
async def delete_product(
    product: Product = Depends(get_product_or_404),
    session: AsyncSession = Depends(get_session),
    _claims: dict[str, Any] = Depends(require_write_scope),
) -> Response:
    await crud.delete_product(session, product)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
