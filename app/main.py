from fastapi import FastAPI
from fastapi.responses import PlainTextResponse

app = FastAPI(title="TRDL", version="1.0.0")

@app.get("/", response_class=PlainTextResponse)
def get_answer():
    return "42"

@app.get("/health/live")
def liveness():
    return {"status": "alive"}

@app.get("/health/ready")
def readiness():
    return {"status": "ready"}
