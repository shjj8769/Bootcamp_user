"""Request schemas for pickup endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class Pickup(BaseModel):
    e_id: str
    email: str
    SKU: str
    store_seq: int
    p_date: Optional[datetime] = None
