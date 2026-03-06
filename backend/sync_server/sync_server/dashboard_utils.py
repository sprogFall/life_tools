from __future__ import annotations

from typing import Any, Mapping

from .storage import UserSnapshot


def build_tool_summary(tool_id: str, tool_snapshot: Mapping[str, Any]) -> dict[str, Any]:
    version = int(tool_snapshot.get("version") or 0)
    data = tool_snapshot.get("data")
    section_counts: dict[str, int] = {}
    total_items = 0
    if isinstance(data, Mapping):
        for section_name, section_value in data.items():
            if isinstance(section_value, list):
                count = len(section_value)
            elif section_value is None:
                count = 0
            else:
                count = 1
            section_counts[str(section_name)] = count
            total_items += count

    return {
        "tool_id": tool_id,
        "version": version,
        "total_items": total_items,
        "section_counts": section_counts,
    }


def build_snapshot_summary(snapshot: UserSnapshot | None) -> dict[str, Any]:
    if snapshot is None:
        return {
            "has_snapshot": False,
            "server_revision": 0,
            "updated_at_ms": 0,
            "tool_count": 0,
            "tool_ids": [],
            "total_item_count": 0,
            "tool_summaries": [],
        }

    tool_ids = sorted(snapshot.tools_data.keys())
    tool_summaries = [
        build_tool_summary(tool_id, snapshot.tools_data.get(tool_id, {}))
        for tool_id in tool_ids
    ]
    return {
        "has_snapshot": True,
        "server_revision": snapshot.server_revision,
        "updated_at_ms": snapshot.updated_at_ms,
        "tool_count": len(tool_ids),
        "tool_ids": tool_ids,
        "total_item_count": sum(item["total_items"] for item in tool_summaries),
        "tool_summaries": tool_summaries,
    }
