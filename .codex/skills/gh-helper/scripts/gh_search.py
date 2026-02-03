#!/usr/bin/env python3
"""
GitHub 搜索小工具（repos / code / issues）。

默认直接调用 GitHub REST Search API：
  - https://api.github.com/search/repositories
  - https://api.github.com/search/code
  - https://api.github.com/search/issues

提示：
  - 未提供 Token 时，GitHub API 速率限制更严格，且 code search 更容易被限制。
  - 可通过环境变量 GITHUB_TOKEN 或参数 --token 提供 Token。
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import textwrap
import urllib.parse
import urllib.request
from dataclasses import dataclass
from typing import Any, Iterable


API_BASE = "https://api.github.com"
API_VERSION = "2022-11-28"
DEFAULT_PER_PAGE = 10
DEFAULT_PAGES = 1


class GitHubApiError(RuntimeError):
    def __init__(self, message: str, status: int | None = None, body: str | None = None) -> None:
        super().__init__(message)
        self.status = status
        self.body = body


@dataclass(frozen=True)
class SearchRequest:
    endpoint: str
    query: str
    sort: str | None
    order: str | None
    per_page: int
    pages: int
    token: str | None


def _stderr(message: str) -> None:
    print(message, file=sys.stderr)


def _build_headers(token: str | None) -> dict[str, str]:
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": API_VERSION,
        "User-Agent": "gh-helper/gh_search.py",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    return headers


def _http_get_json(url: str, token: str | None) -> dict[str, Any]:
    req = urllib.request.Request(url, headers=_build_headers(token))
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        hint = "（可尝试设置 GITHUB_TOKEN 以提高速率限制）"
        raise GitHubApiError(f"GitHub API 请求失败: HTTP {e.code} {hint}", status=e.code, body=raw) from e
    except urllib.error.URLError as e:
        raise GitHubApiError(f"GitHub API 连接失败: {e}") from e
    except json.JSONDecodeError as e:
        raise GitHubApiError(f"GitHub API 返回非 JSON 内容: {e}") from e


def _iter_pages(req: SearchRequest) -> Iterable[dict[str, Any]]:
    per_page = max(1, min(100, req.per_page))
    pages = max(1, req.pages)
    for page in range(1, pages + 1):
        params = {"q": req.query, "per_page": str(per_page), "page": str(page)}
        if req.sort:
            params["sort"] = req.sort
        if req.order:
            params["order"] = req.order
        url = f"{API_BASE}{req.endpoint}?{urllib.parse.urlencode(params)}"
        yield _http_get_json(url, req.token)


def _wrap(text: str, width: int = 100) -> str:
    text = (text or "").strip()
    if not text:
        return ""
    return "\n".join(textwrap.wrap(text, width=width))


def _print_repos(items: list[dict[str, Any]]) -> None:
    for idx, item in enumerate(items, start=1):
        full_name = item.get("full_name", "")
        stars = item.get("stargazers_count", 0)
        forks = item.get("forks_count", 0)
        url = item.get("html_url", "")
        desc = _wrap(item.get("description") or "", width=100)
        print(f"{idx}. {full_name}  ★{stars}  fork:{forks}")
        if desc:
            print(f"   {desc}")
        if url:
            print(f"   {url}")


def _print_code(items: list[dict[str, Any]]) -> None:
    for idx, item in enumerate(items, start=1):
        repo = (item.get("repository") or {}).get("full_name", "")
        path = item.get("path", "")
        url = item.get("html_url", "")
        print(f"{idx}. {repo}:{path}")
        if url:
            print(f"   {url}")


def _print_issues(items: list[dict[str, Any]]) -> None:
    for idx, item in enumerate(items, start=1):
        title = item.get("title", "")
        state = item.get("state", "")
        url = item.get("html_url", "")
        repo_url = item.get("repository_url", "")
        repo = repo_url.rsplit("/", 2)[-2:] if repo_url else []
        repo_name = "/".join(repo) if repo else ""
        print(f"{idx}. [{state}] {title}")
        if repo_name:
            print(f"   repo: {repo_name}")
        if url:
            print(f"   {url}")


def _format_md(kind: str, items: list[dict[str, Any]]) -> str:
    lines: list[str] = []
    for idx, item in enumerate(items, start=1):
        if kind == "repos":
            name = item.get("full_name", "")
            url = item.get("html_url", "")
            stars = item.get("stargazers_count", 0)
            desc = (item.get("description") or "").strip()
            label = f"{name} (★{stars})"
            lines.append(f"{idx}. [{label}]({url})" + (f" — {desc}" if desc else ""))
        elif kind == "code":
            repo = (item.get("repository") or {}).get("full_name", "")
            path = item.get("path", "")
            url = item.get("html_url", "")
            lines.append(f"{idx}. [{repo}:{path}]({url})")
        else:  # issues
            title = (item.get("title") or "").strip()
            state = (item.get("state") or "").strip()
            url = item.get("html_url", "")
            lines.append(f"{idx}. [{state}] [{title}]({url})")
    return "\n".join(lines) + ("\n" if lines else "")


def _parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog="gh_search.py",
        description="GitHub 搜索（repos / code / issues）。",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    parser.add_argument(
        "kind",
        choices=["repos", "code", "issues"],
        help="搜索类型：repos=仓库，code=代码，issues=Issue/PR",
    )
    parser.add_argument(
        "--query",
        "-q",
        required=True,
        help="GitHub 搜索查询字符串（支持 GitHub qualifiers，如 language:Python stars:>500）。",
    )
    parser.add_argument("--sort", help="排序字段（因 endpoint 不同而不同，常见：stars、forks、updated）。")
    parser.add_argument("--order", choices=["asc", "desc"], help="排序方向。")
    parser.add_argument("--per-page", type=int, default=DEFAULT_PER_PAGE, help="每页返回数量（1-100）。")
    parser.add_argument("--pages", type=int, default=DEFAULT_PAGES, help="拉取页数（默认 1）。")
    parser.add_argument(
        "--format",
        choices=["text", "json", "md"],
        default="text",
        help="输出格式：text/json/md",
    )
    parser.add_argument(
        "--token",
        default=os.environ.get("GITHUB_TOKEN"),
        help="GitHub Token（默认读取环境变量 GITHUB_TOKEN）。",
    )
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = _parse_args(argv)
    endpoint = {
        "repos": "/search/repositories",
        "code": "/search/code",
        "issues": "/search/issues",
    }[args.kind]

    req = SearchRequest(
        endpoint=endpoint,
        query=args.query,
        sort=args.sort,
        order=args.order,
        per_page=args.per_page,
        pages=args.pages,
        token=args.token,
    )

    all_items: list[dict[str, Any]] = []
    try:
        for page_json in _iter_pages(req):
            items = page_json.get("items") or []
            if not isinstance(items, list):
                continue
            all_items.extend([x for x in items if isinstance(x, dict)])
    except GitHubApiError as e:
        _stderr(str(e))
        if e.body:
            _stderr(_wrap(e.body, width=120))
        return 2

    if args.format == "json":
        print(json.dumps(all_items, ensure_ascii=False, indent=2))
        return 0

    if args.format == "md":
        print(_format_md(args.kind, all_items), end="")
        return 0

    if args.kind == "repos":
        _print_repos(all_items)
    elif args.kind == "code":
        _print_code(all_items)
    else:
        _print_issues(all_items)

    if not all_items:
        _stderr("未找到结果（可调整 --query 或增加 pages/per-page）。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))

