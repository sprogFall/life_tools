#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
POST_PUSH_SCRIPT="${REPO_ROOT}/scripts/post-push.sh"

fail() {
  echo "[post-push-test] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    echo "[post-push-test] file content:" >&2
    cat "$file" >&2 || true
    fail "期望包含: ${expected}"
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq "$unexpected" "$file"; then
    echo "[post-push-test] file content:" >&2
    cat "$file" >&2 || true
    fail "不应包含: ${unexpected}"
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

    mkdir -p .github/workflows backend/sync_server dashboard/src lib scripts
    cat > .github/workflows/build-apk.yml <<'YAML'
name: Build Android APK

on:
  push:
    branches:
      - main
      - dev
    paths:
      - 'lib/**'
      - 'test/**'
      - 'android/**'
      - 'assets/**'
      - 'pubspec.yaml'
      - 'pubspec.lock'
      - 'analysis_options.yaml'
      - 'l10n.yaml'
      - '.github/workflows/build-apk.yml'
YAML
    cat > backend/sync_server/app.py <<'PY'
print('backend v1')
PY
    cat > dashboard/src/app.ts <<'TS'
export const dashboard = 'v1'
TS
    cat > lib/main.dart <<'DART'
String app() => 'v1';
DART
    mkdir -p test
    cat > test/widget_test.dart <<'DART'
void main() {}
DART
    mkdir -p android/app
    cat > android/app/build.gradle.kts <<'GRADLE'
plugins {}
GRADLE
    cat > scripts/local.sh <<'SH'
echo v1
SH
    cat > README.md <<'MD'
# demo
MD

    git add .
    git commit -q -m "init"
  )
}

run_post_push() {
  local repo_dir="$1"
  local out_file="$2"
  shift 2
  (
    cd "$repo_dir"
    bash "$POST_PUSH_SCRIPT" "$@"
  ) >"$out_file" 2>&1
}

create_commit() {
  local repo_dir="$1"
  local message="$2"
  shift 2
  (
    cd "$repo_dir"
    "$@"
    git add -A
    git commit -q -m "$message"
    git rev-parse HEAD
  )
}

test_skip_monitor_for_backend_and_dashboard_changes() {
  local tmp_repo output sha
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  sha="$(create_commit "$tmp_repo" "chore: update backend dashboard" bash -lc '
    echo "print(\"backend v2\")" > backend/sync_server/app.py
    echo "export const dashboard = \"v2\"" > dashboard/src/app.ts
  ')"

  output="${tmp_repo}/post_push_skip.log"
  run_post_push "$tmp_repo" "$output" --sha "$sha" --dry-run
  assert_contains "$output" "跳过监控: backend/dashboard/docs only changes"
}

test_force_monitor_overrides_backend_and_dashboard_skip() {
  local tmp_repo output sha
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  sha="$(create_commit "$tmp_repo" "chore: update backend dashboard" bash -lc '
    echo "print(\"backend v2\")" > backend/sync_server/app.py
    echo "export const dashboard = \"v2\"" > dashboard/src/app.ts
  ')"

  output="${tmp_repo}/post_push_force.log"
  run_post_push "$tmp_repo" "$output" --sha "$sha" --force-monitor --dry-run
  assert_contains "$output" "[dry-run] 将执行轮询"
  assert_not_contains "$output" "跳过监控"
}

test_skip_monitor_when_workflow_paths_do_not_match() {
  local tmp_repo output sha
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  sha="$(create_commit "$tmp_repo" "chore: update script" bash -lc '
    echo "echo v2" > scripts/local.sh
  ')"

  output="${tmp_repo}/post_push_paths_skip.log"
  run_post_push "$tmp_repo" "$output" --sha "$sha" --dry-run
  assert_contains "$output" "跳过监控: workflow path/branch filters do not match current push"
}

test_skip_monitor_when_workflow_branches_do_not_match() {
  local tmp_repo output sha
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  (
    cd "$tmp_repo"
    git checkout -q -b feature/demo
  )

  sha="$(create_commit "$tmp_repo" "fix: update flutter on feature" bash -lc '
    echo "String app() => \"v3\";" > lib/main.dart
  ')"

  output="${tmp_repo}/post_push_branch_skip.log"
  run_post_push "$tmp_repo" "$output" --sha "$sha" --branch feature/demo --dry-run
  assert_contains "$output" "跳过监控: workflow path/branch filters do not match current push"
}

test_monitor_for_flutter_changes() {
  local tmp_repo output sha
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  sha="$(create_commit "$tmp_repo" "fix: update flutter" bash -lc '
    echo "String app() => \"v2\";" > lib/main.dart
  ')"

  output="${tmp_repo}/post_push_flutter.log"
  run_post_push "$tmp_repo" "$output" --sha "$sha" --dry-run
  assert_contains "$output" "[dry-run] 将执行轮询"
  assert_not_contains "$output" "跳过监控"
}

test_monitor_for_android_changes() {
  local tmp_repo output sha
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  sha="$(create_commit "$tmp_repo" "build(android): update gradle config" bash -lc '
    echo "plugins { id(\"com.android.application\") }" > android/app/build.gradle.kts
  ')"

  output="${tmp_repo}/post_push_android.log"
  run_post_push "$tmp_repo" "$output" --sha "$sha" --dry-run
  assert_contains "$output" "[dry-run] 将执行轮询"
  assert_not_contains "$output" "跳过监控"
}

main() {
  test_skip_monitor_for_backend_and_dashboard_changes
  test_force_monitor_overrides_backend_and_dashboard_skip
  test_skip_monitor_when_workflow_paths_do_not_match
  test_skip_monitor_when_workflow_branches_do_not_match
  test_monitor_for_flutter_changes
  test_monitor_for_android_changes
  echo "[post-push-test] all passed"
}

main "$@"
