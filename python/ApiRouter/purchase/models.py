"""Request schemas for purchase create and update endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class Purchase(BaseModel):
    p_id: Optional[int] = None
    p_seq: int
    p_count: int
    p_date: Optional[datetime] = None
    p_price: int
    email: str
    SKU: str
    store_seq: int


class PurchaseUpdate(BaseModel):
    p_count: int
    p_date: Optional[datetime] = None
    p_price: int
    store_seq: int
