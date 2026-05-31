#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FAILURE_RECORD_SCRIPT="${REPO_ROOT}/scripts/failure-record.sh"

fail() {
  echo "[failure-record-test] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "[failure-record-test] file content:" >&2
    cat "$file" >&2 || true
    fail "期望包含: ${expected}"
  fi
}

test_record_failure_by_module() {
  local tmp_repo log_file output record_file
  tmp_repo="$(mktemp -d)"
  log_file="${tmp_repo}/failed.log"

  git init -q "$tmp_repo"
  (
    cd "$tmp_repo"
    git config user.name "test"
    git config user.email "test@example.com"
    mkdir -p lib
    echo "String app() => 'v1';" > lib/main.dart
    git add .
    git commit -q -m "init"
  )

  cat > "$log_file" <<'LOG'
flutter analyze
Authorization: Bearer secret-token
GITHUB_TOKEN=secret-token
error - Undefined name 'x'
LOG

  output="$(
    bash "$FAILURE_RECORD_SCRIPT" \
      --repo-root "$tmp_repo" \
      --stage pre-push \
      --module flutter \
      --exit-code 1 \
      --command "flutter analyze" \
      --log-file "$log_file" \
      --changed-file lib/main.dart
  )"

  record_file="$(echo "$output" | sed -n 's/^record_file=//p')"
  [[ -f "$record_file" ]] || fail "未生成失败记录: ${record_file}"

  case "$record_file" in
    "$tmp_repo"/failure-records/flutter/*.md) ;;
    *) fail "失败记录未按模块写入: ${record_file}" ;;
  esac

  assert_contains "$record_file" "状态: 待归纳"
  assert_contains "$record_file" "阶段: pre-push"
  assert_contains "$record_file" "模块: flutter"
  assert_contains "$record_file" "精简错误信息"
  assert_contains "$record_file" "解决方案"
  assert_contains "$record_file" "预防方案"
  assert_contains "$record_file" "error - Undefined name 'x'"
  assert_contains "$record_file" "Authorization: Bearer [REDACTED]"
  assert_contains "$record_file" "GITHUB_TOKEN=[REDACTED]"
  assert_contains "$record_file" "- lib/main.dart"
}

test_sanitize_module_name() {
  local tmp_repo output record_file
  tmp_repo="$(mktemp -d)"
  git init -q "$tmp_repo"

  output="$(
    bash "$FAILURE_RECORD_SCRIPT" \
      --repo-root "$tmp_repo" \
      --stage post-push \
      --module "../Flutter App" \
      --exit-code 1 \
      --command "return 1"
  )"

  record_file="$(echo "$output" | sed -n 's/^record_file=//p')"
  [[ -f "$record_file" ]] || fail "未生成失败记录: ${record_file}"

  case "$record_file" in
    "$tmp_repo"/failure-records/flutter-app/*.md) ;;
    *) fail "模块名未被安全归一化: ${record_file}" ;;
  esac
}

main() {
  test_record_failure_by_module
  test_sanitize_module_name
  echo "[failure-record-test] all passed"
}

main "$@"
