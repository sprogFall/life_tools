#!/usr/bin/env bash
set -euo pipefail

SCOPE="auto"
CHANGE_SOURCE="working-tree"
ALLOW_NO_CHANGES="false"
SKIP_PUB_GET="false"
SKIP_ANALYZE="false"
SKIP_TEST="false"
SKIP_BACKEND_TEST="false"
BACKEND_TEST_CMD=""
FLUTTER_BIN=""
DRY_RUN="false"

log() {
  echo "[pre-push] $*"
}

die() {
  echo "[pre-push] ERROR: $*" >&2
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

run_shell() {
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] $*"
    return 0
  fi
  bash -lc "$*"
}

usage() {
  cat <<'USAGE'
用法:
  bash scripts/pre-push.sh [options]

功能:
  - 在 push 前执行代码校验（Flutter / Backend）
  - 自动识别改动范围并按规则执行

选项:
  --scope <auto|flutter|backend|docs|mixed>
  --change-source <working-tree|head>
  --allow-no-changes

  --skip-pub-get
  --skip-analyze
  --skip-test
  --skip-backend-test
  --backend-test-cmd <cmd>
  --flutter-bin <path>

  --dry-run
  -h, --help

示例:
  bash scripts/pre-push.sh
  bash scripts/pre-push.sh --scope backend
  bash scripts/pre-push.sh --change-source head --scope flutter
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --scope)
        [[ $# -ge 2 ]] || die "--scope 需要参数"
        SCOPE="$2"
        shift
        ;;
      --change-source)
        [[ $# -ge 2 ]] || die "--change-source 需要参数"
        CHANGE_SOURCE="$2"
        shift
        ;;
      --allow-no-changes)
        ALLOW_NO_CHANGES="true"
        ;;
      --skip-pub-get)
        SKIP_PUB_GET="true"
        ;;
      --skip-analyze)
        SKIP_ANALYZE="true"
        ;;
      --skip-test)
        SKIP_TEST="true"
        ;;
      --skip-backend-test)
        SKIP_BACKEND_TEST="true"
        ;;
      --backend-test-cmd)
        [[ $# -ge 2 ]] || die "--backend-test-cmd 需要参数"
        BACKEND_TEST_CMD="$2"
        shift
        ;;
      --flutter-bin)
        [[ $# -ge 2 ]] || die "--flutter-bin 需要参数"
        FLUTTER_BIN="$2"
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

validate_enums() {
  case "$SCOPE" in
    auto|flutter|backend|docs|mixed) ;;
    *) die "--scope 仅支持 auto|flutter|backend|docs|mixed" ;;
  esac

  case "$CHANGE_SOURCE" in
    working-tree|head) ;;
    *) die "--change-source 仅支持 working-tree|head" ;;
  esac
}

detect_os() {
  local uname_s
  uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$uname_s" in
    msys*|mingw*|cygwin*) echo "windows" ;;
    darwin*) echo "macos" ;;
    *) echo "linux" ;;
  esac
}

resolve_repo_root() {
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$REPO_ROOT" ]] || die "当前目录不在 git 仓库内"
  cd "$REPO_ROOT"
}

collect_working_tree_files() {
  {
    git diff --name-only
    git diff --cached --name-only
    git ls-files --others --exclude-standard
  } | sed '/^$/d' | sort -u
}

