import tempfile

from fastapi.testclient import TestClient

from sync_server.main import create_app


def _v2_req(*, task_id: int, updated_at: int, client_time: int, last_rev: int | None, client_is_empty: bool) -> dict:
    return {
        "protocol_version": 2,
        "user_id": "u1",
        "client_time": client_time,
        "client_state": {
            "last_server_revision": last_rev,
            "client_is_empty": client_is_empty,
        },
        "tools_data": {
            "work_log": {
                "version": 1,
                "data": {
                    "tasks": [{"id": task_id, "updated_at": updated_at}],
                    "time_entries": [],
                },
            }
        },
    }


def test_snapshot_by_revision_api() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # rev=1
        resp1 = client.post(
            "/sync/v2",
            json=_v2_req(
                task_id=1,
                updated_at=100,
                client_time=1730000000000,
                last_rev=None,
                client_is_empty=False,
            ),
        )
        assert resp1.status_code == 200
        assert resp1.json()["server_revision"] == 1

        # rev=2
        resp2 = client.post(
            "/sync/v2",
            json=_v2_req(
                task_id=2,
                updated_at=200,
                client_time=1730000000100,
                last_rev=1,
                client_is_empty=False,
            ),
        )
        assert resp2.status_code == 200
        assert resp2.json()["server_revision"] == 2

        snap1 = client.get("/sync/snapshots/1", params={"user_id": "u1"})
        assert snap1.status_code == 200
        assert snap1.json()["snapshot"]["server_revision"] == 1
        assert snap1.json()["snapshot"]["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 1

        snap2 = client.get("/sync/snapshots/2", params={"user_id": "u1"})
        assert snap2.status_code == 200
        assert snap2.json()["snapshot"]["server_revision"] == 2
        assert snap2.json()["snapshot"]["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 2

        missing = client.get("/sync/snapshots/999", params={"user_id": "u1"})
        assert missing.status_code == 404


def test_rollback_should_create_new_revision_and_record() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # rev=1
        resp1 = client.post(
            "/sync/v2",
            json=_v2_req(
                task_id=1,
                updated_at=100,
                client_time=1730000000000,
                last_rev=None,
                client_is_empty=False,
            ),
        )
        assert resp1.status_code == 200
        assert resp1.json()["server_revision"] == 1

        # rev=2
        resp2 = client.post(
            "/sync/v2",
            json=_v2_req(
                task_id=2,
                updated_at=200,
                client_time=1730000000100,
                last_rev=1,
                client_is_empty=False,
            ),
        )
        assert resp2.status_code == 200
        assert resp2.json()["server_revision"] == 2

        rb = client.post("/sync/rollback", json={"user_id": "u1", "target_revision": 1})
        assert rb.status_code == 200
        body = rb.json()
        assert body["success"] is True
        assert body["restored_from_revision"] == 1
        assert body["server_revision"] == 3
        assert body["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 1

        # 服务端应变为 rev=3，并可被空客户端拉取
        pull = client.post(
            "/sync/v2",
            json={
                "protocol_version": 2,
                "user_id": "u1",
                "client_time": 1730000000200,
                "client_state": {"last_server_revision": 2, "client_is_empty": True},
                "tools_data": {
                    "work_log": {"version": 1, "data": {"tasks": [], "time_entries": []}}
                },
            },
        )
        assert pull.status_code == 200
        assert pull.json()["decision"] == "use_server"
        assert pull.json()["server_revision"] == 3
        assert pull.json()["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 1

        # 记录应包含 rollback
        records = client.get("/sync/records", params={"user_id": "u1", "limit": 10})
        assert records.status_code == 200
        items = records.json()["records"]
        assert any(r["decision"] == "rollback" for r in items)


def test_rollback_missing_revision_should_404() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        resp = client.post("/sync/rollback", json={"user_id": "u1", "target_revision": 999})
        assert resp.status_code == 404

