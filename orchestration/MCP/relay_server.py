"""Minimal FastAPI MCP relay server for MAOS MVP."""

from __future__ import annotations

from pathlib import Path

import uvicorn
import yaml
from fastapi import FastAPI
from pydantic import BaseModel

from telemetry.emit_heartbeat import emit_heartbeat


def _load_config() -> dict:
    path = Path("configs/global_config.yaml")
    return yaml.safe_load(path.read_text(encoding="utf-8"))


class HeartbeatPayload(BaseModel):
    source: str = "mcp-relay"


app = FastAPI(title="MAOS MCP Relay", version="0.1.0")


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/heartbeat")
def heartbeat(payload: HeartbeatPayload):
    emit_heartbeat(source=payload.source)
    return {"status": "heartbeat-recorded"}


def main() -> None:
    config = _load_config()
    uvicorn.run(
        "orchestration.MCP.relay_server:app",
        host=config["mcp"]["host"],
        port=config["mcp"]["port"],
        reload=False,
    )


if __name__ == "__main__":
    main()
