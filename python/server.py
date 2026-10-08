"""Standalone FastAPI server entry point for this Flutter project.

Run: python3 python/server.py
"""

from fastapi import FastAPI
import uvicorn


app = FastAPI(title="Shoes API")


@app.get("/health")
def health() -> dict[str, str]:
    """Return the process health without accessing any existing API or database."""
    return {"status": "ok", "service": "shoes"}


if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
