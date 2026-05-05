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


def test_sync_v1_route_removed() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        resp = client.post(
            "/sync",
            json={
                "user_id": "u1",
                "tools_data": {
                    "work_log": {
                        "version": 1,
                        "data": {"tasks": [], "time_entries": []},
                    }
                },
            },
        )

        assert resp.status_code == 404


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


def test_sync_v2_new_client_without_revision_pulls_existing_app_config() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 1) 旧设备先把账号快照写到服务端，里面包含 AI 配置。
        req1 = {
            "protocol_version": 2,
            "user_id": "u_ai",
            "client_time": 1730000000000,
            "client_state": {"last_server_revision": None, "client_is_empty": False},
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 1, "updated_at": 100}], "time_entries": []},
                },
                "app_config": {
                    "version": 1,
                    "updated_at_ms": 100,
                    "data": {
                        "ai_config": {
                            "baseUrl": "https://api.server.example",
                            "apiKey": "server-key",
                            "model": "server-model",
                            "temperature": 0.7,
                            "maxOutputTokens": 1024,
                        },
                        "sync_config": None,
                        "obj_store_config": None,
                        "obj_store_secrets": None,
                        "settings": {},
                        "ai_call_history": None,
                    },
                },
            },
        }
        resp1 = client.post("/sync/v2", json=req1)
        assert resp1.status_code == 200
        assert resp1.json()["decision"] == "use_client"
        assert resp1.json()["server_revision"] == 1

        # 2) 新装客户端刚保存同步配置，本地 app_config 时间戳更新，但还没有服务端游标。
        #    这种场景必须优先拉服务端快照，不能用本地空 AI 配置覆盖服务端。
        req2 = {
            "protocol_version": 2,
            "user_id": "u_ai",
            "client_time": 1730000000100,
            "client_state": {"last_server_revision": None, "client_is_empty": False},
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 2, "updated_at": 1000}], "time_entries": []},
                },
                "app_config": {
                    "version": 1,
                    "updated_at_ms": 2000,
                    "data": {
                        "ai_config": None,
                        "sync_config": {
                            "userId": "u_ai",
                            "networkType": 0,
                            "serverUrl": "https://sync.example",
                            "serverPort": 443,
                            "customHeaders": {},
                            "allowedWifiNames": [],
                            "autoSyncOnStartup": True,
                            "lastSyncTime": None,
                            "lastServerRevision": None,
                        },
                        "obj_store_config": None,
                        "obj_store_secrets": None,
                        "settings": {},
                        "ai_call_history": None,
                    },
                },
            },
        }
        resp2 = client.post("/sync/v2", json=req2)
        assert resp2.status_code == 200
        body2 = resp2.json()
        assert body2["success"] is True
        assert body2["decision"] == "use_server"
        assert body2["server_revision"] == 1
        assert body2["tools_data"]["app_config"]["data"]["ai_config"]["apiKey"] == "server-key"


def test_sync_v2_first_sync_persists_app_config_only_snapshot() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 业务数据为空时 client_is_empty 仍为 true，但 app_config 里的 AI 配置也应能进入账号快照。
        req1 = {
            "protocol_version": 2,
            "user_id": "u_config_only",
            "client_time": 1730000000000,
            "client_state": {"last_server_revision": None, "client_is_empty": True},
            "tools_data": {
                "work_log": {"version": 1, "data": {"tasks": [], "time_entries": []}},
                "app_config": {
                    "version": 1,
                    "updated_at_ms": 100,
                    "data": {
                        "ai_config": {
                            "baseUrl": "https://api.config-only.example",
                            "apiKey": "config-only-key",
                            "model": "config-only-model",
                            "temperature": 0.7,
                            "maxOutputTokens": 1024,
                        },
                        "sync_config": None,
                        "obj_store_config": None,
                        "obj_store_secrets": None,
                        "settings": {},
                        "ai_call_history": None,
                    },
                },
            },
        }
        resp1 = client.post("/sync/v2", json=req1)
        assert resp1.status_code == 200
        body1 = resp1.json()
        assert body1["success"] is True
        assert body1["decision"] == "use_client"
        assert body1["server_revision"] == 1

        req2 = {
            "protocol_version": 2,
            "user_id": "u_config_only",
            "client_time": 1730000000100,
            "client_state": {"last_server_revision": None, "client_is_empty": True},
            "tools_data": {
                "work_log": {"version": 1, "data": {"tasks": [], "time_entries": []}},
                "app_config": {
                    "version": 1,
                    "updated_at_ms": 200,
                    "data": {
                        "ai_config": None,
                        "sync_config": None,
                        "obj_store_config": None,
                        "obj_store_secrets": None,
                        "settings": {},
                        "ai_call_history": None,
                    },
                },
            },
        }
        resp2 = client.post("/sync/v2", json=req2)
        assert resp2.status_code == 200
        body2 = resp2.json()
        assert body2["decision"] == "use_server"
        assert (
            body2["tools_data"]["app_config"]["data"]["ai_config"]["apiKey"]
            == "config-only-key"
        )


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
