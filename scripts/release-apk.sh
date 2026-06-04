#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERSION_INPUT=""
REMOTE_NAME="origin"
BRANCH_NAME=""
SUMMARY=""
MAX_POLLS=""
SKIP_PRE_PUSH="false"
DRY_RUN="false"
WORKFLOW_NAME="Build Android APK"
REPO_ROOT=""
RELEASE_TAG=""
APP_VERSION=""
VERSION_FILE="VERSION"
VERSION_FILE_NEEDS_UPDATE="false"

log() {
  echo "[release-apk] $*"
}

die() {
  echo "[release-apk] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
用法:
  bash scripts/release-apk.sh <版本号> [options]
  bash scripts/release-apk.sh --version <版本号> [options]

功能:
  - 一键发布正式 Android APK
  - 自动校验版本号，创建 vMAJOR.MINOR.PATCH tag
  - 自动更新 VERSION 文件，保证无业务改动时也有明确的发版提交
  - 先执行 pre-push 校验，再 commit 并 push 代码
  - push tag 触发 GitHub Action 正式打包
  - 等待并返回打包结果、Release 页面和 APK 下载地址

参数:
  <版本号>                  支持 1.2.3 或 v1.2.3，会统一为 v1.2.3

选项:
  --version <版本号>        与位置参数等价
  --summary <text>          有本地改动时使用的提交摘要（默认：发布 vX.Y.Z 正式安装包）
  --remote <name>           Git remote（默认 origin）
  --branch <name>           需要 push 的分支（默认当前分支）
  --max-polls <n>           传给 post-push 的最大轮询次数（默认不限）
  --skip-pre-push           跳过本地校验（只建议临时排障时使用）
  --dry-run                 只打印将执行的动作，不真正提交、打 tag 或 push
  -h, --help                查看帮助

示例:
  bash scripts/release-apk.sh 1.2.3
  bash scripts/release-apk.sh v1.2.3 --summary "发布 1.2.3 修复版"
  bash scripts/release-apk.sh 1.2.3 --max-polls 30

提示:
  - 正式更新只认 vMAJOR.MINOR.PATCH tag。
  - VERSION 文件会记录最近一次准备发布的正式版本号。
  - tag 一旦 push 到 GitHub，就会触发正式 Release APK 打包。
  - 客户端“关于 -> 检查更新”只会拉取正式 Release，不会拉取自测 prerelease 包。
USAGE
}

