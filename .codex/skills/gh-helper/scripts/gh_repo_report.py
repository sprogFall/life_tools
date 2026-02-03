#!/usr/bin/env python3
"""
生成 GitHub/本地仓库的“剖析报告”（Markdown）。

特点：
  - 支持输入：本地路径 / https URL / SSH URL / owner/repo
  - 可选调用 GitHub API 获取 stars/forks/license 等元信息（建议设置 GITHUB_TOKEN）
  - 只依赖 Python 标准库 + git 命令
"""

from __future__ import annotations

import argparse
import dataclasses
import json
import os
import re
import subprocess
import sys
import tomllib
import urllib.parse
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Iterable


API_BASE = "https://api.github.com"
API_VERSION = "2022-11-28"


class RepoError(RuntimeError):
    pass


def _stderr(message: str) -> None:
    print(message, file=sys.stderr)


def _run(cmd: list[str], *, cwd: Path | None = None) -> str:
    try:
        p = subprocess.run(
            cmd,
            cwd=str(cwd) if cwd else None,
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        return p.stdout.strip()
    except subprocess.CalledProcessError as e:
        raise RepoError(f"命令执行失败: {' '.join(cmd)}\n{e.stderr.strip()}") from e


def _try_run(cmd: list[str], *, cwd: Path | None = None) -> str | None:
    try:
        return _run(cmd, cwd=cwd)
    except RepoError:
        return None


def _http_get_json(url: str, token: str | None) -> dict[str, Any]:
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": API_VERSION,
        "User-Agent": "gh-helper/gh_repo_report.py",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode("utf-8", errors="replace")
            return json.loads(raw)
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        raise RepoError(f"GitHub API 请求失败: HTTP {e.code}\n{raw}") from e
    except urllib.error.URLError as e:
        raise RepoError(f"GitHub API 连接失败: {e}") from e
    except json.JSONDecodeError as e:
        raise RepoError(f"GitHub API 返回非 JSON: {e}") from e


def _slugify(text: str) -> str:
    text = re.sub(r"[^A-Za-z0-9._-]+", "_", text.strip())
    return text.strip("_") or "repo"


def _parse_github_slug(value: str) -> tuple[str, str] | None:
    value = value.strip()

    # owner/repo
    if re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", value):
        owner, repo = value.split("/", 1)
        return owner, repo

    # git@github.com:owner/repo(.git)
    m = re.fullmatch(r"git@github\.com:([^/]+)/([^/]+?)(?:\.git)?", value)
    if m:
        return m.group(1), m.group(2)

    # https://github.com/owner/repo(.git)
    if value.startswith("https://github.com/") or value.startswith("http://github.com/"):
        parsed = urllib.parse.urlparse(value)
        parts = [p for p in parsed.path.split("/") if p]
        if len(parts) >= 2:
            owner = parts[0]
            repo = parts[1]
            repo = repo[:-4] if repo.endswith(".git") else repo
            return owner, repo

    return None


def _looks_like_url(value: str) -> bool:
    return value.startswith("https://") or value.startswith("http://") or value.startswith("git@")


def _ensure_repo_dir(repo_dir: Path) -> None:
    if not repo_dir.exists():
        raise RepoError(f"仓库路径不存在: {repo_dir}")
    ok = _try_run(["git", "-C", str(repo_dir), "rev-parse", "--is-inside-work-tree"])
    if ok != "true":
        raise RepoError(f"不是 git 仓库: {repo_dir}")


def _clone_repo(url: str, dest: Path, ref: str | None) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists():
        _ensure_repo_dir(dest)
        _run(["git", "-C", str(dest), "fetch", "--all", "--tags", "--prune"])
    else:
        _run(["git", "clone", "--depth", "1", url, str(dest)])

    if ref:
        # 先尝试直接 checkout；失败则尝试 fetch 该 ref 再 checkout
        if _try_run(["git", "-C", str(dest), "checkout", ref]) is None:
            _run(["git", "-C", str(dest), "fetch", "--depth", "1", "origin", ref])
            _run(["git", "-C", str(dest), "checkout", ref])


def _iter_git_files(repo_dir: Path) -> Iterable[str]:
    p = subprocess.Popen(
        ["git", "-C", str(repo_dir), "ls-files"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    assert p.stdout is not None
    for line in p.stdout:
        yield line.rstrip("\n")
    _, err = p.communicate()
    if p.returncode != 0:
        raise RepoError(f"git ls-files 失败: {err.strip()}")


def _read_text(path: Path, max_bytes: int = 512 * 1024) -> str:
    data = path.read_bytes()[:max_bytes]
    return data.decode("utf-8", errors="replace")


def _detect_key_files(repo_root: Path) -> dict[str, list[str]]:
    groups: dict[str, list[str]] = defaultdict(list)

    def add(group: str, rel: str) -> None:
        p = repo_root / rel
        if p.is_file():
            groups[group].append(rel)

    # 文档/规范
    for name in [
        "README.md",
        "README.rst",
        "README.txt",
        "LICENSE",
        "LICENSE.md",
        "LICENSE.txt",
        "COPYING",
        "SECURITY.md",
        "CONTRIBUTING.md",
        "CODE_OF_CONDUCT.md",
        "CHANGELOG.md",
    ]:
        add("docs", name)

    # 配置/构建
    for name in [
        "package.json",
        "pnpm-lock.yaml",
        "yarn.lock",
        "package-lock.json",
        "pyproject.toml",
        "requirements.txt",
        "Pipfile",
        "setup.py",
        "Cargo.toml",
        "go.mod",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
        "gradlew",
        "Makefile",
        "CMakeLists.txt",
        "pubspec.yaml",
        "pubspec.lock",
        "Gemfile",
        "composer.json",
    ]:
        add("build", name)

    # 容器/部署
    for name in [
        "Dockerfile",
        "docker-compose.yml",
        "docker-compose.yaml",
        ".dockerignore",
    ]:
        add("deploy", name)

    # CI
    if (repo_root / ".github" / "workflows").is_dir():
        for p in sorted((repo_root / ".github" / "workflows").glob("*.yml")) + sorted(
            (repo_root / ".github" / "workflows").glob("*.yaml")
        ):
            groups["ci"].append(str(p.relative_to(repo_root)))
    for name in [".gitlab-ci.yml", ".circleci/config.yml", "azure-pipelines.yml"]:
        add("ci", name)

    return dict(groups)


def _count_top_dirs(files: Iterable[str]) -> Counter[str]:
    c: Counter[str] = Counter()
    for f in files:
        first = f.split("/", 1)[0]
        c[first] += 1
    return c


def _count_extensions(files: Iterable[str]) -> Counter[str]:
    c: Counter[str] = Counter()
    for f in files:
        name = f.rsplit("/", 1)[-1]
        if "." not in name:
            c["(no-ext)"] += 1
            continue
        ext = name.rsplit(".", 1)[-1].lower()
        c[f".{ext}"] += 1
    return c


def _parse_package_json(path: Path) -> dict[str, Any]:
    try:
        data = json.loads(_read_text(path))
    except json.JSONDecodeError:
        return {}
    out: dict[str, Any] = {}
    out["name"] = data.get("name")
    out["private"] = data.get("private")
    out["type"] = data.get("type")
    out["scripts"] = sorted((data.get("scripts") or {}).keys())
    out["dependencies"] = sorted((data.get("dependencies") or {}).keys())
    out["devDependencies"] = sorted((data.get("devDependencies") or {}).keys())
    out["peerDependencies"] = sorted((data.get("peerDependencies") or {}).keys())
    return out


def _parse_requirements_txt(path: Path) -> list[str]:
    deps: list[str] = []
    for line in _read_text(path).splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("-r ") or line.startswith("--requirement"):
            continue
        if line.startswith("-e ") or line.startswith("--editable"):
            continue
        deps.append(line)
    return deps


def _parse_pyproject_toml(path: Path) -> dict[str, Any]:
    try:
        data = tomllib.loads(_read_text(path))
    except Exception:
        return {}

    out: dict[str, Any] = {}
    project = data.get("project") or {}
    if isinstance(project, dict):
        out["name"] = project.get("name")
        out["dependencies"] = project.get("dependencies") or []
        out["optional-dependencies"] = list((project.get("optional-dependencies") or {}).keys())

    tools = data.get("tool") or {}
    if isinstance(tools, dict):
        out["tooling"] = sorted(tools.keys())
    return out


def _parse_cargo_toml(path: Path) -> dict[str, Any]:
    try:
        data = tomllib.loads(_read_text(path))
    except Exception:
        return {}
    pkg = data.get("package") or {}
    out: dict[str, Any] = {}
    if isinstance(pkg, dict):
        out["name"] = pkg.get("name")
        out["edition"] = pkg.get("edition")
    for section in ["dependencies", "dev-dependencies", "build-dependencies"]:
        deps = data.get(section) or {}
        if isinstance(deps, dict):
            out[section] = sorted(deps.keys())
    return out


def _parse_go_mod(path: Path) -> dict[str, Any]:
    module_name: str | None = None
    requires: list[str] = []
    in_block = False
    for line in _read_text(path).splitlines():
        line = line.strip()
        if not line or line.startswith("//"):
            continue
        if line.startswith("module "):
            module_name = line.split(None, 1)[1].strip()
            continue
        if line.startswith("require ("):
            in_block = True
            continue
        if in_block and line == ")":
            in_block = False
            continue
        if line.startswith("require "):
            # require foo v1.2.3
            parts = line.split()
            if len(parts) >= 2:
                requires.append(parts[1])
            continue
        if in_block:
            parts = line.split()
            if parts:
                requires.append(parts[0])
    return {"module": module_name, "require": sorted(set(requires))}


def _parse_pubspec_yaml_deps(path: Path) -> dict[str, list[str]]:
    text = _read_text(path)
    lines = text.splitlines()

    def parse_section(section: str) -> list[str]:
        pkgs: list[str] = []
        in_section = False
        section_indent = 0
        for raw in lines:
            if not raw.strip() or raw.lstrip().startswith("#"):
                continue
            indent = len(raw) - len(raw.lstrip(" "))
            if not in_section:
                if indent == 0 and raw.strip() == f"{section}:":
                    in_section = True
                    section_indent = indent
                continue
            # 退出条件：遇到新的顶级 key
            if indent <= section_indent and re.match(r"^[A-Za-z0-9_-]+:", raw.strip()):
                break
            # 只采集“紧贴 section 的第一层 key”（通常缩进 +2）
            if indent == section_indent + 2:
                stripped = raw.strip()
                if ":" in stripped:
                    key = stripped.split(":", 1)[0].strip()
                    if re.fullmatch(r"[A-Za-z0-9_-]+", key):
                        pkgs.append(key)
        return pkgs

    return {
        "dependencies": parse_section("dependencies"),
        "dev_dependencies": parse_section("dev_dependencies"),
    }


def _guess_stack(key_files: dict[str, list[str]]) -> list[str]:
    build = set(key_files.get("build", []))
    stacks: list[str] = []
    if "pubspec.yaml" in build:
        stacks.append("Flutter/Dart")
    if "package.json" in build:
        stacks.append("Node.js（npm/pnpm/yarn）")
    if "pyproject.toml" in build or "requirements.txt" in build:
        stacks.append("Python")
    if "Cargo.toml" in build:
        stacks.append("Rust")
    if "go.mod" in build:
        stacks.append("Go")
    if "pom.xml" in build or "build.gradle" in build or "build.gradle.kts" in build:
        stacks.append("Java/Kotlin（Maven/Gradle）")
    if "CMakeLists.txt" in build:
        stacks.append("C/C++（CMake）")
    if "Gemfile" in build:
        stacks.append("Ruby（Bundler）")
    if "composer.json" in build:
        stacks.append("PHP（Composer）")
    return stacks


def _short(text: str, max_len: int = 140) -> str:
    text = (text or "").strip().replace("\n", " ")
    if len(text) <= max_len:
        return text
    return text[: max_len - 1] + "…"


def _format_counter(counter: Counter[str], *, top: int = 10) -> list[str]:
    return [f"{k}({v})" for k, v in counter.most_common(top)]


@dataclasses.dataclass
class RepoContext:
    input_value: str
    repo_dir: Path
    github_slug: tuple[str, str] | None
    remote_url: str | None


def _resolve_repo(input_value: str, cache_dir: Path, ref: str | None) -> RepoContext:
    input_value = input_value.strip()
    p = Path(input_value)
    if p.exists():
        repo_dir = p.resolve()
        _ensure_repo_dir(repo_dir)
        remote_url = _try_run(["git", "-C", str(repo_dir), "remote", "get-url", "origin"])
        github_slug = _parse_github_slug(remote_url) if remote_url else None
        return RepoContext(input_value=input_value, repo_dir=repo_dir, github_slug=github_slug, remote_url=remote_url)

    github_slug = _parse_github_slug(input_value)
    if github_slug:
        owner, repo = github_slug
        url = f"https://github.com/{owner}/{repo}.git"
    elif _looks_like_url(input_value):
        url = input_value
    else:
        raise RepoError("无法识别 repo 输入：请提供本地路径 / GitHub URL / owner/repo")

    dest_name = _slugify(input_value if not github_slug else f"{github_slug[0]}__{github_slug[1]}")
    dest = cache_dir / dest_name
    _clone_repo(url, dest, ref)
    remote_url = _try_run(["git", "-C", str(dest), "remote", "get-url", "origin"])
    github_slug = _parse_github_slug(remote_url or input_value)
    return RepoContext(input_value=input_value, repo_dir=dest, github_slug=github_slug, remote_url=remote_url)


def _git_meta(repo_dir: Path) -> dict[str, str]:
    commit = _run(["git", "-C", str(repo_dir), "rev-parse", "HEAD"])
    short_commit = _run(["git", "-C", str(repo_dir), "rev-parse", "--short", "HEAD"])
    branch = _try_run(["git", "-C", str(repo_dir), "rev-parse", "--abbrev-ref", "HEAD"]) or ""
    last_date = _try_run(["git", "-C", str(repo_dir), "log", "-1", "--format=%cI"]) or ""
    subject = _try_run(["git", "-C", str(repo_dir), "log", "-1", "--format=%s"]) or ""
    return {
        "commit": commit,
        "short_commit": short_commit,
        "branch": branch,
        "last_commit_date": last_date,
        "last_commit_subject": subject,
    }


def _github_meta(slug: tuple[str, str], token: str | None) -> dict[str, Any]:
    owner, repo = slug
    repo_json = _http_get_json(f"{API_BASE}/repos/{owner}/{repo}", token)
    languages_json = _http_get_json(f"{API_BASE}/repos/{owner}/{repo}/languages", token)
    return {"repo": repo_json, "languages": languages_json}


def _md_list(items: list[str]) -> str:
    if not items:
        return "（无）"
    return ", ".join(f"`{x}`" for x in items)


def _write_report(
    *,
    out_path: Path,
    ctx: RepoContext,
    meta: dict[str, str],
    key_files: dict[str, list[str]],
    stack: list[str],
    top_dirs: Counter[str],
    exts: Counter[str],
    dep_summary: dict[str, Any],
    gh_meta: dict[str, Any] | None,
) -> None:
    repo_title = "/".join(ctx.github_slug) if ctx.github_slug else ctx.input_value
    lines: list[str] = []

    lines.append(f"# 仓库剖析报告：{repo_title}")
    lines.append("")

    lines.append("## 基本信息")
    lines.append(f"- 本地路径：`{ctx.repo_dir}`")
    if ctx.remote_url:
        lines.append(f"- 远程地址：`{ctx.remote_url}`")
    lines.append(f"- 分支/状态：`{meta.get('branch')}`")
    lines.append(f"- 当前提交：`{meta.get('short_commit')}`（{meta.get('commit')}）")
    if meta.get("last_commit_date"):
        lines.append(f"- 最近提交：`{meta.get('last_commit_date')}` — {_short(meta.get('last_commit_subject', ''))}")

    if gh_meta:
        repo_json = gh_meta.get("repo") or {}
        license_obj = repo_json.get("license") or {}
        license_spdx = license_obj.get("spdx_id") or ""
        lines.append(f"- Stars/Forks：★{repo_json.get('stargazers_count', 0)} / {repo_json.get('forks_count', 0)}")
        if license_spdx:
            lines.append(f"- License：`{license_spdx}`")
        desc = repo_json.get("description") or ""
        if desc:
            lines.append(f"- 描述：{_short(desc, 220)}")
    lines.append("")

    lines.append("## TL;DR（快速结论）")
    lines.append(f"- 技术栈猜测：{('、'.join(stack) if stack else '（不确定）')}")
    lines.append(f"- 关键文件：docs={len(key_files.get('docs', []))} / build={len(key_files.get('build', []))} / ci={len(key_files.get('ci', []))}")
    lines.append(f"- 目录概况（Top 8）：{', '.join(_format_counter(top_dirs, top=8)) if top_dirs else '（无）'}")
    lines.append(f"- 文件扩展名（Top 10）：{', '.join(_format_counter(exts, top=10)) if exts else '（无）'}")
    lines.append("")

    lines.append("## 项目结构")
    if key_files.get("docs"):
        lines.append(f"- 文档/规范：{_md_list(key_files['docs'])}")
    if key_files.get("build"):
        lines.append(f"- 构建/依赖：{_md_list(key_files['build'])}")
    if key_files.get("deploy"):
        lines.append(f"- 部署/容器：{_md_list(key_files['deploy'])}")
    if key_files.get("ci"):
        lines.append(f"- CI/CD：{_md_list(key_files['ci'])}")
    lines.append("")

    lines.append("## 依赖概览（从关键清单粗提）")
    if not dep_summary:
        lines.append("（未识别到常见依赖清单文件）")
    else:
        for k, v in dep_summary.items():
            if isinstance(v, dict):
                lines.append(f"### {k}")
                for kk, vv in v.items():
                    if isinstance(vv, list):
                        lines.append(f"- {kk}：{', '.join(vv[:20])}{' …' if len(vv) > 20 else ''}")
                    else:
                        lines.append(f"- {kk}：{vv}")
                lines.append("")
            elif isinstance(v, list):
                lines.append(f"- {k}：{', '.join(v[:20])}{' …' if len(v) > 20 else ''}")
            else:
                lines.append(f"- {k}：{v}")
        if lines and lines[-1] != "":
            lines.append("")

    if gh_meta:
        langs = gh_meta.get("languages") or {}
        if isinstance(langs, dict) and langs:
            top_langs = sorted(langs.items(), key=lambda x: x[1], reverse=True)[:10]
            lines.append("## GitHub 语言统计（API）")
            lines.append("- " + ", ".join(f"{k}({v})" for k, v in top_langs))
            lines.append("")

    lines.append("## 下一步建议（给进一步深挖用）")
    lines.append("- 先跑一遍“最小闭环”：能否本地 build + test（优先看 CI 配置与 README）。")
    lines.append("- 结合你的目标（迁移/复用/对比/学习），锁定 1-3 个核心用例与入口模块，再做定向阅读。")
    lines.append("- 需要找参考实现：用 `gh_search.py` 先在 GitHub 上找同类仓库/关键字，再对 2-3 个代表仓库做快速剖析对比。")
    lines.append("")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(lines), encoding="utf-8")


def _collect_dep_summary(repo_root: Path, key_files: dict[str, list[str]]) -> dict[str, Any]:
    build_files = set(key_files.get("build", []))
    out: dict[str, Any] = {}

    if "package.json" in build_files:
        out["Node(package.json)"] = _parse_package_json(repo_root / "package.json")

    if "requirements.txt" in build_files:
        out["Python(requirements.txt)"] = _parse_requirements_txt(repo_root / "requirements.txt")

    if "pyproject.toml" in build_files:
        out["Python(pyproject.toml)"] = _parse_pyproject_toml(repo_root / "pyproject.toml")

    if "Cargo.toml" in build_files:
        out["Rust(Cargo.toml)"] = _parse_cargo_toml(repo_root / "Cargo.toml")

    if "go.mod" in build_files:
        out["Go(go.mod)"] = _parse_go_mod(repo_root / "go.mod")

    if "pubspec.yaml" in build_files:
        out["Flutter(pubspec.yaml)"] = _parse_pubspec_yaml_deps(repo_root / "pubspec.yaml")

    if "composer.json" in build_files:
        try:
            out["PHP(composer.json)"] = json.loads(_read_text(repo_root / "composer.json"))
        except Exception:
            pass

    return out


def _parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(
        prog="gh_repo_report.py",
        description="生成 GitHub/本地仓库剖析报告（Markdown）。",
        formatter_class=argparse.RawTextHelpFormatter,
    )
    p.add_argument("--repo", "-r", required=True, help="本地路径 / GitHub URL / owner/repo")
    p.add_argument("--ref", help="可选：checkout 到指定分支/Tag/Commit（仅对 clone 的仓库生效）。")
    p.add_argument("--cache-dir", default=".gh-helper-cache", help="clone 缓存目录（默认 ./.gh-helper-cache）。")
    p.add_argument("--out", default=".gh-helper-out/report.md", help="输出报告文件路径（默认 ./.gh-helper-out/report.md）。")
    p.add_argument("--api", action="store_true", help="启用 GitHub API 拉取仓库元信息（推荐）。")
    p.add_argument("--token", default=os.environ.get("GITHUB_TOKEN"), help="GitHub Token（默认读取 GITHUB_TOKEN）。")
    return p.parse_args(argv)


def main(argv: list[str]) -> int:
    args = _parse_args(argv)
    try:
        cache_dir = Path(args.cache_dir).resolve()
        ctx = _resolve_repo(args.repo, cache_dir, args.ref)
        repo_root = ctx.repo_dir
        meta = _git_meta(repo_root)

        key_files = _detect_key_files(repo_root)
        stack = _guess_stack(key_files)

        # 注意：_iter_git_files 只能遍历一次，所以这里分两轮取：先缓存到 list（可控大小）
        files = list(_iter_git_files(repo_root))
        top_dirs = _count_top_dirs(files)
        exts = _count_extensions(files)

        dep_summary = _collect_dep_summary(repo_root, key_files)

        gh_meta: dict[str, Any] | None = None
        if args.api and ctx.github_slug:
            gh_meta = _github_meta(ctx.github_slug, args.token)

        out_path = Path(args.out).resolve()
        _write_report(
            out_path=out_path,
            ctx=ctx,
            meta=meta,
            key_files=key_files,
            stack=stack,
            top_dirs=top_dirs,
            exts=exts,
            dep_summary=dep_summary,
            gh_meta=gh_meta,
        )
        print(f"[OK] 已生成报告: {out_path}")
        return 0
    except RepoError as e:
        _stderr(str(e))
        return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
