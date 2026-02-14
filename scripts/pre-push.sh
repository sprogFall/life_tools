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
REPO_ROOT=""
OS_TYPE=""
EFFECTIVE_SCOPE=""
FLUTTER_PUBGET_HASH_STATE_FILE=""
TARGETED_TEST_GUARANTEED="false"
TARGETED_TEST_REASON=""
TARGET_TEST_FILES=()
CURRENT_FLUTTER_PUBGET_HASH=""

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

prepare_sqlite_for_flutter_tests() {
  if [[ "${OS_TYPE:-}" != "linux" ]]; then
    return 0
  fi

  local sqlite_so_target="/usr/lib/x86_64-linux-gnu/libsqlite3.so.0"
  local sqlite_so_link="/tmp/libsqlite3.so"

  if [[ ! -e "$sqlite_so_target" ]]; then
    log "未找到 $sqlite_so_target，跳过 sqlite 兼容处理"
    return 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] ln -sf $sqlite_so_target $sqlite_so_link"
  else
    ln -sf "$sqlite_so_target" "$sqlite_so_link"
  fi

  local current_ld="${LD_LIBRARY_PATH:-}"
  if [[ -z "$current_ld" ]]; then
    export LD_LIBRARY_PATH="/tmp"
  else
    case ":$current_ld:" in
      *":/tmp:"*) ;;
      *) export LD_LIBRARY_PATH="/tmp:$current_ld" ;;
    esac
  fi

  log "已启用 sqlite 兼容（Linux）"
}

usage() {
  cat <<'USAGE'
用法:
  bash scripts/pre-push.sh [options]

功能:
  - 在 push 前执行代码校验（Flutter / Backend）
  - 自动识别改动范围并按规则执行
  - Flutter 测试优先执行可证明覆盖的目标测试，无法证明时自动回退全量

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

hash_stdin_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
    return
  fi

  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
    return
  fi

  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 | awk '{print $NF}'
    return
  fi

  die "缺少哈希命令: sha256sum/shasum/openssl 任一即可"
}

resolve_repo_root() {
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$REPO_ROOT" ]] || die "当前目录不在 git 仓库内"
  cd "$REPO_ROOT"
  FLUTTER_PUBGET_HASH_STATE_FILE="$(git rev-parse --git-dir)/pre-push/flutter-pub-get.hash"
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

compute_flutter_pub_get_hash() {
  local flutter="$1"
  local version_text
  local hash_payload

  version_text="$("$flutter" --version --machine 2>/dev/null || "$flutter" --version 2>/dev/null | head -n 1 || true)"

  hash_payload="flutter=${version_text}"$'\n'
  local dep_file
  for dep_file in "pubspec.yaml" "pubspec.lock"; do
    if [[ -f "$dep_file" ]]; then
      hash_payload+="${dep_file}:$(git hash-object "$dep_file" 2>/dev/null || echo "hash-error")"$'\n'
    else
      hash_payload+="${dep_file}:missing"$'\n'
    fi
  done

  printf '%s' "$hash_payload" | hash_stdin_sha256
}

save_flutter_pub_get_hash() {
  local hash_value="$1"
  local hash_dir

  hash_dir="$(dirname "$FLUTTER_PUBGET_HASH_STATE_FILE")"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] write pub-get hash: $FLUTTER_PUBGET_HASH_STATE_FILE"
    return
  fi

  mkdir -p "$hash_dir"
  printf '%s' "$hash_value" > "$FLUTTER_PUBGET_HASH_STATE_FILE"
}

should_run_flutter_pub_get() {
  local flutter="$1"
  local current_hash previous_hash
  local package_config=".dart_tool/package_config.json"

  current_hash="$(compute_flutter_pub_get_hash "$flutter")"
  CURRENT_FLUTTER_PUBGET_HASH="$current_hash"

  if [[ ! -f "$package_config" ]]; then
    log "未发现 ${package_config}，需要执行 flutter pub get"
    return 0
  fi

  if [[ ! -f "$FLUTTER_PUBGET_HASH_STATE_FILE" ]]; then
    log "未发现依赖哈希缓存，执行 flutter pub get"
    return 0
  fi

  previous_hash="$(cat "$FLUTTER_PUBGET_HASH_STATE_FILE" 2>/dev/null || true)"
  if [[ "$previous_hash" == "$current_hash" ]]; then
    log "依赖哈希未变化，跳过 flutter pub get"
    return 1
  fi

  log "依赖哈希变化，执行 flutter pub get"
  return 0
}

should_run_pre_push_self_test() {
  local f
  for f in "${CHANGED_FILES[@]}"; do
    case "$f" in
      scripts/pre-push.sh|scripts/tests/pre-push_test.sh)
        return 0
        ;;
      *)
        ;;
    esac
  done

  return 1
}

