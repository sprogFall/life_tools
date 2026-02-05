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


def test_sync_v2_force_use_client_overrides_server_newer_snapshot() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 1) 先写入一个“较新”的服务端快照（updated_at=200）
        req1 = {
            "protocol_version": 2,
            "user_id": "u_force",
            "client_time": 1730000000000,
            "client_state": {"last_server_revision": None, "client_is_empty": False},
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 1, "updated_at": 200}], "time_entries": []},
                }
            },
        }
        resp1 = client.post("/sync/v2", json=req1)
        assert resp1.status_code == 200
        assert resp1.json()["decision"] == "use_client"
        assert resp1.json()["server_revision"] == 1

        # 2) 客户端提供更旧的数据（updated_at=100），但强制 use_client，应覆盖服务端
        req2 = {
            "protocol_version": 2,
            "user_id": "u_force",
            "client_time": 1730000000100,
            "client_state": {"last_server_revision": 1, "client_is_empty": False},
            "force_decision": "use_client",
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 2, "updated_at": 100}], "time_entries": []},
                }
            },
        }
        resp2 = client.post("/sync/v2", json=req2)
        assert resp2.status_code == 200
        body2 = resp2.json()
        assert body2["success"] is True
        assert body2["decision"] == "use_client"
        assert body2["server_revision"] == 2

        # 3) 用空客户端拉取，应拿到刚刚强制覆盖后的数据（id=2）
        req3 = {
            "protocol_version": 2,
            "user_id": "u_force",
            "client_time": 1730000000200,
            "client_state": {"last_server_revision": 2, "client_is_empty": True},
            "tools_data": {},
        }
        resp3 = client.post("/sync/v2", json=req3)
        assert resp3.status_code == 200
        body3 = resp3.json()
        assert body3["success"] is True
        assert body3["decision"] == "use_server"
        assert body3["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 2


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


def test_sync_v1_force_use_client_overrides_server_newer_snapshot() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 1) 写入服务端快照（updated_at=200）
        req1 = {
            "user_id": "u_force_v1",
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 1, "updated_at": 200}], "time_entries": []},
                }
            },
        }
        resp1 = client.post("/sync", json=req1)
        assert resp1.status_code == 200
        assert resp1.json()["success"] is True

        # 2) 客户端提供更旧的数据（updated_at=100），但强制 use_client，应覆盖服务端
        req2 = {
            "user_id": "u_force_v1",
            "force_decision": "use_client",
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 2, "updated_at": 100}], "time_entries": []},
                }
            },
        }
        resp2 = client.post("/sync", json=req2)
        assert resp2.status_code == 200
        body2 = resp2.json()
        assert body2["success"] is True
        # v1: use_client 时不返回 tools_data
        assert body2.get("tools_data") is None

        # 3) 空客户端来同步：应返回刚刚覆盖后的 id=2
        req3 = {
            "user_id": "u_force_v1",
            "tools_data": {},
        }
        resp3 = client.post("/sync", json=req3)
        assert resp3.status_code == 200
        body3 = resp3.json()
        assert body3["success"] is True
        assert body3["tools_data"]["work_log"]["data"]["tasks"][0]["id"] == 2
