import tempfile

from fastapi.testclient import TestClient

from sync_server.main import create_app


def test_sync_records_list_and_detail() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 1) 触发一次 use_client（服务端保存客户端快照）
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
        assert resp1.json()["decision"] == "use_client"

        # 2) 再触发一次 use_server（空数据保护：客户端空快照拉取服务端）
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
        assert resp2.json()["decision"] == "use_server"

        # 3) 查询记录列表：应至少有 2 条（只记录发生改变的同步行为）
        list_resp = client.get("/sync/records", params={"user_id": "u1", "limit": 20})
        assert list_resp.status_code == 200
        list_body = list_resp.json()
        assert list_body["success"] is True
        assert len(list_body["records"]) >= 2

        first = list_body["records"][0]
        assert first["user_id"] == "u1"
        assert first["decision"] in ("use_client", "use_server")
        assert "diff_summary" in first

        # 4) 查询某条详情：应包含 diff
        record_id = first["id"]
        detail_resp = client.get(f"/sync/records/{record_id}", params={"user_id": "u1"})
        assert detail_resp.status_code == 200
        detail_body = detail_resp.json()
        assert detail_body["success"] is True
        assert detail_body["record"]["id"] == record_id
        assert "diff" in detail_body["record"]


def test_noop_sync_should_not_create_record() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        # 1) 首次保存
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
        assert resp1.json()["decision"] == "use_client"

        # 2) 再次同步同一份更新时间：应返回 noop
        req2 = {
            "protocol_version": 2,
            "user_id": "u1",
            "client_time": 1730000000100,
            "client_state": {"last_server_revision": 1, "client_is_empty": False},
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {"tasks": [{"id": 1, "updated_at": 100}], "time_entries": []},
                }
            },
        }
        resp2 = client.post("/sync/v2", json=req2)
        assert resp2.status_code == 200
        assert resp2.json()["decision"] == "noop"

        list_resp = client.get("/sync/records", params={"user_id": "u1", "limit": 50})
        assert list_resp.status_code == 200
        records = list_resp.json()["records"]
        # 仅有首次 use_client 的 1 条记录
        assert len(records) == 1