run_pre_push_self_test_if_needed() {
  local self_test_script="${REPO_ROOT}/scripts/tests/pre-push_test.sh"

  if ! should_run_pre_push_self_test; then
    return 0
  fi

  if [[ ! -x "$self_test_script" ]]; then
    die "检测到 pre-push 脚本改动，但自测脚本不可执行: $self_test_script"
  fi

  log "检测到 pre-push 相关改动，执行脚本自测: scripts/tests/pre-push_test.sh"
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] bash scripts/tests/pre-push_test.sh"
    return 0
  fi

  bash "$self_test_script"
}

add_target_test_file() {
  local candidate="$1"
  [[ -n "$candidate" ]] || return 0
  [[ -f "$candidate" ]] || return 0

  local existing
  for existing in "${TARGET_TEST_FILES[@]:-}"; do
    if [[ "$existing" == "$candidate" ]]; then
      return 0
    fi
  done

  TARGET_TEST_FILES+=("$candidate")
}

collect_tests_for_lib_file() {
  local lib_file="$1"
  local rel_path direct_test base_name found_match="false"

  rel_path="${lib_file#lib/}"
  direct_test="test/${rel_path%.dart}_test.dart"
  if [[ -f "$direct_test" ]]; then
    add_target_test_file "$direct_test"
    found_match="true"
  fi

  base_name="$(basename "$lib_file" .dart)"
  while IFS= read -r test_file; do
    [[ -z "$test_file" ]] && continue
    add_target_test_file "$test_file"
    found_match="true"
  done < <(find test -type f -name "${base_name}_test.dart" 2>/dev/null | sort)

  if [[ "$found_match" == "true" ]]; then
    return 0
  fi

  return 1
}

plan_targeted_flutter_tests() {
  TARGETED_TEST_GUARANTEED="false"
  TARGETED_TEST_REASON=""
  TARGET_TEST_FILES=()

  local flutter_changed_files=()
  local f
  for f in "${CHANGED_FILES[@]}"; do
    if is_flutter_file "$f"; then
      flutter_changed_files+=("$f")
    fi
  done

  if [[ ${#flutter_changed_files[@]} -eq 0 ]]; then
    TARGETED_TEST_REASON="未检测到 Flutter 侧改动"
    return
  fi

  local changed
  for changed in "${flutter_changed_files[@]}"; do
    if [[ "$changed" == test/* ]]; then
      if [[ "$changed" == *_test.dart ]]; then
        add_target_test_file "$changed"
        continue
      fi

      TARGETED_TEST_REASON="修改了测试支撑文件（非 _test.dart）：${changed}"
      return
    fi

    if [[ "$changed" == lib/* ]]; then
      if [[ "$changed" != *.dart ]]; then
        TARGETED_TEST_REASON="检测到非 Dart 的 lib 改动：${changed}"
        return
      fi
      if [[ ! -f "$changed" ]]; then
        TARGETED_TEST_REASON="检测到删除/重命名的 Dart 文件：${changed}"
        return
      fi
      if ! collect_tests_for_lib_file "$changed"; then
        TARGETED_TEST_REASON="未找到可证明覆盖的测试：${changed}"
        return
      fi
      continue
    fi

    TARGETED_TEST_REASON="包含无法建立覆盖映射的 Flutter 改动：${changed}"
    return
  done

  if [[ ${#TARGET_TEST_FILES[@]} -eq 0 ]]; then
    TARGETED_TEST_REASON="未生成可执行的目标测试集"
    return
  fi

  TARGETED_TEST_GUARANTEED="true"
}

run_flutter_tests() {
  local flutter="$1"
  plan_targeted_flutter_tests

  if [[ "$TARGETED_TEST_GUARANTEED" != "true" ]]; then
    log "回退全量 flutter test：${TARGETED_TEST_REASON}"
    run_cmd "$flutter" test
    return
  fi

  log "使用变更优先测试（可证明覆盖），目标数量: ${#TARGET_TEST_FILES[@]}"
  local test_file
  for test_file in "${TARGET_TEST_FILES[@]}"; do
    run_cmd "$flutter" test "$test_file"
  done
}

run_flutter_checks() {
  prepare_sqlite_for_flutter_tests

  local flutter
  flutter="$(resolve_flutter_bin)"
  log "使用 Flutter: $flutter"

  if [[ "$SKIP_PUB_GET" != "true" ]]; then
    if should_run_flutter_pub_get "$flutter"; then
      run_cmd "$flutter" pub get
      save_flutter_pub_get_hash "$CURRENT_FLUTTER_PUBGET_HASH"
    fi
  else
    log "已跳过 flutter pub get"
  fi

  if [[ "$SKIP_ANALYZE" != "true" ]]; then
    run_cmd "$flutter" analyze
  else
    log "已跳过 flutter analyze"
  fi

  if [[ "$SKIP_TEST" != "true" ]]; then
    run_flutter_tests "$flutter"
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
  run_pre_push_self_test_if_needed

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
