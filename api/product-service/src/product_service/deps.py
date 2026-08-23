"""Shared FastAPI dependencies + a helper to fetch-or-404 a product."""

from fastapi import Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from product_service import crud
from product_service.db import get_session
from product_service.models import Product


async def get_product_or_404(
    product_id: str,
    session: AsyncSession = Depends(get_session),
) -> Product:
    product = await crud.get_product(session, product_id)
    if product is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Product {product_id} not found",
        )
    return product
