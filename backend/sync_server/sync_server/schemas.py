from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class SyncRequestV1(BaseModel):
    user_id: str = Field(min_length=1)
    tools_data: dict[str, dict[str, Any]]


class SyncResponseV1(BaseModel):
    success: bool
    message: str | None = None
    tools_data: dict[str, dict[str, Any]] | None = None
    server_time: int


class SyncClientState(BaseModel):
    last_server_revision: int | None = None
    client_is_empty: bool


class SyncRequestV2(BaseModel):
    protocol_version: int
    user_id: str = Field(min_length=1)
    client_time: int
    client_state: SyncClientState
    tools_data: dict[str, dict[str, Any]]


class SyncResponseV2(BaseModel):
    success: bool
    decision: str
    message: str | None = None
    tools_data: dict[str, dict[str, Any]] | None = None
    server_time: int
    server_revision: int


class RollbackRequest(BaseModel):
    user_id: str = Field(min_length=1)
    target_revision: int = Field(gt=0)
