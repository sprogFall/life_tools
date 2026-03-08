import tempfile

from fastapi.testclient import TestClient

from sync_server.main import create_app


def _seed_work_log_snapshot(client: TestClient, *, user_id: str) -> None:
    response = client.post(
        "/sync/v2",
        json={
            "protocol_version": 2,
            "user_id": user_id,
            "client_time": 1730000000000,
            "client_state": {
                "last_server_revision": None,
                "client_is_empty": False,
            },
            "tools_data": {
                "work_log": {
                    "version": 1,
                    "data": {
                        "tasks": [
                            {
                                "id": 1,
                                "title": "整理周报",
                                "description": "补齐项目进度与风险",
                                "status": 1,
                                "estimated_minutes": 90,
                                "is_pinned": 1,
                                "sort_index": 0,
                                "created_at": 1730000000000,
                                "updated_at": 1730000000100,
                            }
                        ],
                        "time_entries": [
                            {
                                "id": 10,
                                "task_id": 1,
                                "work_date": 1730000000000,
                                "minutes": 60,
                                "content": "产出初稿",
                                "created_at": 1730000000000,
                                "updated_at": 1730000000200,
                            }
                        ],
                        "task_tags": [],
                        "operation_logs": [],
                    },
                }
            },
        },
    )
    assert response.status_code == 200
    assert response.json()["decision"] == "use_client"


def test_dashboard_users_list_and_detail() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        _seed_work_log_snapshot(client, user_id="u1")

        create_resp = client.post(
            "/dashboard/users",
            json={
                "user_id": "u2",
                "display_name": "备用同步账号",
                "notes": "仅用于家庭库存导入",
                "is_enabled": False,
            },
        )
        assert create_resp.status_code == 200

        list_resp = client.get("/dashboard/users")
        assert list_resp.status_code == 200
        body = list_resp.json()
        assert body["success"] is True
        assert len(body["users"]) == 2

        users = {item["user_id"]: item for item in body["users"]}
        assert users["u1"]["snapshot"]["has_snapshot"] is True
        assert users["u1"]["snapshot"]["tool_count"] == 1
        assert users["u1"]["snapshot"]["tool_ids"] == ["work_log"]
        assert users["u1"]["snapshot"]["tool_summaries"][0]["section_counts"]["tasks"] == 1
        assert users["u1"]["snapshot"]["tool_summaries"][0]["section_counts"]["time_entries"] == 1

        assert users["u2"]["display_name"] == "备用同步账号"
        assert users["u2"]["is_enabled"] is False
        assert users["u2"]["snapshot"]["has_snapshot"] is False

        detail_resp = client.get("/dashboard/users/u1")
        assert detail_resp.status_code == 200
        detail = detail_resp.json()
        assert detail["success"] is True
        assert detail["user"]["user_id"] == "u1"
        assert detail["snapshot"]["server_revision"] == 1
        assert detail["snapshot"]["tools_data"]["work_log"]["data"]["tasks"][0]["title"] == "整理周报"
        assert detail["recent_records"][0]["decision"] == "use_client"


def test_dashboard_can_update_user_profile() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        create_resp = client.post(
            "/dashboard/users",
            json={
                "user_id": "sync_admin",
                "display_name": "原始名称",
                "notes": "初始备注",
            },
        )
        assert create_resp.status_code == 200

        update_resp = client.patch(
            "/dashboard/users/sync_admin",
            json={
                "display_name": "主同步用户",
                "notes": "用于工作记录与囤货助手",
                "is_enabled": True,
            },
        )
        assert update_resp.status_code == 200
        body = update_resp.json()
        assert body["success"] is True
        assert body["user"]["display_name"] == "主同步用户"
        assert body["user"]["notes"] == "用于工作记录与囤货助手"
        assert body["user"]["is_enabled"] is True


def test_dashboard_tool_update_creates_new_revision_and_record() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        _seed_work_log_snapshot(client, user_id="u1")

        get_tool_resp = client.get("/dashboard/users/u1/tools/work_log")
        assert get_tool_resp.status_code == 200
        tool_payload = get_tool_resp.json()["tool"]
        tool_payload["data"]["tasks"].append(
            {
                "id": 2,
                "title": "回访异常数据",
                "description": "核对同步失败原因",
                "status": 0,
                "estimated_minutes": 45,
                "is_pinned": 0,
                "sort_index": 1,
                "created_at": 1730000000300,
                "updated_at": 1730000000400,
            }
        )

        update_resp = client.put(
            "/dashboard/users/u1/tools/work_log",
            json={
                "version": tool_payload["version"],
                "data": tool_payload["data"],
                "message": "dashboard 批量补录工作任务",
            },
        )
        assert update_resp.status_code == 200
        body = update_resp.json()
        assert body["success"] is True
        assert body["snapshot"]["server_revision"] == 2
        assert body["tool"]["summary"]["section_counts"]["tasks"] == 2

        detail_resp = client.get("/dashboard/users/u1/tools/work_log")
        assert detail_resp.status_code == 200
        detail = detail_resp.json()
        tasks = detail["tool"]["data"]["tasks"]
        assert len(tasks) == 2
        assert tasks[-1]["title"] == "回访异常数据"

        records_resp = client.get("/sync/records", params={"user_id": "u1", "limit": 10})
        assert records_resp.status_code == 200
        decisions = [item["decision"] for item in records_resp.json()["records"]]
        assert "dashboard_update" in decisions


