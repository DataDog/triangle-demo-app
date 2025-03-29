from pydantic import BaseModel
from typing import List

class Tower(BaseModel):
    id: str
    x: int
    y: int

class Signal(BaseModel):
    x: int
    y: int
    timestamp: int

class TowerDetection(BaseModel):
    id: str
    x: int
    y: int
    heard_at: int

class SignalBundle(BaseModel):
    signal_timestamp: int
    towers: List[TowerDetection]
