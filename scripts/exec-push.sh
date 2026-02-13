#!/usr/bin/env bash
set -euo pipefail

STAGE_ALL="false"
PUSH="true"
ALLOW_NO_CHANGES="false"
REMOTE_NAME="origin"
BRANCH_NAME=""
WORKFLOW_NAME="Build Android APK"

TYPE=""
SCOPE_TAG=""
SUMMARY=""
MESSAGE=""
BODY=""
BODY_FILE=""

DRY_RUN="false"

log() {
  echo "[exec-push] $*"
}

die() {
  echo "[exec-push] ERROR: $*" >&2
  exit 1
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "缺少命令: $1"
  fi
}

run_cmd() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

usage() {
  cat <<'USAGE'
用法:
  bash scripts/exec-push.sh [options]

功能:
  - 汇总本次改动
  - 按规范生成 commit message（可覆盖）
  - 执行 commit，并可选 push

选项:
  --stage-all                自动执行 git add -A
  --no-push                  仅 commit 不 push
  --push                     commit 后 push（默认）
  --allow-no-changes         无改动时直接退出 0

  --type <type>              提交 type（feat/fix/chore/docs...）
  --scope-tag <scope>        提交 scope（如 app/backend/repo）
  --summary <text>           提交摘要
  --message <full-subject>   完整提交标题（优先级最高）
  --body <text>              提交正文
  --body-file <path>         从文件读取提交正文

  --remote <name>            push remote（默认 origin）
  --branch <name>            push 分支（默认当前分支）
  --workflow <name>          写入 post-push 上下文的 workflow 名称

  --dry-run
  -h, --help

示例:
  bash scripts/exec-push.sh --stage-all --summary "重构三段式发布脚本"
  bash scripts/exec-push.sh --type fix --scope-tag app --summary "修复启动页闪烁" --push
  bash scripts/exec-push.sh --message "docs: 更新发布流程说明" --no-push
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --stage-all)
        STAGE_ALL="true"
        ;;
      --push)
        PUSH="true"
        ;;
      --no-push)
        PUSH="false"
        ;;
      --allow-no-changes)
        ALLOW_NO_CHANGES="true"
        ;;
      --type)
        [[ $# -ge 2 ]] || die "--type 需要参数"
        TYPE="$2"
        shift
        ;;
      --scope-tag)
        [[ $# -ge 2 ]] || die "--scope-tag 需要参数"
        SCOPE_TAG="$2"
        shift
        ;;
      --summary)
        [[ $# -ge 2 ]] || die "--summary 需要参数"
        SUMMARY="$2"
        shift
        ;;
      --message)
        [[ $# -ge 2 ]] || die "--message 需要参数"
        MESSAGE="$2"
        shift
        ;;
      --body)
        [[ $# -ge 2 ]] || die "--body 需要参数"
        BODY="$2"
        shift
        ;;
      --body-file)
        [[ $# -ge 2 ]] || die "--body-file 需要参数"
        BODY_FILE="$2"
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
      --workflow)
        [[ $# -ge 2 ]] || die "--workflow 需要参数"
        WORKFLOW_NAME="$2"
        shift
        ;;
      --dry-run)
        DRY_RUN="true"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "未知参数: $1"
        ;;
    esac
    shift
  done
}

resolve_repo_root() {
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$REPO_ROOT" ]] || die "当前目录不在 git 仓库内"
  cd "$REPO_ROOT"
}

is_doc_file() {
  local f="$1"
  case "$f" in
    *.md|docs/*|examples/*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_flutter_file() {
  local f="$1"
  case "$f" in
    lib/*|test/*|android/*|ios/*|macos/*|windows/*|linux/*|web/*|pubspec.yaml|pubspec.lock|analysis_options.yaml|l10n.yaml)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

detect_scope_from_files() {
  local only_docs="true"
  local only_backend_and_docs="true"
  local has_backend="false"
  local has_flutter="false"
  local f

  for f in "$@"; do
    if ! is_doc_file "$f"; then
      only_docs="false"
    fi

    case "$f" in
      backend/*)
        has_backend="true"
        ;;
      *)
        ;;
    esac

    if is_flutter_file "$f"; then
      has_flutter="true"
    fi

    case "$f" in
      backend/*|*.md|docs/*|examples/*)
        ;;
      *)
        only_backend_and_docs="false"
        ;;
    esac
  done

  if [[ "$only_docs" == "true" ]]; then
    echo "docs"
    return
  fi

  if [[ "$only_backend_and_docs" == "true" ]]; then
    echo "backend"
    return
  fi

  if [[ "$has_flutter" == "true" && "$has_backend" == "true" ]]; then
    echo "mixed"
    return
  fi

  if [[ "$has_flutter" == "true" ]]; then
    echo "flutter"
    return
  fi

  if [[ "$has_backend" == "true" ]]; then
    echo "mixed"
    return
  fi

  echo "mixed"
}

auto_summary() {
  local count="${#STAGED_FILES[@]}"
  if [[ "$count" -eq 1 ]]; then
    echo "更新 ${STAGED_FILES[0]}"
    return
  fi

  if [[ "$count" -le 3 ]]; then
    echo "更新 ${STAGED_FILES[*]}"
    return
  fi

  echo "更新 ${count} 个文件"
}

validate_summary_quality() {
  local s_lc
  s_lc="$(echo "$1" | tr '[:upper:]' '[:lower:]' | xargs)"

  case "$s_lc" in
    ""|update|misc|tmp|test|wip|临时改动|杂项)
      die "提交摘要过于模糊，请通过 --summary 提供清晰描述"
      ;;
    *)
      ;;
  esac
}

build_commit_subject() {
  if [[ -n "$MESSAGE" ]]; then
    COMMIT_SUBJECT="$MESSAGE"
    return
  fi

  if [[ -z "$SUMMARY" ]]; then
    SUMMARY="$(auto_summary)"
  fi
  validate_summary_quality "$SUMMARY"

  local type scope_tag
  type="$TYPE"
  scope_tag="$SCOPE_TAG"

  if [[ -z "$type" ]]; then
    if [[ "$DETECTED_SCOPE" == "docs" ]]; then
      type="docs"
    else
      type="chore"
    fi
  fi

  if [[ -z "$scope_tag" ]]; then
    case "$DETECTED_SCOPE" in
      flutter) scope_tag="app" ;;
      backend) scope_tag="backend" ;;
      docs) scope_tag="repo" ;;
      mixed) scope_tag="repo" ;;
      *) scope_tag="repo" ;;
    esac
  fi

  if [[ "$type" == "docs" ]]; then
    COMMIT_SUBJECT="docs: $SUMMARY"
  elif [[ "$scope_tag" == "none" ]]; then
    COMMIT_SUBJECT="$type: $SUMMARY"
  else
    COMMIT_SUBJECT="$type($scope_tag): $SUMMARY"
  fi
}

stage_if_needed() {
  if [[ "$STAGE_ALL" == "true" ]]; then
    run_cmd git add -A
  fi
}

load_staged_files() {
  mapfile -t STAGED_FILES < <(git diff --cached --name-only)

  if [[ "$DRY_RUN" == "true" && "$STAGE_ALL" == "true" && ${#STAGED_FILES[@]} -eq 0 ]]; then
    mapfile -t STAGED_FILES < <(
      {
        git diff --name-only
        git diff --cached --name-only
        git ls-files --others --exclude-standard
      } | sed '/^$/d' | sort -u
    )
  fi

  if [[ ${#STAGED_FILES[@]} -eq 0 ]]; then
    if [[ "$ALLOW_NO_CHANGES" == "true" ]]; then
      log "无已暂存改动，按 --allow-no-changes 退出"
      exit 0
    fi

    local wt_count
    wt_count="$(git status --porcelain | wc -l | tr -d ' ')"
    if [[ "$wt_count" != "0" && "$STAGE_ALL" != "true" ]]; then
      die "存在未暂存改动，请先 git add 或使用 --stage-all"
    fi

    die "无可提交改动"
  fi
}

print_change_summary() {
  local shortstat
  shortstat="$(git diff --cached --shortstat || true)"
  log "已暂存文件数量: ${#STAGED_FILES[@]}"
  if [[ -n "$shortstat" ]]; then
    log "统计: $shortstat"
  fi
  printf '%s\n' "${STAGED_FILES[@]}" | sed 's/^/[exec-push]   - /'
}

load_commit_body() {
  if [[ -n "$BODY_FILE" ]]; then
    [[ -f "$BODY_FILE" ]] || die "--body-file 不存在: $BODY_FILE"
    BODY="$(cat "$BODY_FILE")"
  fi
}

commit_changes() {
  load_commit_body

  if [[ "$DRY_RUN" == "true" ]]; then
    if [[ -n "$BODY" ]]; then
      log "[dry-run] git commit -m \"$COMMIT_SUBJECT\" -m \"<body>\""
    else
      log "[dry-run] git commit -m \"$COMMIT_SUBJECT\""
    fi
    return
  fi

  if [[ -n "$BODY" ]]; then
    git commit -m "$COMMIT_SUBJECT" -m "$BODY"
  else
    git commit -m "$COMMIT_SUBJECT"
  fi
}

write_push_context() {
  local sha="$1"
  local branch="$2"
  local remote="$3"
  local context_file
  context_file="$(git rev-parse --git-dir)/cicd-last-push.env"

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] write context: $context_file"
    return
  fi

  {
    echo "PUSHED_SHA=$sha"
    echo "PUSHED_BRANCH=$branch"
    echo "PUSHED_REMOTE=$remote"
    echo "WORKFLOW_NAME=$WORKFLOW_NAME"
  } > "$context_file"
}

push_if_needed() {
  local sha
  sha="$(git rev-parse HEAD)"

  if [[ -z "$BRANCH_NAME" ]]; then
    BRANCH_NAME="$(git branch --show-current)"
  fi

  if [[ "$PUSH" != "true" ]]; then
    log "未启用 push"
    write_push_context "$sha" "$BRANCH_NAME" "$REMOTE_NAME"
    return
  fi

  [[ -n "$BRANCH_NAME" ]] || die "无法识别当前分支，请用 --branch 指定"

  run_cmd git push "$REMOTE_NAME" "$BRANCH_NAME"
  log "push 完成: $REMOTE_NAME/$BRANCH_NAME @ $sha"

  write_push_context "$sha" "$BRANCH_NAME" "$REMOTE_NAME"
}

main() {
  parse_args "$@"
  need_cmd git
  resolve_repo_root

  stage_if_needed
  load_staged_files
  DETECTED_SCOPE="$(detect_scope_from_files "${STAGED_FILES[@]}")"
  print_change_summary
  build_commit_subject

  log "检测范围: $DETECTED_SCOPE"
  log "commit message: $COMMIT_SUBJECT"

  commit_changes
  push_if_needed

  log "完成"
}

main "$@"
