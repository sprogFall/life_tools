from __future__ import annotations

import os
import time
from typing import Any

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from .schemas import SyncRequestV1, SyncRequestV2, SyncResponseV1, SyncResponseV2
from .storage import SqliteSnapshotStore
from .sync_logic import (
    compute_latest_updated_at_ms,
    decide_sync_v2,
    is_all_tools_empty,
)


def _now_ms() -> int:
    return int(time.time() * 1000)


def create_app(*, db_path: str) -> FastAPI:
    app = FastAPI(title="life_tools sync server", version="0.1.0")

    store = SqliteSnapshotStore(db_path=db_path)
    app.state.store = store

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(HTTPException)
    async def _handle_http_exception(
        _request: Request,
        exc: HTTPException,
    ) -> JSONResponse:
        if isinstance(exc.detail, dict):
            return JSONResponse(status_code=exc.status_code, content=exc.detail)
        if isinstance(exc.detail, str):
            return JSONResponse(
                status_code=exc.status_code,
                content={"message": exc.detail},
            )
        return JSONResponse(
            status_code=exc.status_code,
            content={"message": f"请求失败，HTTP {exc.status_code}"},
        )

    @app.exception_handler(RequestValidationError)
    async def _handle_validation_error(
        _request: Request,
        _exc: RequestValidationError,
    ) -> JSONResponse:
        return JSONResponse(status_code=422, content={"message": "请求参数校验失败"})

    @app.get("/healthz")
    def healthz() -> dict[str, str]:
        return {"status": "ok"}

    @app.post("/sync", response_model=SyncResponseV1)
    def sync_v1(request: SyncRequestV1) -> SyncResponseV1:
        user_id = request.user_id.strip()
        if not user_id:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        server_time = _now_ms()

        client_tools_data: dict[str, Any] = request.tools_data
        client_is_empty = is_all_tools_empty(client_tools_data)
        client_updated_at_ms = compute_latest_updated_at_ms(client_tools_data)

        snapshot = store.get_snapshot(user_id)
        if snapshot is None:
            if client_is_empty:
                return SyncResponseV1(success=True, server_time=server_time)
            store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=None,
            )
            return SyncResponseV1(success=True, server_time=server_time)

        server_tools_data = snapshot.tools_data
        server_is_empty = is_all_tools_empty(server_tools_data)
        decision = decide_sync_v2(
            client_is_empty=client_is_empty,
            client_updated_at_ms=client_updated_at_ms,
            server_has_snapshot=True,
            server_is_empty=server_is_empty,
            server_updated_at_ms=snapshot.updated_at_ms,
        )

        if decision == "use_server":
            return SyncResponseV1(
                success=True,
                server_time=server_time,
                tools_data=server_tools_data,
            )

        if decision == "use_client":
            store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=None,
            )
            return SyncResponseV1(success=True, server_time=server_time)

        return SyncResponseV1(success=True, server_time=server_time)

    @app.post("/sync/v2", response_model=SyncResponseV2)
    def sync_v2(request: SyncRequestV2) -> SyncResponseV2:
        if request.protocol_version != 2:
            raise HTTPException(
                status_code=400,
                detail={"message": "protocol_version 必须为 2"},
            )

        user_id = request.user_id.strip()
        if not user_id:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        server_time = _now_ms()

        client_tools_data: dict[str, Any] = request.tools_data
        client_is_empty = bool(request.client_state.client_is_empty)
        client_updated_at_ms = compute_latest_updated_at_ms(client_tools_data)

        snapshot = store.get_snapshot(user_id)
        if snapshot is None:
            decision = decide_sync_v2(
                client_is_empty=client_is_empty,
                client_updated_at_ms=client_updated_at_ms,
                server_has_snapshot=False,
                server_is_empty=True,
                server_updated_at_ms=0,
            )
            if decision == "use_client":
                new_revision = store.save_client_snapshot(
                    user_id=user_id,
                    tools_data=client_tools_data,
                    updated_at_ms=client_updated_at_ms,
                    server_time_ms=server_time,
                    client_time_ms=request.client_time,
                )
                return SyncResponseV2(
                    success=True,
                    decision="use_client",
                    server_time=server_time,
                    server_revision=new_revision,
                )

            return SyncResponseV2(
                success=True,
                decision="noop",
                server_time=server_time,
                server_revision=0,
            )

        server_tools_data = snapshot.tools_data
        server_is_empty = is_all_tools_empty(server_tools_data)
        decision = decide_sync_v2(
            client_is_empty=client_is_empty,
            client_updated_at_ms=client_updated_at_ms,
            server_has_snapshot=True,
            server_is_empty=server_is_empty,
            server_updated_at_ms=snapshot.updated_at_ms,
        )

        if decision == "use_server":
            return SyncResponseV2(
                success=True,
                decision="use_server",
                message="server newer than client",
                tools_data=server_tools_data,
                server_time=server_time,
                server_revision=snapshot.server_revision,
            )

        if decision == "use_client":
            new_revision = store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=request.client_time,
            )
            return SyncResponseV2(
                success=True,
                decision="use_client",
                message="client newer than server",
                server_time=server_time,
                server_revision=new_revision,
            )

        return SyncResponseV2(
            success=True,
            decision="noop",
            message="no changes",
            server_time=server_time,
            server_revision=snapshot.server_revision,
        )

    return app


def create_default_app() -> FastAPI:
    # 默认把数据放在 backend/sync_server/data/sync.db
    env_db_path = os.environ.get("SYNC_SERVER_DB_PATH", "").strip()
    if env_db_path:
        return create_app(db_path=env_db_path)

    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    return create_app(db_path=os.path.join(base_dir, "data", "sync.db"))


app = create_default_app()
