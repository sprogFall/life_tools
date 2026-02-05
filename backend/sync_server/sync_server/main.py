from __future__ import annotations

import os
import time
from typing import Any

from fastapi import FastAPI, HTTPException, Request, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from .schemas import (
    RollbackRequest,
    SyncRequestV1,
    SyncRequestV2,
    SyncResponseV1,
    SyncResponseV2,
)
from .storage import SqliteSnapshotStore
from .sync_diff import build_tools_diff
from .sync_logic import (
    compute_latest_updated_at_ms,
    decide_sync_v2,
    is_all_tools_empty,
)


def _now_ms() -> int:
    return int(time.time() * 1000)


def _normalize_force_decision(value: str | None) -> str | None:
    if value is None:
        return None
    v = value.strip().lower()
    if v in ("use_server", "use_client"):
        return v
    return None


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
        force = _normalize_force_decision(request.force_decision)

        if force == "use_client":
            server_revision_before = snapshot.server_revision if snapshot else 0
            server_updated_at_before = snapshot.updated_at_ms if snapshot else 0
            server_tools_before: dict[str, Any] = snapshot.tools_data if snapshot else {}
            diff = build_tools_diff(
                server_tools_data=server_tools_before,
                client_tools_data=client_tools_data,
            )
            new_revision = store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=None,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=1,
                decision="use_client",
                server_time_ms=server_time,
                client_time_ms=None,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=server_updated_at_before,
                server_updated_at_ms_after=client_updated_at_ms,
                server_revision_before=server_revision_before,
                server_revision_after=new_revision,
                diff=diff,
            )
            return SyncResponseV1(success=True, server_time=server_time)

        if force == "use_server":
            if snapshot is None:
                return SyncResponseV1(success=True, server_time=server_time)

            diff = build_tools_diff(
                server_tools_data=snapshot.tools_data,
                client_tools_data=client_tools_data,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=1,
                decision="use_server",
                server_time_ms=server_time,
                client_time_ms=None,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=snapshot.updated_at_ms,
                server_updated_at_ms_after=snapshot.updated_at_ms,
                server_revision_before=snapshot.server_revision,
                server_revision_after=snapshot.server_revision,
                diff=diff,
            )
            return SyncResponseV1(
                success=True,
                server_time=server_time,
                tools_data=snapshot.tools_data,
            )

        if snapshot is None:
            if client_is_empty:
                return SyncResponseV1(success=True, server_time=server_time)

            server_revision_before = 0
            server_updated_at_before = 0
            server_tools_before: dict[str, Any] = {}
            diff = build_tools_diff(
                server_tools_data=server_tools_before,
                client_tools_data=client_tools_data,
            )
            new_revision = store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=None,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=1,
                decision="use_client",
                server_time_ms=server_time,
                client_time_ms=None,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=server_updated_at_before,
                server_updated_at_ms_after=client_updated_at_ms,
                server_revision_before=server_revision_before,
                server_revision_after=new_revision,
                diff=diff,
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
            diff = build_tools_diff(
                server_tools_data=server_tools_data,
                client_tools_data=client_tools_data,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=1,
                decision="use_server",
                server_time_ms=server_time,
                client_time_ms=None,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=snapshot.updated_at_ms,
                server_updated_at_ms_after=snapshot.updated_at_ms,
                server_revision_before=snapshot.server_revision,
                server_revision_after=snapshot.server_revision,
                diff=diff,
            )
            return SyncResponseV1(
                success=True,
                server_time=server_time,
                tools_data=server_tools_data,
            )

        if decision == "use_client":
            diff = build_tools_diff(
                server_tools_data=server_tools_data,
                client_tools_data=client_tools_data,
            )
            new_revision = store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=None,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=1,
                decision="use_client",
                server_time_ms=server_time,
                client_time_ms=None,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=snapshot.updated_at_ms,
                server_updated_at_ms_after=client_updated_at_ms,
                server_revision_before=snapshot.server_revision,
                server_revision_after=new_revision,
                diff=diff,
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
        force = _normalize_force_decision(request.force_decision)

        if force == "use_client":
            server_revision_before = snapshot.server_revision if snapshot else 0
            server_updated_at_before = snapshot.updated_at_ms if snapshot else 0
            server_tools_before: dict[str, Any] = snapshot.tools_data if snapshot else {}
            diff = build_tools_diff(
                server_tools_data=server_tools_before,
                client_tools_data=client_tools_data,
            )
            new_revision = store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=request.client_time,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=2,
                decision="use_client",
                server_time_ms=server_time,
                client_time_ms=request.client_time,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=server_updated_at_before,
                server_updated_at_ms_after=client_updated_at_ms,
                server_revision_before=server_revision_before,
                server_revision_after=new_revision,
                diff=diff,
            )
            return SyncResponseV2(
                success=True,
                decision="use_client",
                message="forced use_client",
                server_time=server_time,
                server_revision=new_revision,
            )

        if force == "use_server":
            if snapshot is None:
                return SyncResponseV2(
                    success=True,
                    decision="noop",
                    message="no snapshot",
                    server_time=server_time,
                    server_revision=0,
                )

            diff = build_tools_diff(
                server_tools_data=snapshot.tools_data,
                client_tools_data=client_tools_data,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=2,
                decision="use_server",
                server_time_ms=server_time,
                client_time_ms=request.client_time,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=snapshot.updated_at_ms,
                server_updated_at_ms_after=snapshot.updated_at_ms,
                server_revision_before=snapshot.server_revision,
                server_revision_after=snapshot.server_revision,
                diff=diff,
            )
            return SyncResponseV2(
                success=True,
                decision="use_server",
                message="forced use_server",
                tools_data=snapshot.tools_data,
                server_time=server_time,
                server_revision=snapshot.server_revision,
            )

        if snapshot is None:
            decision = decide_sync_v2(
                client_is_empty=client_is_empty,
                client_updated_at_ms=client_updated_at_ms,
                server_has_snapshot=False,
                server_is_empty=True,
                server_updated_at_ms=0,
            )
            if decision == "use_client":
                diff = build_tools_diff(
                    server_tools_data={},
                    client_tools_data=client_tools_data,
                )
                new_revision = store.save_client_snapshot(
                    user_id=user_id,
                    tools_data=client_tools_data,
                    updated_at_ms=client_updated_at_ms,
                    server_time_ms=server_time,
                    client_time_ms=request.client_time,
                )
                store.add_sync_record(
                    user_id=user_id,
                    protocol_version=2,
                    decision="use_client",
                    server_time_ms=server_time,
                    client_time_ms=request.client_time,
                    client_updated_at_ms=client_updated_at_ms,
                    server_updated_at_ms_before=0,
                    server_updated_at_ms_after=client_updated_at_ms,
                    server_revision_before=0,
                    server_revision_after=new_revision,
                    diff=diff,
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
            diff = build_tools_diff(
                server_tools_data=server_tools_data,
                client_tools_data=client_tools_data,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=2,
                decision="use_server",
                server_time_ms=server_time,
                client_time_ms=request.client_time,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=snapshot.updated_at_ms,
                server_updated_at_ms_after=snapshot.updated_at_ms,
                server_revision_before=snapshot.server_revision,
                server_revision_after=snapshot.server_revision,
                diff=diff,
            )
            return SyncResponseV2(
                success=True,
                decision="use_server",
                message="server newer than client",
                tools_data=server_tools_data,
                server_time=server_time,
                server_revision=snapshot.server_revision,
            )

        if decision == "use_client":
            diff = build_tools_diff(
                server_tools_data=server_tools_data,
                client_tools_data=client_tools_data,
            )
            new_revision = store.save_client_snapshot(
                user_id=user_id,
                tools_data=client_tools_data,
                updated_at_ms=client_updated_at_ms,
                server_time_ms=server_time,
                client_time_ms=request.client_time,
            )
            store.add_sync_record(
                user_id=user_id,
                protocol_version=2,
                decision="use_client",
                server_time_ms=server_time,
                client_time_ms=request.client_time,
                client_updated_at_ms=client_updated_at_ms,
                server_updated_at_ms_before=snapshot.updated_at_ms,
                server_updated_at_ms_after=client_updated_at_ms,
                server_revision_before=snapshot.server_revision,
                server_revision_after=new_revision,
                diff=diff,
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

    @app.get("/sync/records")
    def list_sync_records(
        user_id: str = Query(min_length=1),
        limit: int = Query(default=50, ge=1, le=200),
        before_id: int | None = Query(default=None, ge=1),
    ) -> dict[str, Any]:
        uid = user_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        records = store.list_sync_records(user_id=uid, limit=limit, before_id=before_id)
        items: list[dict[str, Any]] = []
        for r in records:
            summary = r.diff.get("summary") if isinstance(r.diff, dict) else None
            items.append(
                {
                    "id": r.id,
                    "user_id": r.user_id,
                    "protocol_version": r.protocol_version,
                    "decision": r.decision,
                    "server_time": r.server_time_ms,
                    "client_time": r.client_time_ms,
                    "client_updated_at_ms": r.client_updated_at_ms,
                    "server_updated_at_ms_before": r.server_updated_at_ms_before,
                    "server_updated_at_ms_after": r.server_updated_at_ms_after,
                    "server_revision_before": r.server_revision_before,
                    "server_revision_after": r.server_revision_after,
                    "diff_summary": summary or {},
                }
            )

        next_before_id = items[-1]["id"] if len(items) == limit else None
        return {"success": True, "records": items, "next_before_id": next_before_id}

    @app.get("/sync/records/{record_id}")
    def get_sync_record(
        record_id: int,
        user_id: str = Query(min_length=1),
    ) -> dict[str, Any]:
        uid = user_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        record = store.get_sync_record(record_id)
        if record is None or record.user_id != uid:
            raise HTTPException(status_code=404, detail={"message": "记录不存在"})

        summary = record.diff.get("summary") if isinstance(record.diff, dict) else None
        return {
            "success": True,
            "record": {
                "id": record.id,
                "user_id": record.user_id,
                "protocol_version": record.protocol_version,
                "decision": record.decision,
                "server_time": record.server_time_ms,
                "client_time": record.client_time_ms,
                "client_updated_at_ms": record.client_updated_at_ms,
                "server_updated_at_ms_before": record.server_updated_at_ms_before,
                "server_updated_at_ms_after": record.server_updated_at_ms_after,
                "server_revision_before": record.server_revision_before,
                "server_revision_after": record.server_revision_after,
                "diff_summary": summary or {},
                "diff": record.diff,
            },
        }

    @app.get("/sync/snapshots/{revision}")
    def get_snapshot_by_revision(
        revision: int,
        user_id: str = Query(min_length=1),
    ) -> dict[str, Any]:
        uid = user_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})
        if revision <= 0:
            raise HTTPException(status_code=400, detail={"message": "revision 必须大于 0"})

        snapshot = store.get_snapshot_by_revision(uid, revision)
        if snapshot is None:
            raise HTTPException(status_code=404, detail={"message": "快照不存在"})

        return {
            "success": True,
            "snapshot": {
                "user_id": snapshot.user_id,
                "server_revision": snapshot.server_revision,
                "updated_at_ms": snapshot.updated_at_ms,
                "tools_data": snapshot.tools_data,
            },
        }

    @app.post("/sync/rollback")
    def rollback_to_revision(request: RollbackRequest) -> dict[str, Any]:
        user_id = request.user_id.strip()
        if not user_id:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        target_revision = int(request.target_revision)
        if target_revision <= 0:
            raise HTTPException(status_code=400, detail={"message": "target_revision 必须大于 0"})

        target = store.get_snapshot_by_revision(user_id, target_revision)
        if target is None:
            raise HTTPException(status_code=404, detail={"message": "目标快照不存在"})

        server_time = _now_ms()
        current = store.get_snapshot(user_id)
        server_tools_before: dict[str, Any] = {} if current is None else current.tools_data
        server_revision_before = 0 if current is None else current.server_revision
        server_updated_at_before = 0 if current is None else current.updated_at_ms

        # 回退属于一次“变更事件”，updated_at 取服务端当前时间以确保客户端可拉取到该版本。
        saved_updated_at_ms = max(int(target.updated_at_ms), int(server_time))

        diff = build_tools_diff(
            server_tools_data=server_tools_before,
            client_tools_data=target.tools_data,
        )
        new_revision = store.save_client_snapshot(
            user_id=user_id,
            tools_data=target.tools_data,
            updated_at_ms=saved_updated_at_ms,
            server_time_ms=server_time,
            client_time_ms=None,
        )
        store.add_sync_record(
            user_id=user_id,
            protocol_version=0,
            decision="rollback",
            server_time_ms=server_time,
            client_time_ms=None,
            client_updated_at_ms=0,
            server_updated_at_ms_before=server_updated_at_before,
            server_updated_at_ms_after=saved_updated_at_ms,
            server_revision_before=server_revision_before,
            server_revision_after=new_revision,
            diff=diff,
        )

        return {
            "success": True,
            "server_time": server_time,
            "server_revision": new_revision,
            "restored_from_revision": target_revision,
            "tools_data": target.tools_data,
        }

    return app


def create_default_app() -> FastAPI:
    # 默认把数据放在 backend/sync_server/data/sync.db
    env_db_path = os.environ.get("SYNC_SERVER_DB_PATH", "").strip()
    if env_db_path:
        return create_app(db_path=env_db_path)

    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    return create_app(db_path=os.path.join(base_dir, "data", "sync.db"))


app = create_default_app()