def test_dashboard_snapshot_update_allows_json_management() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        _seed_work_log_snapshot(client, user_id="u1")

        detail_resp = client.get("/dashboard/users/u1")
        assert detail_resp.status_code == 200
        detail = detail_resp.json()

        tools_data = detail["snapshot"]["tools_data"]
        tools_data["work_log"]["data"]["tasks"][0]["title"] = "JSON 方式修正标题"
        tools_data["work_log"]["data"]["tasks"].append(
            {
                "id": 2,
                "title": "JSON 新增任务",
                "description": "直接修改快照 JSON",
                "status": 0,
                "estimated_minutes": 30,
                "is_pinned": 0,
                "sort_index": 1,
                "created_at": 1730000000500,
                "updated_at": 1730000000600,
            }
        )

        update_resp = client.put(
            "/dashboard/users/u1/snapshot",
            json={
                "tools_data": tools_data,
                "message": "dashboard JSON 管理保存",
            },
        )
        assert update_resp.status_code == 200
        body = update_resp.json()
        assert body["success"] is True
        assert body["snapshot"]["server_revision"] == 2
        assert body["snapshot"]["tools_data"]["work_log"]["data"]["tasks"][0]["title"] == "JSON 方式修正标题"
        assert len(body["snapshot"]["tools_data"]["work_log"]["data"]["tasks"]) == 2

        records_resp = client.get("/sync/records", params={"user_id": "u1", "limit": 10})
        assert records_resp.status_code == 200
        assert records_resp.json()["records"][0]["decision"] == "dashboard_update"



def test_dashboard_tool_update_rejects_unknown_time_entry_task_id() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        _seed_work_log_snapshot(client, user_id="u1")

        get_tool_resp = client.get("/dashboard/users/u1/tools/work_log")
        assert get_tool_resp.status_code == 200
        tool_payload = get_tool_resp.json()["tool"]
        tool_payload["data"]["time_entries"][0]["task_id"] = 999

        update_resp = client.put(
            "/dashboard/users/u1/tools/work_log",
            json={
                "version": tool_payload["version"],
                "data": tool_payload["data"],
                "message": "dashboard 非法工时归属测试",
            },
        )
        assert update_resp.status_code == 400
        assert "task_id=999" in update_resp.json()["message"]

        detail_resp = client.get("/dashboard/users/u1/tools/work_log")
        assert detail_resp.status_code == 200
        detail = detail_resp.json()
        assert detail["tool"]["data"]["time_entries"][0]["task_id"] == 1


def test_dashboard_tool_update_reassign_time_entry_writes_operation_log() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        _seed_work_log_snapshot(client, user_id="u1")

        get_tool_resp = client.get("/dashboard/users/u1/tools/work_log")
        assert get_tool_resp.status_code == 200
        tool_payload = get_tool_resp.json()["tool"]
        tool_payload["data"]["tasks"].append(
            {
                "id": 2,
                "title": "回访异常数据",
                "description": "核对同步失败原因",
                "status": 0,
                "estimated_minutes": 45,
                "is_pinned": 0,
                "sort_index": 1,
                "created_at": 1730000000300,
                "updated_at": 1730000000400,
            }
        )
        tool_payload["data"]["time_entries"][0]["task_id"] = 2
        tool_payload["data"]["time_entries"][0]["updated_at"] = 1730000000800

        update_resp = client.put(
            "/dashboard/users/u1/tools/work_log",
            json={
                "version": tool_payload["version"],
                "data": tool_payload["data"],
                "message": "dashboard 拖拽改工时归属",
            },
        )
        assert update_resp.status_code == 200
        body = update_resp.json()
        logs = body["tool"]["data"]["operation_logs"]
        assert len(logs) == 1
        log = logs[0]
        assert log["operation_type"] == 4
        assert log["target_type"] == 1
        assert log["target_id"] == 10
        assert log["target_title"] == "产出初稿"
        assert "整理周报" in log["summary"]
        assert "回访异常数据" in log["summary"]
        assert log["before_snapshot"]["task_id"] == 1
        assert log["after_snapshot"]["task_id"] == 2



def test_dashboard_snapshot_update_reassign_time_entry_writes_operation_log() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        app = create_app(db_path=f"{tmp}/sync.db")
        client = TestClient(app)

        _seed_work_log_snapshot(client, user_id="u1")

        detail_resp = client.get("/dashboard/users/u1")
        assert detail_resp.status_code == 200
        detail = detail_resp.json()

        tools_data = detail["snapshot"]["tools_data"]
        tools_data["work_log"]["data"]["tasks"].append(
            {
                "id": 2,
                "title": "JSON 新任务",
                "description": "从 JSON 管理页迁移",
                "status": 0,
                "estimated_minutes": 30,
                "is_pinned": 0,
                "sort_index": 1,
                "created_at": 1730000000500,
                "updated_at": 1730000000600,
            }
        )
        tools_data["work_log"]["data"]["time_entries"][0]["task_id"] = 2

        update_resp = client.put(
            "/dashboard/users/u1/snapshot",
            json={
                "tools_data": tools_data,
                "message": "dashboard JSON 拖拽改工时归属",
            },
        )
        assert update_resp.status_code == 200
        body = update_resp.json()
        logs = body["snapshot"]["tools_data"]["work_log"]["data"]["operation_logs"]
        assert len(logs) == 1
        assert logs[0]["before_snapshot"]["task_id"] == 1
        assert logs[0]["after_snapshot"]["task_id"] == 2
