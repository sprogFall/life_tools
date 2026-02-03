import tempfile

from fastapi.testclient import TestClient

from sync_server.main import create_app


def test_healthz() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)
        resp = client.get("/healthz")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"


def test_sync_v2_roundtrip_use_client_then_use_server() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 1) 首次同步：服务端无快照，客户端上传 -> use_client
        req1 = {
            "protocol_version": 2,
            "user_id": "u1",
            "client_time": 1730000000000,
            "client_state": {"last_server_revision": None, "client_is_empty": False},
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 1, "updated_at": 100}], "time_entries": []},
                }
            },
        }
        resp1 = client.post("/sync/v2", json=req1)
        assert resp1.status_code == 200
        body1 = resp1.json()
        assert body1["success"] is True
        assert body1["decision"] == "use_client"
        assert isinstance(body1["server_time"], int)
        assert body1["server_revision"] == 1

        # 2) 空客户端来同步：触发空数据保护 -> use_server，返回 tools_data
        req2 = {
            "protocol_version": 2,
            "user_id": "u1",
            "client_time": 1730000000100,
            "client_state": {"last_server_revision": 1, "client_is_empty": True},
            "tools_data": {
                "work_log": {"version": 1, "data": {"tasks": [], "time_entries": []}}
            },
        }
        resp2 = client.post("/sync/v2", json=req2)
        assert resp2.status_code == 200
        body2 = resp2.json()
        assert body2["success"] is True
        assert body2["decision"] == "use_server"
        assert body2["server_revision"] == 1
        assert "tools_data" in body2
        assert body2["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 1


def test_sync_v1_use_server_when_server_newer() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 第一次：上传数据（服务端存储）
        req1 = {
            "user_id": "u1",
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 1, "updated_at": 100}], "time_entries": []},
                }
            },
        }
        resp1 = client.post("/sync", json=req1)
        assert resp1.status_code == 200
        assert resp1.json()["success"] is True

        # 第二次：客户端空快照；服务端应返回 tools_data
        req2 = {
            "user_id": "u1",
            "tools_data": {
                "work_log": {"version": 1, "data": {"tasks": [], "time_entries": []}}
            },
        }
        resp2 = client.post("/sync", json=req2)
        assert resp2.status_code == 200
        body2 = resp2.json()
        assert body2["success"] is True
        assert "tools_data" in body2
        assert body2["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 1

