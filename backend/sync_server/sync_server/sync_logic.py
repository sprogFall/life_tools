from __future__ import annotations

from collections.abc import Mapping, Sequence
from typing import Any


def _read_int_ms(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value if value >= 0 else None
    if isinstance(value, float):
        iv = int(value)
        return iv if iv >= 0 else None
    if isinstance(value, str):
        text = value.strip()
        if not text:
            return None
        iv = int(text) if text.isdigit() else None
        return iv if iv is not None and iv >= 0 else None
    return None


def compute_latest_updated_at_ms(tools_data: Mapping[str, Any]) -> int:
    """从 tools_data 全量快照里扫描 `updated_at`，取最大毫秒时间戳。

    约定：各工具导出的实体一般包含 `updated_at`（epoch ms）。
    """

    max_ms = 0
    stack: list[Any] = [tools_data]

    while stack:
        current = stack.pop()
        if isinstance(current, Mapping):
            for key, value in current.items():
                if key in ("updated_at", "updatedAt", "updated_at_ms", "updatedAtMs"):
                    ms = _read_int_ms(value)
                    if ms is not None and ms > max_ms:
                        max_ms = ms
                stack.append(value)
        elif isinstance(current, Sequence) and not isinstance(current, (str, bytes)):
            stack.extend(current)

    return max_ms


def is_tool_snapshot_empty(snapshot: Mapping[str, Any]) -> bool:
    data = snapshot.get("data")
    if data is None:
        return False
    return _is_deep_empty(data)


def is_all_tools_empty(tools_data: Mapping[str, Any]) -> bool:
    if not tools_data:
        return True
    return all(
        is_tool_snapshot_empty(tool_snapshot)
        for tool_snapshot in tools_data.values()
        if isinstance(tool_snapshot, Mapping)
    )


def _is_deep_empty(value: Any) -> bool:
    # 对齐客户端：数值/布尔不算“有数据”，避免被时间戳、计数等误判。
    if value is None:
        return True
    if isinstance(value, str):
        return value.strip() == ""
    if isinstance(value, bool):
        return True
    if isinstance(value, (int, float)):
        return True
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes)):
        return len(value) == 0
    if isinstance(value, Mapping):
        if not value:
            return True
        return all(_is_deep_empty(v) for v in value.values())
    return False


def decide_sync_v2(
    *,
    client_is_empty: bool,
    client_updated_at_ms: int,
    server_has_snapshot: bool,
    server_is_empty: bool,
    server_updated_at_ms: int,
) -> str:
    """根据“最新更新时间 + 空数据保护”决定本次同步方向。"""

    if not server_has_snapshot:
        return "noop" if client_is_empty else "use_client"

    # 空数据保护：空客户端不能覆盖非空服务端
    if client_is_empty and not server_is_empty:
        return "use_server"

    # 服务端为空但客户端非空：直接以客户端为准（即便缺少 updated_at 字段）
    if server_is_empty and not client_is_empty:
        return "use_client"

    if server_updated_at_ms > client_updated_at_ms:
        return "use_server"
    if client_updated_at_ms > server_updated_at_ms:
        return "use_client"
    return "noop"

