"""Request schemas for product create and update endpoints."""

from pydantic import BaseModel


class Product(BaseModel):
    SKU: str
    pr_code: str
    pr_name: str
    pr_brand: str
    pr_price: int
    category: str
    gender: str
    size: int
    color: str


class ProductUpdate(BaseModel):
    pr_code: str
    pr_name: str
    pr_brand: str
    pr_price: int
    category: str
    gender: str
    size: int
    color: str
