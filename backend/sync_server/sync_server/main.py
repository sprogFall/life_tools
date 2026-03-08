from __future__ import annotations

import os
import time
from typing import Any

from fastapi import FastAPI, HTTPException, Request, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError

from .dashboard_utils import build_snapshot_summary, build_tool_summary
from .dashboard_work_log import apply_dashboard_work_log_rules
from .schemas import (
    DashboardSnapshotUpdateRequest,
    DashboardToolUpdateRequest,
    DashboardUserCreateRequest,
    DashboardUserUpdateRequest,
    RollbackRequest,
    SyncRequestV1,
    SyncRequestV2,
    SyncResponseV1,
    SyncResponseV2,
)
from .storage import DashboardUser, SqliteSnapshotStore, SyncRecord, UserSnapshot
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


def _fallback_dashboard_user(*, user_id: str, snapshot: UserSnapshot | None) -> DashboardUser:
    base_time = 0 if snapshot is None else int(snapshot.updated_at_ms)
    return DashboardUser(
        user_id=user_id,
        display_name="",
        notes="",
        is_enabled=True,
        created_at_ms=base_time,
        updated_at_ms=base_time,
        last_seen_at_ms=None if base_time <= 0 else base_time,
    )


def _serialize_sync_record(record: SyncRecord, *, include_diff: bool) -> dict[str, Any]:
    summary = record.diff.get("summary") if isinstance(record.diff, dict) else None
    payload: dict[str, Any] = {
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
    }
    if include_diff:
        payload["diff"] = record.diff
    return payload


def _serialize_dashboard_user(
    *,
    profile: DashboardUser,
    snapshot: UserSnapshot | None,
) -> dict[str, Any]:
    return {
        "user_id": profile.user_id,
        "display_name": profile.display_name,
        "notes": profile.notes,
        "is_enabled": profile.is_enabled,
        "created_at_ms": profile.created_at_ms,
        "updated_at_ms": profile.updated_at_ms,
        "last_seen_at_ms": profile.last_seen_at_ms,
        "snapshot": build_snapshot_summary(snapshot),
    }


