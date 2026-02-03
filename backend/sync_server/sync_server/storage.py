from __future__ import annotations

from contextlib import closing
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


@dataclass(frozen=True)
class SyncRecord:
    id: int
    user_id: str
    protocol_version: int
    decision: str
    server_time_ms: int
    client_time_ms: int | None
    client_updated_at_ms: int
    server_updated_at_ms_before: int
    server_updated_at_ms_after: int
    server_revision_before: int
    server_revision_after: int
    diff: dict[str, Any]


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
        with closing(self._connect()) as conn:
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
            conn.execute(
                """
CREATE TABLE IF NOT EXISTS sync_snapshot_history (
  user_id TEXT NOT NULL,
  server_revision INTEGER NOT NULL,
  updated_at_ms INTEGER NOT NULL,
  tools_data_json TEXT NOT NULL,
  updated_server_time_ms INTEGER NOT NULL,
  last_client_time_ms INTEGER,
  PRIMARY KEY (user_id, server_revision)
);
""",
            )
            conn.execute(
                """
CREATE TABLE IF NOT EXISTS sync_records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id TEXT NOT NULL,
  protocol_version INTEGER NOT NULL,
  decision TEXT NOT NULL,
  server_time_ms INTEGER NOT NULL,
  client_time_ms INTEGER,
  client_updated_at_ms INTEGER NOT NULL,
  server_updated_at_ms_before INTEGER NOT NULL,
  server_updated_at_ms_after INTEGER NOT NULL,
  server_revision_before INTEGER NOT NULL,
  server_revision_after INTEGER NOT NULL,
  diff_json TEXT NOT NULL
);
""",
            )
            conn.execute(
                """
CREATE INDEX IF NOT EXISTS idx_sync_records_user_id_id
ON sync_records (user_id, id DESC);
""",
            )
            conn.execute(
                """
CREATE INDEX IF NOT EXISTS idx_sync_snapshot_history_user_id_rev
ON sync_snapshot_history (user_id, server_revision DESC);
""",
            )
            conn.commit()

    def get_snapshot(self, user_id: str) -> UserSnapshot | None:
        with closing(self._connect()) as conn:
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

    def get_snapshot_by_revision(self, user_id: str, revision: int) -> UserSnapshot | None:
        with closing(self._connect()) as conn:
            row = conn.execute(
                """
SELECT user_id, server_revision, updated_at_ms, tools_data_json
FROM sync_snapshot_history
WHERE user_id = ? AND server_revision = ?
""",
                (user_id, int(revision)),
            ).fetchone()
            if row is None:
                # 兼容：旧库可能没有历史表数据，尽力从当前快照回退（仅当 revision 匹配）
                current = self.get_snapshot(user_id)
                if current is not None and current.server_revision == int(revision):
                    return current
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

        with closing(self._connect()) as conn:
            conn.execute("BEGIN IMMEDIATE")

            row = conn.execute(
                "SELECT server_revision FROM sync_snapshots WHERE user_id = ?",
                (user_id,),
            ).fetchone()
            current_revision = int(row[0]) if row is not None else 0
            new_revision = current_revision + 1

            conn.execute(
                """
INSERT INTO sync_snapshot_history (
  user_id,
  server_revision,
  updated_at_ms,
  tools_data_json,
  updated_server_time_ms,
  last_client_time_ms
)
VALUES (?, ?, ?, ?, ?, ?)
ON CONFLICT(user_id, server_revision) DO UPDATE SET
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

    def add_sync_record(
        self,
        *,
        user_id: str,
        protocol_version: int,
        decision: str,
        server_time_ms: int,
        client_time_ms: int | None,
        client_updated_at_ms: int,
        server_updated_at_ms_before: int,
        server_updated_at_ms_after: int,
        server_revision_before: int,
        server_revision_after: int,
        diff: dict[str, Any],
    ) -> int:
        diff_json = json.dumps(
            diff,
            ensure_ascii=False,
            separators=(",", ":"),
        )

        with closing(self._connect()) as conn:
            cur = conn.execute(
                """
INSERT INTO sync_records (
  user_id,
  protocol_version,
  decision,
  server_time_ms,
  client_time_ms,
  client_updated_at_ms,
  server_updated_at_ms_before,
  server_updated_at_ms_after,
  server_revision_before,
  server_revision_after,
  diff_json
)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
""",
                (
                    user_id,
                    int(protocol_version),
                    decision,
                    int(server_time_ms),
                    None if client_time_ms is None else int(client_time_ms),
                    int(client_updated_at_ms),
                    int(server_updated_at_ms_before),
                    int(server_updated_at_ms_after),
                    int(server_revision_before),
                    int(server_revision_after),
                    diff_json,
                ),
            )
            conn.commit()
            return int(cur.lastrowid)

    def list_sync_records(
        self,
        *,
        user_id: str,
        limit: int,
        before_id: int | None,
    ) -> list[SyncRecord]:
        effective_limit = max(1, min(int(limit), 200))
        sql = """
SELECT
  id,
  user_id,
  protocol_version,
  decision,
  server_time_ms,
  client_time_ms,
  client_updated_at_ms,
  server_updated_at_ms_before,
  server_updated_at_ms_after,
  server_revision_before,
  server_revision_after,
  diff_json
FROM sync_records
WHERE user_id = ?
"""
        args: list[Any] = [user_id]
        if before_id is not None:
            sql += " AND id < ?"
            args.append(int(before_id))
        sql += " ORDER BY id DESC LIMIT ?"
        args.append(effective_limit)

        with closing(self._connect()) as conn:
            rows = conn.execute(sql, tuple(args)).fetchall()

        return [self._row_to_sync_record(row) for row in rows]

    def get_sync_record(self, record_id: int) -> SyncRecord | None:
        with closing(self._connect()) as conn:
            row = conn.execute(
                """
SELECT
  id,
  user_id,
  protocol_version,
  decision,
  server_time_ms,
  client_time_ms,
  client_updated_at_ms,
  server_updated_at_ms_before,
  server_updated_at_ms_after,
  server_revision_before,
  server_revision_after,
  diff_json
FROM sync_records
WHERE id = ?
""",
                (int(record_id),),
            ).fetchone()
            if row is None:
                return None
            return self._row_to_sync_record(row)

    @staticmethod
    def _row_to_sync_record(row: sqlite3.Row | tuple[Any, ...]) -> SyncRecord:
        diff = json.loads(row[11]) if row[11] else {}
        return SyncRecord(
            id=int(row[0]),
            user_id=str(row[1]),
            protocol_version=int(row[2]),
            decision=str(row[3]),
            server_time_ms=int(row[4]),
            client_time_ms=None if row[5] is None else int(row[5]),
            client_updated_at_ms=int(row[6]),
            server_updated_at_ms_before=int(row[7]),
            server_updated_at_ms_after=int(row[8]),
            server_revision_before=int(row[9]),
            server_revision_after=int(row[10]),
            diff=diff,
        )
