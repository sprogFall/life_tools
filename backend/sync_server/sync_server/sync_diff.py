from __future__ import annotations

import hashlib
import json
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from typing import Any


def _stable_dumps(value: Any) -> str:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
        default=str,
    )


def _sha256_hex(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


@dataclass
class _DiffState:
    remaining: int
    truncated: bool = False

    def take(self) -> bool:
        if self.remaining <= 0:
            self.truncated = True
            return False
        self.remaining -= 1
        return True


def build_tools_diff(
    *,
    server_tools_data: Mapping[str, Any],
    client_tools_data: Mapping[str, Any],
    max_diffs: int = 200,
    max_depth: int = 8,
    max_list_items: int = 20,
) -> dict[str, Any]:
    """构建“服务端 vs 客户端”的差异信息（不包含敏感字段值，仅结构化路径）。"""

    state = _DiffState(remaining=max_diffs)

    tool_ids = set(server_tools_data.keys()) | set(client_tools_data.keys())
    tools: dict[str, Any] = {}
    changed_tools = 0
    diff_items_total = 0

    for tool_id in sorted(tool_ids):
        server_snapshot = server_tools_data.get(tool_id)
        client_snapshot = client_tools_data.get(tool_id)

        server_json = _stable_dumps(server_snapshot) if server_snapshot is not None else ""
        client_json = _stable_dumps(client_snapshot) if client_snapshot is not None else ""

        server_hash = _sha256_hex(server_json) if server_snapshot is not None else None
        client_hash = _sha256_hex(client_json) if client_snapshot is not None else None

        same = server_hash == client_hash

        diff_items: list[dict[str, Any]] = []
        if not same:
            changed_tools += 1
            _diff_value(
                state=state,
                a=server_snapshot,
                b=client_snapshot,
                path="",
                out=diff_items,
                depth=0,
                max_depth=max_depth,
                max_list_items=max_list_items,
            )
        diff_items_total += len(diff_items)

        tools[tool_id] = {
            "same": same,
            "server_hash": server_hash,
            "client_hash": client_hash,
            "diff_items": diff_items,
        }

        if state.truncated:
            break

    return {
        "summary": {
            "changed_tools": changed_tools,
            "diff_items": diff_items_total,
            "truncated": state.truncated,
        },
        "tools": tools,
    }


def _diff_value(
    *,
    state: _DiffState,
    a: Any,
    b: Any,
    path: str,
    out: list[dict[str, Any]],
    depth: int,
    max_depth: int,
    max_list_items: int,
) -> None:
    if not state.remaining:
        state.truncated = True
        return

    if depth >= max_depth:
        if a != b and state.take():
            out.append({"path": path, "change": "depth_truncated"})
        return

    if a is None and b is None:
        return
    if a is None and b is not None:
        if state.take():
            out.append({"path": path, "change": "added"})
        return
    if a is not None and b is None:
        if state.take():
            out.append({"path": path, "change": "removed"})
        return

    if type(a) is not type(b):
        if state.take():
            out.append(
                {
                    "path": path,
                    "change": "type_changed",
                    "server_type": type(a).__name__,
                    "client_type": type(b).__name__,
                }
            )
        return

    if isinstance(a, Mapping):
        a_keys = set(a.keys())
        b_keys = set(b.keys())

        for key in sorted(a_keys - b_keys):
            if not state.take():
                return
            out.append({"path": _join(path, str(key)), "change": "removed"})

        for key in sorted(b_keys - a_keys):
            if not state.take():
                return
            out.append({"path": _join(path, str(key)), "change": "added"})

        for key in sorted(a_keys & b_keys):
            _diff_value(
                state=state,
                a=a.get(key),
                b=b.get(key),
                path=_join(path, str(key)),
                out=out,
                depth=depth + 1,
                max_depth=max_depth,
                max_list_items=max_list_items,
            )
            if state.truncated:
                return
        return

    if isinstance(a, Sequence) and not isinstance(a, (str, bytes)):
        len_a = len(a)
        len_b = len(b)
        if len_a != len_b and state.take():
            out.append(
                {
                    "path": _join(path, "length"),
                    "change": "length_changed",
                    "server": len_a,
                    "client": len_b,
                }
            )

        compare_len = min(len_a, len_b, max_list_items)
        for i in range(compare_len):
            _diff_value(
                state=state,
                a=a[i],
                b=b[i],
                path=_join(path, str(i)),
                out=out,
                depth=depth + 1,
                max_depth=max_depth,
                max_list_items=max_list_items,
            )
            if state.truncated:
                return

        if (len_a > max_list_items or len_b > max_list_items) and not state.truncated:
            if state.take():
                out.append({"path": path, "change": "list_truncated"})
        return

    if a != b and state.take():
        out.append({"path": path, "change": "value_changed"})


def _join(prefix: str, key: str) -> str:
    if not prefix:
        return key
    return f"{prefix}.{key}"