def _normalize_dashboard_tools_data(
    tools_data: dict[str, dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    normalized: dict[str, dict[str, Any]] = {}
    for raw_tool_id, raw_payload in tools_data.items():
        tool_id = raw_tool_id.strip()
        if not tool_id:
            raise HTTPException(status_code=400, detail={"message": "tools_data 中存在空 tool_id"})
        if not isinstance(raw_payload, dict):
            raise HTTPException(status_code=400, detail={"message": f"工具 {tool_id} 的快照必须是对象"})

        version = raw_payload.get("version")
        try:
            normalized_version = int(version)
        except (TypeError, ValueError):
            normalized_version = 0
        if normalized_version <= 0:
            raise HTTPException(status_code=400, detail={"message": f"工具 {tool_id} 缺少合法 version"})

        data = raw_payload.get("data")
        if not isinstance(data, dict):
            raise HTTPException(status_code=400, detail={"message": f"工具 {tool_id} 的 data 必须是对象"})

        normalized[tool_id] = {
            "version": normalized_version,
            "data": data,
        }
    return normalized


def _resolve_dashboard_user(
    *,
    store: SqliteSnapshotStore,
    user_id: str,
) -> tuple[DashboardUser | None, UserSnapshot | None]:
    snapshot = store.get_snapshot(user_id)
    profile = store.get_user_profile(user_id)
    if profile is None:
        if snapshot is None:
            return None, None
        profile = _fallback_dashboard_user(user_id=user_id, snapshot=snapshot)
    return profile, snapshot


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
        store.touch_user(user_id=user_id, now_ms=server_time)

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
        store.touch_user(user_id=user_id, now_ms=server_time)

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


    @app.get("/dashboard/users")
    def list_dashboard_users() -> dict[str, Any]:
        profile_map = {item.user_id: item for item in store.list_user_profiles()}
        snapshot_map = {item.user_id: item for item in store.list_snapshots()}

        users: list[tuple[int, int, str, dict[str, Any]]] = []
        for user_id in sorted(set(profile_map.keys()) | set(snapshot_map.keys())):
            snapshot = snapshot_map.get(user_id)
            profile = profile_map.get(user_id)
            if profile is None:
                profile = _fallback_dashboard_user(user_id=user_id, snapshot=snapshot)
            sort_last_seen = profile.last_seen_at_ms or (0 if snapshot is None else snapshot.updated_at_ms)
            sort_updated = max(profile.updated_at_ms, 0 if snapshot is None else snapshot.updated_at_ms)
            users.append(
                (
                    int(sort_last_seen),
                    int(sort_updated),
                    user_id,
                    _serialize_dashboard_user(profile=profile, snapshot=snapshot),
                )
            )

        users.sort(key=lambda item: (-item[0], -item[1], item[2]))
        return {"success": True, "users": [item[3] for item in users]}

    @app.post("/dashboard/users")
    def create_dashboard_user(request: DashboardUserCreateRequest) -> dict[str, Any]:
        user_id = request.user_id.strip()
        if not user_id:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        profile = store.upsert_user_profile(
            user_id=user_id,
            display_name=request.display_name.strip(),
            notes=request.notes.strip(),
            is_enabled=bool(request.is_enabled),
            now_ms=_now_ms(),
        )
        snapshot = store.get_snapshot(user_id)
        return {
            "success": True,
            "user": _serialize_dashboard_user(profile=profile, snapshot=snapshot),
        }

    @app.get("/dashboard/users/{user_id}")
    def get_dashboard_user(user_id: str) -> dict[str, Any]:
        uid = user_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        profile, snapshot = _resolve_dashboard_user(store=store, user_id=uid)
        if profile is None:
            raise HTTPException(status_code=404, detail={"message": "用户不存在"})

        recent_records = [
            _serialize_sync_record(record, include_diff=False)
            for record in store.list_sync_records(user_id=uid, limit=20, before_id=None)
        ]
        return {
            "success": True,
            "user": _serialize_dashboard_user(profile=profile, snapshot=snapshot),
            "snapshot": {
                **build_snapshot_summary(snapshot),
                "tools_data": {} if snapshot is None else snapshot.tools_data,
            },
            "recent_records": recent_records,
        }

    @app.patch("/dashboard/users/{user_id}")
    def update_dashboard_user(
        user_id: str,
        request: DashboardUserUpdateRequest,
    ) -> dict[str, Any]:
        uid = user_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        profile = store.update_user_profile(
            user_id=uid,
            display_name=None if request.display_name is None else request.display_name.strip(),
            notes=None if request.notes is None else request.notes.strip(),
            is_enabled=request.is_enabled,
            now_ms=_now_ms(),
        )
        if profile is None:
            raise HTTPException(status_code=404, detail={"message": "用户不存在"})

        snapshot = store.get_snapshot(uid)
        return {
            "success": True,
            "user": _serialize_dashboard_user(profile=profile, snapshot=snapshot),
        }

    @app.get("/dashboard/users/{user_id}/tools/{tool_id}")
    def get_dashboard_tool(user_id: str, tool_id: str) -> dict[str, Any]:
        uid = user_id.strip()
        normalized_tool_id = tool_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})
        if not normalized_tool_id:
            raise HTTPException(status_code=400, detail={"message": "tool_id 不能为空"})

        _profile, snapshot = _resolve_dashboard_user(store=store, user_id=uid)
        if snapshot is None:
            raise HTTPException(status_code=404, detail={"message": "快照不存在"})

        tool_snapshot = snapshot.tools_data.get(normalized_tool_id)
        if not isinstance(tool_snapshot, dict):
            raise HTTPException(status_code=404, detail={"message": "工具数据不存在"})

        return {
            "success": True,
            "tool": {
                "tool_id": normalized_tool_id,
                "version": int(tool_snapshot.get("version") or 0),
                "data": tool_snapshot.get("data") or {},
                "summary": build_tool_summary(normalized_tool_id, tool_snapshot),
            },
            "snapshot": build_snapshot_summary(snapshot),
        }

    @app.put("/dashboard/users/{user_id}/snapshot")
    def update_dashboard_snapshot(
        user_id: str,
        request: DashboardSnapshotUpdateRequest,
    ) -> dict[str, Any]:
        uid = user_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})

        normalized_tools_data = _normalize_dashboard_tools_data(request.tools_data)
        server_time = _now_ms()
        store.touch_user(user_id=uid, now_ms=server_time)
        current = store.get_snapshot(uid)
        previous_tools_data = {} if current is None else current.tools_data
        normalized_tools_data = apply_dashboard_work_log_rules(
            previous_tools_data=previous_tools_data,
            next_tools_data=normalized_tools_data,
            now_ms=server_time,
        )

        saved_updated_at_ms = max(server_time, compute_latest_updated_at_ms(normalized_tools_data))
        server_revision_before = 0 if current is None else current.server_revision
        server_updated_at_before = 0 if current is None else current.updated_at_ms
        diff = build_tools_diff(
            server_tools_data=previous_tools_data,
            client_tools_data=normalized_tools_data,
        )
        message = (request.message or "").strip()
        if message:
            diff = {**diff, "dashboard_message": message}

        new_revision = store.save_client_snapshot(
            user_id=uid,
            tools_data=normalized_tools_data,
            updated_at_ms=saved_updated_at_ms,
            server_time_ms=server_time,
            client_time_ms=None,
        )
        store.add_sync_record(
            user_id=uid,
            protocol_version=99,
            decision="dashboard_update",
            server_time_ms=server_time,
            client_time_ms=None,
            client_updated_at_ms=saved_updated_at_ms,
            server_updated_at_ms_before=server_updated_at_before,
            server_updated_at_ms_after=saved_updated_at_ms,
            server_revision_before=server_revision_before,
            server_revision_after=new_revision,
            diff=diff,
        )

        snapshot = store.get_snapshot(uid)
        if snapshot is None:
            raise HTTPException(status_code=500, detail={"message": "快照保存后未找到"})
        profile, _ = _resolve_dashboard_user(store=store, user_id=uid)
        if profile is None:
            raise HTTPException(status_code=500, detail={"message": "用户资料未找到"})
        return {
            "success": True,
            "user": _serialize_dashboard_user(profile=profile, snapshot=snapshot),
            "snapshot": {
                **build_snapshot_summary(snapshot),
                "tools_data": snapshot.tools_data,
            },
            "recent_records": [
                _serialize_sync_record(record, include_diff=False)
                for record in store.list_sync_records(user_id=uid, limit=20, before_id=None)
            ],
        }


    @app.put("/dashboard/users/{user_id}/tools/{tool_id}")
    def update_dashboard_tool(
        user_id: str,
        tool_id: str,
        request: DashboardToolUpdateRequest,
    ) -> dict[str, Any]:
        uid = user_id.strip()
        normalized_tool_id = tool_id.strip()
        if not uid:
            raise HTTPException(status_code=400, detail={"message": "user_id 不能为空"})
        if not normalized_tool_id:
            raise HTTPException(status_code=400, detail={"message": "tool_id 不能为空"})

        server_time = _now_ms()
        store.touch_user(user_id=uid, now_ms=server_time)
        current = store.get_snapshot(uid)
        previous_tools_data = {} if current is None else current.tools_data
        next_tools_data = dict(previous_tools_data)
        next_tools_data[normalized_tool_id] = {
            "version": int(request.version),
            "data": request.data,
        }
        next_tools_data = apply_dashboard_work_log_rules(
            previous_tools_data=previous_tools_data,
            next_tools_data=next_tools_data,
            now_ms=server_time,
        )

        saved_updated_at_ms = max(server_time, compute_latest_updated_at_ms(next_tools_data))
        server_revision_before = 0 if current is None else current.server_revision
        server_updated_at_before = 0 if current is None else current.updated_at_ms
        diff = build_tools_diff(
            server_tools_data=previous_tools_data,
            client_tools_data=next_tools_data,
        )
        message = (request.message or "").strip()
        if message:
            diff = {**diff, "dashboard_message": message}

        new_revision = store.save_client_snapshot(
            user_id=uid,
            tools_data=next_tools_data,
            updated_at_ms=saved_updated_at_ms,
            server_time_ms=server_time,
            client_time_ms=None,
        )
        store.add_sync_record(
            user_id=uid,
            protocol_version=99,
            decision="dashboard_update",
            server_time_ms=server_time,
            client_time_ms=None,
            client_updated_at_ms=saved_updated_at_ms,
            server_updated_at_ms_before=server_updated_at_before,
            server_updated_at_ms_after=saved_updated_at_ms,
            server_revision_before=server_revision_before,
            server_revision_after=new_revision,
            diff=diff,
        )

        snapshot = store.get_snapshot(uid)
        assert snapshot is not None
        tool_snapshot = snapshot.tools_data.get(normalized_tool_id) or {}
        profile, _ = _resolve_dashboard_user(store=store, user_id=uid)
        assert profile is not None
        return {
            "success": True,
            "user": _serialize_dashboard_user(profile=profile, snapshot=snapshot),
            "snapshot": build_snapshot_summary(snapshot),
            "tool": {
                "tool_id": normalized_tool_id,
                "version": int(tool_snapshot.get("version") or 0),
                "data": tool_snapshot.get("data") or {},
                "summary": build_tool_summary(normalized_tool_id, tool_snapshot),
            },
        }

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
        items = [_serialize_sync_record(record, include_diff=False) for record in records]

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

        return {
            "success": True,
            "record": _serialize_sync_record(record, include_diff=True),
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
        store.touch_user(user_id=user_id, now_ms=server_time)
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
