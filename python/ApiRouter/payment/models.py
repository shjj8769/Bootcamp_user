"""Request schemas for payment create and update endpoints."""

from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class Payment(BaseModel):
    email: str
    e_id: str
    pay_id: str
    pay_date: Optional[datetime] = None
    pay_price: int


class PaymentUpdate(BaseModel):
    pay_id: str
    pay_date: Optional[datetime] = None
    pay_price: int
