from fastapi import FastAPI, Request
from pydantic import BaseModel

app = FastAPI()

class Signal(BaseModel):
    x: int
    y: int
    timestamp: int

@app.post("/signal")
async def receive_signal(signal: Signal):
    print(f"📡 Received signal: {signal}")
    return {"status": "ok"}