collect_head_files() {
  git diff-tree --no-commit-id --name-only -r --root HEAD
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

categorize_scope_auto() {
  local only_docs="true"
  local only_backend_and_docs="true"
  local has_backend="false"
  local has_flutter="false"
  local f

  for f in "${CHANGED_FILES[@]}"; do
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
    EFFECTIVE_SCOPE="docs"
    return
  fi

  if [[ "$only_backend_and_docs" == "true" ]]; then
    EFFECTIVE_SCOPE="backend"
    return
  fi

  if [[ "$has_flutter" == "true" && "$has_backend" == "true" ]]; then
    EFFECTIVE_SCOPE="mixed"
    return
  fi

  if [[ "$has_flutter" == "true" ]]; then
    EFFECTIVE_SCOPE="flutter"
    return
  fi

  if [[ "$has_backend" == "true" ]]; then
    EFFECTIVE_SCOPE="mixed"
    return
  fi

  EFFECTIVE_SCOPE="flutter"
}

resolve_flutter_bin() {
  if [[ -n "$FLUTTER_BIN" ]]; then
    [[ -x "$FLUTTER_BIN" || -f "$FLUTTER_BIN" ]] || die "--flutter-bin 不可用: $FLUTTER_BIN"
    echo "$FLUTTER_BIN"
    return
  fi

  if command -v flutter >/dev/null 2>&1; then
    command -v flutter
    return
  fi

  if command -v flutter.bat >/dev/null 2>&1; then
    command -v flutter.bat
    return
  fi

  local candidates=()
  if [[ -n "${FLUTTER_HOME:-}" ]]; then
    candidates+=("$FLUTTER_HOME/bin/flutter")
    candidates+=("$FLUTTER_HOME/bin/flutter.bat")
  fi

  candidates+=(
    "/opt/flutter/bin/flutter"
    "$HOME/flutter/bin/flutter"
    "/usr/local/flutter/bin/flutter"
    "/c/src/flutter/bin/flutter.bat"
    "/c/flutter/bin/flutter.bat"
    "/c/tools/flutter/bin/flutter.bat"
  )

  local c
  for c in "${candidates[@]}"; do
    if [[ -x "$c" || -f "$c" ]]; then
      echo "$c"
      return
    fi
  done

  die "未找到 flutter，可用 --flutter-bin 指定路径"
}

default_backend_test_cmd() {
  if [[ "$OS_TYPE" == "windows" ]]; then
    cat <<'CMD'
cd backend/sync_server && if [ -f .venv/Scripts/python.exe ]; then .venv/Scripts/python.exe -m pytest; elif command -v python >/dev/null 2>&1; then python -m pytest; else echo "python not found" >&2; exit 1; fi
CMD
  else
    cat <<'CMD'
cd backend/sync_server && if [ -x .venv/bin/python ]; then .venv/bin/python -m pytest; elif command -v python3 >/dev/null 2>&1; then python3 -m pytest; elif command -v python >/dev/null 2>&1; then python -m pytest; else echo "python not found" >&2; exit 1; fi
CMD
  fi
}

run_flutter_checks() {
  local flutter
  flutter="$(resolve_flutter_bin)"
  log "使用 Flutter: $flutter"

  if [[ "$SKIP_PUB_GET" != "true" ]]; then
    run_cmd "$flutter" pub get
  else
    log "已跳过 flutter pub get"
  fi

  if [[ "$SKIP_ANALYZE" != "true" ]]; then
    run_cmd "$flutter" analyze
  else
    log "已跳过 flutter analyze"
  fi

  if [[ "$SKIP_TEST" != "true" ]]; then
    run_cmd "$flutter" test
  else
    log "已跳过 flutter test"
  fi
}

run_backend_checks() {
  if [[ "$SKIP_BACKEND_TEST" == "true" ]]; then
    log "已跳过 backend 测试"
    return
  fi

  if [[ -z "$BACKEND_TEST_CMD" ]]; then
    BACKEND_TEST_CMD="$(default_backend_test_cmd)"
  fi

  run_shell "$BACKEND_TEST_CMD"
}

load_changed_files() {
  if [[ "$CHANGE_SOURCE" == "working-tree" ]]; then
    mapfile -t CHANGED_FILES < <(collect_working_tree_files)
  else
    mapfile -t CHANGED_FILES < <(collect_head_files)
  fi

  if [[ ${#CHANGED_FILES[@]} -eq 0 && "$ALLOW_NO_CHANGES" != "true" ]]; then
    die "未检测到改动。可用 --allow-no-changes 放行。"
  fi
}

print_change_summary() {
  log "改动来源: $CHANGE_SOURCE"
  log "改动文件数量: ${#CHANGED_FILES[@]}"
  if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    printf '%s\n' "${CHANGED_FILES[@]}" | sed 's/^/[pre-push]   - /'
  fi
}

main() {
  parse_args "$@"
  validate_enums
  need_cmd git

  OS_TYPE="$(detect_os)"
  resolve_repo_root
  load_changed_files
  print_change_summary

  if [[ "$SCOPE" == "auto" ]]; then
    categorize_scope_auto
  else
    EFFECTIVE_SCOPE="$SCOPE"
  fi

  log "执行范围: $EFFECTIVE_SCOPE"

  case "$EFFECTIVE_SCOPE" in
    docs)
      log "仅文档改动：跳过 Flutter/Backend 校验"
      ;;
    backend)
      run_backend_checks
      ;;
    flutter)
      run_flutter_checks
      ;;
    mixed)
      run_backend_checks
      run_flutter_checks
      ;;
    *)
      die "未知执行范围: $EFFECTIVE_SCOPE"
      ;;
  esac

  log "完成"
}

main "$@"
