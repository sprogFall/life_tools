from __future__ import annotations

from collections.abc import Mapping
from typing import Any

from fastapi import HTTPException

WORK_LOG_TOOL_ID = "work_log"
ORPHAN_TASK_LABEL = "未归属 / 异常归属"
OPERATION_TYPE_UPDATE_TIME_ENTRY = 4
TARGET_TYPE_TIME_ENTRY = 1


WorkLogRow = dict[str, Any]


def apply_dashboard_work_log_rules(
    *,
    previous_tools_data: Mapping[str, Any],
    next_tools_data: dict[str, dict[str, Any]],
    now_ms: int,
) -> dict[str, dict[str, Any]]:
    next_work_log_snapshot = next_tools_data.get(WORK_LOG_TOOL_ID)
    if not isinstance(next_work_log_snapshot, dict):
        return next_tools_data

    next_work_log_data = next_work_log_snapshot.get("data")
    if not isinstance(next_work_log_data, dict):
        return next_tools_data

    previous_work_log_snapshot = previous_tools_data.get(WORK_LOG_TOOL_ID)
    previous_work_log_data = (
        previous_work_log_snapshot.get("data")
        if isinstance(previous_work_log_snapshot, Mapping)
        else {}
    )
    if not isinstance(previous_work_log_data, Mapping):
        previous_work_log_data = {}

    normalized_work_log_data = _prepare_work_log_data_for_dashboard(
        previous_data=previous_work_log_data,
        next_data=next_work_log_data,
        now_ms=now_ms,
    )

    normalized_tools_data = dict(next_tools_data)
    normalized_tools_data[WORK_LOG_TOOL_ID] = {
        **next_work_log_snapshot,
        "data": normalized_work_log_data,
    }
    return normalized_tools_data



def _prepare_work_log_data_for_dashboard(
    *,
    previous_data: Mapping[str, Any],
    next_data: Mapping[str, Any],
    now_ms: int,
) -> dict[str, Any]:
    tasks = _require_row_list(next_data.get("tasks"), section_label="tasks")
    time_entries = _require_row_list(next_data.get("time_entries"), section_label="time_entries")
    operation_logs = _require_row_list(next_data.get("operation_logs"), section_label="operation_logs")

    previous_tasks = _require_row_list(previous_data.get("tasks"), section_label="tasks")
    previous_time_entries = _require_row_list(
        previous_data.get("time_entries"), section_label="time_entries"
    )

    task_map = _build_indexed_rows(tasks, section_label="tasks")
    previous_task_map = _build_indexed_rows(previous_tasks, section_label="tasks")
    previous_time_entry_map = _build_indexed_rows(
        previous_time_entries,
        section_label="time_entries",
    )

    for entry in time_entries:
        _validate_time_entry_task_affiliation(entry, task_map)

    audit_logs = _build_reassignment_logs(
        previous_time_entry_map=previous_time_entry_map,
        next_time_entries=time_entries,
        previous_task_map=previous_task_map,
        next_task_map=task_map,
        existing_logs=operation_logs,
        now_ms=now_ms,
    )

    normalized_data = dict(next_data)
    normalized_data["operation_logs"] = [*operation_logs, *audit_logs]
    return normalized_data



def _require_row_list(raw_value: Any, *, section_label: str) -> list[WorkLogRow]:
    if raw_value is None:
        return []
    if not isinstance(raw_value, list):
        raise HTTPException(
            status_code=400,
            detail={"message": f"工作记录的 {section_label} 必须是数组"},
        )
    rows: list[WorkLogRow] = []
    for index, item in enumerate(raw_value):
        if not isinstance(item, dict):
            raise HTTPException(
                status_code=400,
                detail={"message": f"工作记录的 {section_label}[{index}] 必须是对象"},
            )
        rows.append(dict(item))
    return rows



def _build_indexed_rows(rows: list[WorkLogRow], *, section_label: str) -> dict[int, WorkLogRow]:
    indexed: dict[int, WorkLogRow] = {}
    for index, row in enumerate(rows):
        row_id = _require_numeric_id(row.get("id"), section_label=section_label, index=index)
        if row_id in indexed:
            raise HTTPException(
                status_code=400,
                detail={"message": f"工作记录的 {section_label} 存在重复 id={row_id}"},
            )
        indexed[row_id] = row
    return indexed



