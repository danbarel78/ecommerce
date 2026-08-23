"""Data-access layer for products. Pure DB operations, no HTTP concerns."""

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from product_service.models import Product
from product_service.schemas import ProductCreate, ProductUpdate


async def get_product(session: AsyncSession, product_id: str) -> Product | None:
    """Return the product with ``product_id``, or ``None`` if it does not exist."""
    return await session.get(Product, product_id)


async def get_product_by_sku(session: AsyncSession, sku: str) -> Product | None:
    """Return the product with the given ``sku``, or ``None`` — used to enforce SKU uniqueness."""
    result = await session.execute(select(Product).where(Product.sku == sku))
    return result.scalar_one_or_none()


async def list_products(
    session: AsyncSession,
    *,
    limit: int,
    offset: int,
    q: str | None = None,
) -> tuple[list[Product], int]:
    """Return a page of products and the total match count as ``(items, total)``.

    ``q`` filters by a case-insensitive substring match on the title; ``total`` reflects
    the filter but ignores ``limit``/``offset`` so callers can paginate.
    """
    stmt = select(Product)
    count_stmt = select(func.count()).select_from(Product)
    if q:
        pattern = f"%{q}%"
        stmt = stmt.where(Product.title.ilike(pattern))
        count_stmt = count_stmt.where(Product.title.ilike(pattern))

    stmt = stmt.order_by(Product.created_at.desc()).limit(limit).offset(offset)
    items = list((await session.execute(stmt)).scalars().all())
    total = (await session.execute(count_stmt)).scalar_one()
    return items, total


async def create_product(session: AsyncSession, data: ProductCreate) -> Product:
    """Persist a new product and return it with server-populated fields (id, timestamps)."""
    product = Product(**data.model_dump())
    session.add(product)
    await session.commit()
    await session.refresh(product)
    return product


async def update_product(session: AsyncSession, product: Product, data: ProductUpdate) -> Product:
    """Apply a partial update (only fields explicitly set on ``data``) and return the product."""
    for field, value in data.model_dump(exclude_unset=True).items():
        setattr(product, field, value)
    await session.commit()
    await session.refresh(product)
    return product


async def delete_product(session: AsyncSession, product: Product) -> None:
    """Delete the given product and commit the transaction."""
    await session.delete(product)
    await session.commit()
