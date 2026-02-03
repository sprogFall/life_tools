from __future__ import annotations

import json
import os
import sqlite3
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class UserSnapshot:
    user_id: str
    server_revision: int
    updated_at_ms: int
    tools_data: dict[str, Any]


class SqliteSnapshotStore:
    def __init__(self, *, db_path: str) -> None:
        self._db_path = db_path
        self._ensure_parent_dir()
        self._init_db()

    @property
    def db_path(self) -> str:
        return self._db_path

    def _ensure_parent_dir(self) -> None:
        parent = os.path.dirname(os.path.abspath(self._db_path))
        if parent and not os.path.exists(parent):
            os.makedirs(parent, exist_ok=True)

    def _connect(self) -> sqlite3.Connection:
        return sqlite3.connect(self._db_path, timeout=30)

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.execute(
                """
CREATE TABLE IF NOT EXISTS sync_snapshots (
  user_id TEXT PRIMARY KEY,
  server_revision INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  tools_data_json TEXT NOT NULL,
  updated_server_time_ms INTEGER NOT NULL,
  last_client_time_ms INTEGER
);
""",
            )

    def get_snapshot(self, user_id: str) -> UserSnapshot | None:
        with self._connect() as conn:
            row = conn.execute(
                """
SELECT user_id, server_revision, updated_at_ms, tools_data_json
FROM sync_snapshots
WHERE user_id = ?
""",
                (user_id,),
            ).fetchone()
            if row is None:
                return None
            tools_data = json.loads(row[3])
            return UserSnapshot(
                user_id=row[0],
                server_revision=int(row[1]),
                updated_at_ms=int(row[2]),
                tools_data=tools_data,
            )

    def save_client_snapshot(
        self,
        *,
        user_id: str,
        tools_data: dict[str, Any],
        updated_at_ms: int,
        server_time_ms: int,
        client_time_ms: int | None,
    ) -> int:
        """保存客户端全量快照，服务端 revision 自动递增并返回最新 revision。"""

        tools_data_json = json.dumps(
            tools_data,
            ensure_ascii=False,
            separators=(",", ":"),
        )

        with self._connect() as conn:
            conn.execute("BEGIN IMMEDIATE")

            row = conn.execute(
                "SELECT server_revision FROM sync_snapshots WHERE user_id = ?",
                (user_id,),
            ).fetchone()
            current_revision = int(row[0]) if row is not None else 0
            new_revision = current_revision + 1

            conn.execute(
                """
INSERT INTO sync_snapshots (
  user_id,
  server_revision,
  updated_at_ms,
  tools_data_json,
  updated_server_time_ms,
  last_client_time_ms
)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(user_id) DO UPDATE SET
  server_revision=excluded.server_revision,
  updated_at_ms=excluded.updated_at_ms,
  tools_data_json=excluded.tools_data_json,
  updated_server_time_ms=excluded.updated_server_time_ms,
  last_client_time_ms=excluded.last_client_time_ms
""",
                (
                    user_id,
                    new_revision,
                    int(updated_at_ms),
                    tools_data_json,
                    int(server_time_ms),
                    None if client_time_ms is None else int(client_time_ms),
                ),
            )
            conn.commit()

        return new_revision