quote_command() {
  printf '%q ' "$@"
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] $(quote_command "$@")"
    return 0
  fi

  "$@"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --version)
        [[ $# -ge 2 ]] || die "--version 需要参数"
        VERSION_INPUT="$2"
        shift
        ;;
      --summary)
        [[ $# -ge 2 ]] || die "--summary 需要参数"
        SUMMARY="$2"
        shift
        ;;
      --remote)
        [[ $# -ge 2 ]] || die "--remote 需要参数"
        REMOTE_NAME="$2"
        shift
        ;;
      --branch)
        [[ $# -ge 2 ]] || die "--branch 需要参数"
        BRANCH_NAME="$2"
        shift
        ;;
      --max-polls)
        [[ $# -ge 2 ]] || die "--max-polls 需要参数"
        MAX_POLLS="$2"
        shift
        ;;
      --skip-pre-push)
        SKIP_PRE_PUSH="true"
        ;;
      --dry-run)
        DRY_RUN="true"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --*)
        die "未知参数: $1"
        ;;
      *)
        if [[ -n "$VERSION_INPUT" ]]; then
          die "只能传入一个版本号"
        fi
        VERSION_INPUT="$1"
        ;;
    esac
    shift
  done
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "缺少命令: $1"
  fi
}

resolve_repo_root() {
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$REPO_ROOT" ]] || die "当前目录不在 git 仓库内"
  cd "$REPO_ROOT"
}

normalize_version() {
  [[ -n "$VERSION_INPUT" ]] || die "请传入版本号，例如：bash scripts/release-apk.sh 1.2.3"

  RELEASE_TAG="$VERSION_INPUT"
  if [[ "$RELEASE_TAG" != v* ]]; then
    RELEASE_TAG="v${RELEASE_TAG}"
  fi

  if [[ ! "$RELEASE_TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    die "版本号格式不正确：${VERSION_INPUT}。请使用 1.2.3 或 v1.2.3"
  fi

  APP_VERSION="${RELEASE_TAG#v}"
  [[ -n "$SUMMARY" ]] || SUMMARY="发布 ${RELEASE_TAG} 正式安装包"
}

fill_defaults() {
  if [[ -z "$BRANCH_NAME" ]]; then
    BRANCH_NAME="$(git branch --show-current 2>/dev/null || true)"
  fi
  [[ -n "$BRANCH_NAME" ]] || die "无法识别当前分支，请用 --branch 指定"

  if [[ -n "$MAX_POLLS" && ! "$MAX_POLLS" =~ ^[0-9]+$ ]]; then
    die "--max-polls 仅支持非负整数"
  fi
}

ensure_tag_available() {
  if git rev-parse -q --verify "refs/tags/${RELEASE_TAG}" >/dev/null; then
    die "本地 tag 已存在：${RELEASE_TAG}"
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] 跳过远端 tag 存在性检查：${REMOTE_NAME}/${RELEASE_TAG}"
    return
  fi

  if git ls-remote --exit-code --tags "$REMOTE_NAME" "refs/tags/${RELEASE_TAG}" >/dev/null 2>&1; then
    die "远端 tag 已存在：${REMOTE_NAME}/${RELEASE_TAG}"
  fi
}

has_working_tree_changes() {
  [[ -n "$(git status --porcelain)" ]]
}

has_release_changes() {
  if [[ "$VERSION_FILE_NEEDS_UPDATE" == "true" ]]; then
    return 0
  fi

  has_working_tree_changes
}

check_version_file_update_needed() {
  local current_version=""
  if [[ -f "$VERSION_FILE" ]]; then
    current_version="$(tr -d '\r\n' < "$VERSION_FILE")"
  fi

  if [[ "$current_version" == "$APP_VERSION" ]]; then
    VERSION_FILE_NEEDS_UPDATE="false"
    log "版本文件无需更新：${VERSION_FILE}=${APP_VERSION}"
  else
    VERSION_FILE_NEEDS_UPDATE="true"
    log "版本文件需要更新：${VERSION_FILE}: ${current_version:-<空>} -> ${APP_VERSION}"
  fi
}

update_version_file() {
  if [[ "$VERSION_FILE_NEEDS_UPDATE" != "true" ]]; then
    return
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] 更新版本文件完成"
    return
  fi

  printf '%s\n' "$APP_VERSION" > "$VERSION_FILE"
  log "已更新版本文件：${VERSION_FILE}=${APP_VERSION}"
}

run_pre_push_if_needed() {
  if [[ "$SKIP_PRE_PUSH" == "true" ]]; then
    log "已跳过本地校验（--skip-pre-push）"
    return
  fi

  if has_release_changes; then
    log "检测到待发布改动，先执行发布前校验"
    run_cmd bash "${SCRIPT_DIR}/pre-push.sh"
  else
    log "工作区干净，校验当前 HEAD"
    run_cmd bash "${SCRIPT_DIR}/pre-push.sh" --change-source head --allow-no-changes
  fi
}

commit_and_push_code() {
  if has_release_changes; then
    log "提交并 push 发版提交到 ${REMOTE_NAME}/${BRANCH_NAME}"
    run_cmd bash "${SCRIPT_DIR}/exec-push.sh" \
      --stage-all \
      --push \
      --type chore \
      --scope-tag release \
      --remote "$REMOTE_NAME" \
      --branch "$BRANCH_NAME" \
      --workflow "$WORKFLOW_NAME" \
      --summary "$SUMMARY"
  else
    log "没有本地改动，push 当前分支到 ${REMOTE_NAME}/${BRANCH_NAME}"
    run_cmd git push "$REMOTE_NAME" "$BRANCH_NAME"
  fi
}

create_and_push_tag() {
  local release_sha
  release_sha="$(git rev-parse HEAD)"

  log "创建正式版本 tag：${RELEASE_TAG} -> ${release_sha}"
  run_cmd git tag -a "$RELEASE_TAG" -m "Release ${RELEASE_TAG}" "$release_sha"

  log "push tag 触发正式 APK 打包：${REMOTE_NAME}/${RELEASE_TAG}"
  run_cmd git push "$REMOTE_NAME" "$RELEASE_TAG"
}

monitor_build_result() {
  local release_sha
  release_sha="$(git rev-parse HEAD)"

  local -a args=(
    "${SCRIPT_DIR}/post-push.sh"
    --sha "$release_sha"
    --branch "$RELEASE_TAG"
    --remote "$REMOTE_NAME"
    --workflow "$WORKFLOW_NAME"
    --force-monitor
  )
  if [[ -n "$MAX_POLLS" ]]; then
    args+=(--max-polls "$MAX_POLLS")
  fi
  if [[ "$DRY_RUN" == "true" ]]; then
    args+=(--dry-run)
  fi

  log "等待 GitHub Action 打包结果"
  run_cmd bash "${args[@]}"
}

extract_repo_from_remote() {
  local remote_url="$1"
  local path

  path="$(echo "$remote_url" | sed -E \
    -e 's#^https?://github.com/##' \
    -e 's#^git@github.com:##' \
    -e 's#^ssh://git@ssh.github.com:443/##' \
    -e 's#\.git$##')"

  if [[ "$path" != */* ]]; then
    echo ""
    return
  fi

  echo "$path"
}

print_release_links() {
  local remote_url repo_path release_url download_url
  remote_url="$(git remote get-url "$REMOTE_NAME" 2>/dev/null || true)"
  repo_path="$(extract_repo_from_remote "$remote_url")"

  log "正式版本：${RELEASE_TAG}"
  if [[ -n "$repo_path" ]]; then
    release_url="https://github.com/${repo_path}/releases/tag/${RELEASE_TAG}"
    download_url="https://github.com/${repo_path}/releases/download/${RELEASE_TAG}/life_tools-release-${RELEASE_TAG}.apk"
    log "Release 页面：${release_url}"
    log "APK 直链：${download_url}"
  else
    log "提示：remote 不是标准 GitHub 地址，无法自动拼出下载链接"
  fi
}

main() {
  parse_args "$@"
  need_cmd git
  resolve_repo_root
  normalize_version
  fill_defaults

  log "准备发布正式 APK：${RELEASE_TAG}"
  log "分支：${BRANCH_NAME}"
  log "远端：${REMOTE_NAME}"

  ensure_tag_available
  check_version_file_update_needed
  update_version_file
  run_pre_push_if_needed
  commit_and_push_code
  create_and_push_tag
  monitor_build_result
  print_release_links
  log "完成"
}

main "$@"
