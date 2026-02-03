import os
import sys


def pytest_configure() -> None:
    # 让 `backend/sync_server` 下的包可被直接 import（如 `sync_server.*`）
    repo_root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    if repo_root not in sys.path:
        sys.path.insert(0, repo_root)

