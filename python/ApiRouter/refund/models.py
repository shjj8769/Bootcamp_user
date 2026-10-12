"""Request schemas for refund create and update endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class Refund(BaseModel):
    email: str
    p_r_id: int
    e_id: Optional[str] = None
    p_r_reason: str
    p_r_image: Optional[str] = None
    p_r_date: Optional[datetime] = None


class RefundUpdate(BaseModel):
    is_refunded: int
    e_id: Optional[str] = None
