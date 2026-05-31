#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
EXEC_PUSH_SCRIPT="${REPO_ROOT}/scripts/exec-push.sh"

fail() {
  echo "[exec-push-test] FAIL: $*" >&2
  exit 1
}

assert_file_exists() {
  local file="$1"
  [[ -f "$file" ]] || fail "期望文件存在: ${file}"
}

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "[exec-push-test] file content:" >&2
    cat "$file" >&2 || true
    fail "期望包含: ${expected}"
  fi
}

setup_repo() {
  local dir="$1"
  git init -q "$dir"
  (
    cd "$dir"
    git checkout -q -b main
    git config user.name "test"
    git config user.email "test@example.com"
    mkdir -p lib
    echo "String app() => 'v1';" > lib/main.dart
    git add .
    git commit -q -m "init"
  )
}

test_record_failure_when_push_failed() {
  local tmp_repo output record_file
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  echo "String app() => 'v2';" > "${tmp_repo}/lib/main.dart"

  set +e
  (
    cd "$tmp_repo"
    bash "$EXEC_PUSH_SCRIPT" \
      --stage-all \
      --push \
      --remote missing-remote \
      --branch main \
      --summary "验证 exec-push 失败记录"
  ) >"${tmp_repo}/exec_push.log" 2>&1
  local code=$?
  set -e

  if [[ "$code" -eq 0 ]]; then
    fail "git push 失败时 exec-push 应返回非 0"
  fi

  output="${tmp_repo}/exec_push.log"
  assert_contains "$output" "已记录失败"

  record_file="$(find "${tmp_repo}/failure-records/flutter" -type f -name '*.md' | head -n 1)"
  assert_file_exists "$record_file"
  assert_contains "$record_file" "阶段: exec-push"
  assert_contains "$record_file" "模块: flutter"
  assert_contains "$record_file" "missing-remote"
  assert_contains "$record_file" "- lib/main.dart"
}

main() {
  test_record_failure_when_push_failed
  echo "[exec-push-test] all passed"
}

main "$@"