def _require_numeric_id(raw_value: Any, *, section_label: str, index: int) -> int:
    if isinstance(raw_value, bool):
        raise HTTPException(
            status_code=400,
            detail={"message": f"工作记录的 {section_label}[{index}].id 必须是数字"},
        )
    try:
        value = int(raw_value)
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail={"message": f"工作记录的 {section_label}[{index}].id 必须是数字"},
        ) from None
    return value



def _normalize_optional_numeric(value: Any) -> int | None:
    if value in (None, ""):
        return None
    if isinstance(value, bool):
        raise ValueError("bool is not a valid number")
    return int(value)



def _validate_time_entry_task_affiliation(
    entry: WorkLogRow,
    task_map: Mapping[int, WorkLogRow],
) -> None:
    entry_id = _safe_int(entry.get("id"))
    entry_label = str(entry.get("content") or f"工时记录#{entry_id if entry_id is not None else 'unknown'}")
    try:
        task_id = _normalize_optional_numeric(entry.get("task_id"))
    except (TypeError, ValueError):
        raise HTTPException(
            status_code=400,
            detail={"message": f"工时记录“{entry_label}”的 task_id 必须是数字或空值"},
        ) from None

    if task_id is None:
        return
    if task_id not in task_map:
        raise HTTPException(
            status_code=400,
            detail={
                "message": f"工时记录“{entry_label}”的 task_id={task_id} 未匹配到任务，请先创建目标任务或重新归属"
            },
        )



def _build_reassignment_logs(
    *,
    previous_time_entry_map: Mapping[int, WorkLogRow],
    next_time_entries: list[WorkLogRow],
    previous_task_map: Mapping[int, WorkLogRow],
    next_task_map: Mapping[int, WorkLogRow],
    existing_logs: list[WorkLogRow],
    now_ms: int,
) -> list[WorkLogRow]:
    next_log_id = max((_safe_int(item.get("id")) or 0 for item in existing_logs), default=0)
    audit_logs: list[WorkLogRow] = []

    for entry in next_time_entries:
        entry_id = _safe_int(entry.get("id"))
        if entry_id is None:
            continue
        previous_entry = previous_time_entry_map.get(entry_id)
        if previous_entry is None:
            continue

        previous_task_id = _safe_int_or_none(previous_entry.get("task_id"))
        next_task_id = _safe_int_or_none(entry.get("task_id"))
        if previous_task_id == next_task_id:
            continue

        next_log_id += 1
        entry_title = str(entry.get("content") or f"工时记录#{entry_id}")
        previous_task_title = _resolve_task_title(previous_task_id, previous_task_map, next_task_map)
        next_task_title = _resolve_task_title(next_task_id, next_task_map, previous_task_map)

        audit_logs.append(
            {
                "id": next_log_id,
                "operation_type": OPERATION_TYPE_UPDATE_TIME_ENTRY,
                "target_type": TARGET_TYPE_TIME_ENTRY,
                "target_id": entry_id,
                "target_title": entry_title,
                "summary": f"将工时“{entry_title}”从“{previous_task_title}”调整到“{next_task_title}”",
                "before_snapshot": {
                    "task_id": previous_task_id,
                    "task_title": previous_task_title,
                },
                "after_snapshot": {
                    "task_id": next_task_id,
                    "task_title": next_task_title,
                },
                "created_at": int(now_ms),
            }
        )

    return audit_logs



def _resolve_task_title(
    task_id: int | None,
    primary_task_map: Mapping[int, WorkLogRow],
    fallback_task_map: Mapping[int, WorkLogRow],
) -> str:
    if task_id is None:
        return ORPHAN_TASK_LABEL
    task_row = primary_task_map.get(task_id) or fallback_task_map.get(task_id)
    if not isinstance(task_row, Mapping):
        return f"任务#{task_id}"
    return str(task_row.get("title") or f"任务#{task_id}")



def _safe_int(value: Any) -> int | None:
    try:
        return _normalize_optional_numeric(value)
    except (TypeError, ValueError):
        return None



def _safe_int_or_none(value: Any) -> int | None:
    return _safe_int(value)
