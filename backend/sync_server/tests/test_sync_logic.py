from sync_server.sync_logic import (
    compute_latest_updated_at_ms,
    is_all_tools_empty,
    is_tool_snapshot_empty,
    decide_sync_v2,
)


def test_compute_latest_updated_at_ms_reads_nested_values() -> None:
    tools_data = {
        "work_log": {
            "version": 1,
            "data": {
                "tasks": [
                    {"id": 1, "updated_at": 10},
                    {"id": 2, "updated_at": 30},
                ],
                "time_entries": [],
            },
        },
        "tag_manager": {
            "version": 1,
            "data": {
                "tags": [{"id": 1, "updated_at": 20}],
                "tool_tags": [],
            },
        },
    }

    assert compute_latest_updated_at_ms(tools_data) == 30


def test_compute_latest_updated_at_ms_accepts_string_numbers() -> None:
    tools_data = {"x": {"version": 1, "data": {"items": [{"updated_at": "50"}]}}}
    assert compute_latest_updated_at_ms(tools_data) == 50


def test_is_tool_snapshot_empty_follows_client_deep_empty_rule() -> None:
    assert (
        is_tool_snapshot_empty({"version": 1, "data": {"tasks": [], "logs": []}})
        is True
    )
    assert (
        is_tool_snapshot_empty({"version": 1, "data": {"tasks": [{"id": 1}], "logs": []}})
        is False
    )


def test_is_all_tools_empty() -> None:
    assert is_all_tools_empty({}) is True
    assert (
        is_all_tools_empty({"a": {"version": 1, "data": {"items": []}}}) is True
    )
    assert (
        is_all_tools_empty({"a": {"version": 1, "data": {"items": [{"id": 1}]}}})
        is False
    )


def test_decide_sync_v2_prefers_server_when_server_newer() -> None:
    decision = decide_sync_v2(
        client_is_empty=False,
        client_updated_at_ms=10,
        server_has_snapshot=True,
        server_is_empty=False,
        server_updated_at_ms=20,
    )
    assert decision == "use_server"


def test_decide_sync_v2_prefers_client_when_client_newer() -> None:
    decision = decide_sync_v2(
        client_is_empty=False,
        client_updated_at_ms=20,
        server_has_snapshot=True,
        server_is_empty=False,
        server_updated_at_ms=10,
    )
    assert decision == "use_client"


def test_decide_sync_v2_noop_when_equal_updated_at() -> None:
    decision = decide_sync_v2(
        client_is_empty=False,
        client_updated_at_ms=10,
        server_has_snapshot=True,
        server_is_empty=False,
        server_updated_at_ms=10,
    )
    assert decision == "noop"


def test_decide_sync_v2_empty_protection() -> None:
    decision = decide_sync_v2(
        client_is_empty=True,
        client_updated_at_ms=0,
        server_has_snapshot=True,
        server_is_empty=False,
        server_updated_at_ms=100,
    )
    assert decision == "use_server"


def test_decide_sync_v2_new_user_uses_client() -> None:
    decision = decide_sync_v2(
        client_is_empty=False,
        client_updated_at_ms=123,
        server_has_snapshot=False,
        server_is_empty=True,
        server_updated_at_ms=0,
    )
    assert decision == "use_client"

