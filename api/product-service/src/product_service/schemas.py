"""Pydantic request/response models with validation."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class ProductBase(BaseModel):
    sku: str = Field(min_length=1, max_length=64)
    title: str = Field(min_length=1, max_length=255)
    description: str = Field(default="", max_length=4000)
    price_cents: int = Field(ge=0, description="Price in minor currency units (cents)")
    currency: str = Field(default="USD", min_length=3, max_length=3)
    stock: int = Field(default=0, ge=0)


class ProductCreate(ProductBase):
    pass


class ProductUpdate(BaseModel):
    """All fields optional — partial update."""

    title: str | None = Field(default=None, min_length=1, max_length=255)
    description: str | None = Field(default=None, max_length=4000)
    price_cents: int | None = Field(default=None, ge=0)
    currency: str | None = Field(default=None, min_length=3, max_length=3)
    stock: int | None = Field(default=None, ge=0)


class ProductOut(ProductBase):
    model_config = ConfigDict(from_attributes=True)

    id: str
    created_at: datetime
    updated_at: datetime


class ProductList(BaseModel):
    items: list[ProductOut]
    total: int
    limit: int
    offset: int
