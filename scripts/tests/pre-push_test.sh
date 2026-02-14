#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PRE_PUSH_SCRIPT="${REPO_ROOT}/scripts/pre-push.sh"

fail() {
  echo "[pre-push-test] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq "$expected" "$file"; then
    echo "[pre-push-test] file content:" >&2
    cat "$file" >&2 || true
    fail "期望包含: ${expected}"
  fi
}

assert_not_contains_exact_line() {
  local file="$1"
  local expected="$2"
  if grep -Fxq "$expected" "$file"; then
    echo "[pre-push-test] file content:" >&2
    cat "$file" >&2 || true
    fail "不应出现整行: ${expected}"
  fi
}

assert_empty_file() {
  local file="$1"
  if [[ -s "$file" ]]; then
    echo "[pre-push-test] file content:" >&2
    cat "$file" >&2 || true
    fail "期望为空文件: ${file}"
  fi
}

setup_repo() {
  local dir="$1"
  git init -q "$dir"
  (
    cd "$dir"
    git config user.name "test"
    git config user.email "test@example.com"

    mkdir -p lib/foo test/foo
    cat > pubspec.yaml <<'EOF'
name: demo
description: test repo
version: 1.0.0
environment:
  sdk: ">=3.0.0 <4.0.0"
dependencies:
  flutter:
    sdk: flutter
EOF
    cat > pubspec.lock <<'EOF'
# generated
EOF
    cat > analysis_options.yaml <<'EOF'
include: package:flutter_lints/flutter.yaml
EOF
    cat > lib/foo/bar.dart <<'EOF'
String demo() => 'v1';
EOF
    cat > test/foo/bar_test.dart <<'EOF'
void main() {}
EOF

    git add .
    git commit -q -m "init"
  )
}

create_fake_flutter() {
  local file="$1"
  cat > "$file" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

log_file="${FAKE_FLUTTER_LOG:?}"

if [[ "${1:-}" == "--version" && "${2:-}" == "--machine" ]]; then
  echo '{"frameworkVersion":"3.38.6"}'
  exit 0
fi

if [[ "${1:-}" == "--version" ]]; then
  echo 'Flutter 3.38.6'
  exit 0
fi

echo "$*" >> "$log_file"

if [[ "${1:-}" == "pub" && "${2:-}" == "get" ]]; then
  mkdir -p .dart_tool
  printf '{"configVersion":2}' > .dart_tool/package_config.json
fi
EOF
  chmod +x "$file"
}

run_pre_push() {
  local repo_dir="$1"
  local fake_flutter="$2"
  local log_file="$3"
  shift 3
  (
    cd "$repo_dir"
    FAKE_FLUTTER_LOG="$log_file" bash "$PRE_PUSH_SCRIPT" \
      --scope flutter \
      --change-source working-tree \
      --flutter-bin "$fake_flutter" \
      "$@"
  )
}

test_changed_priority_with_guaranteed_coverage() {
  local tmp_repo
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  local fake_flutter="${tmp_repo}/fake_flutter.sh"
  local log_file="${tmp_repo}/flutter.log"
  create_fake_flutter "$fake_flutter"
  : > "$log_file"

  echo "String demo() => 'v2';" > "${tmp_repo}/lib/foo/bar.dart"

  run_pre_push "$tmp_repo" "$fake_flutter" "$log_file" --skip-pub-get --skip-analyze
  assert_contains "$log_file" "test test/foo/bar_test.dart"
  assert_not_contains_exact_line "$log_file" "test"
}

test_fallback_full_test_for_unmappable_flutter_change() {
  local tmp_repo
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  local fake_flutter="${tmp_repo}/fake_flutter.sh"
  local log_file="${tmp_repo}/flutter.log"
  create_fake_flutter "$fake_flutter"
  : > "$log_file"

  mkdir -p "${tmp_repo}/android/app"
  cat > "${tmp_repo}/android/app/build.gradle" <<'EOF'
// touched
EOF

  run_pre_push "$tmp_repo" "$fake_flutter" "$log_file" --skip-pub-get --skip-analyze
  assert_contains "$log_file" "test"
}

test_pub_get_hash_short_circuit() {
  local tmp_repo
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  local fake_flutter="${tmp_repo}/fake_flutter.sh"
  local first_log="${tmp_repo}/flutter_first.log"
  local second_log="${tmp_repo}/flutter_second.log"
  create_fake_flutter "$fake_flutter"
  : > "$first_log"
  : > "$second_log"

  echo "String demo() => 'v2';" > "${tmp_repo}/lib/foo/bar.dart"

  run_pre_push "$tmp_repo" "$fake_flutter" "$first_log" --skip-analyze --skip-test
  assert_contains "$first_log" "pub get"

  run_pre_push "$tmp_repo" "$fake_flutter" "$second_log" --skip-analyze --skip-test
  assert_empty_file "$second_log"
}

test_run_pre_push_self_test_when_script_changed() {
  local tmp_repo
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  local fake_flutter="${tmp_repo}/fake_flutter.sh"
  local log_file="${tmp_repo}/flutter.log"
  create_fake_flutter "$fake_flutter"
  : > "$log_file"

  mkdir -p "${tmp_repo}/scripts/tests"
  cat > "${tmp_repo}/scripts/pre-push.sh" <<'EOF'
# changed
EOF
  cat > "${tmp_repo}/scripts/tests/pre-push_test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "self-test-ran" >> self_test.log
EOF
  chmod +x "${tmp_repo}/scripts/tests/pre-push_test.sh"

  run_pre_push "$tmp_repo" "$fake_flutter" "$log_file" --skip-pub-get --skip-analyze --skip-test
  assert_contains "${tmp_repo}/self_test.log" "self-test-ran"
}

test_fail_when_pre_push_self_test_failed() {
  local tmp_repo
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  local fake_flutter="${tmp_repo}/fake_flutter.sh"
  local log_file="${tmp_repo}/flutter.log"
  create_fake_flutter "$fake_flutter"
  : > "$log_file"

  mkdir -p "${tmp_repo}/scripts/tests"
  cat > "${tmp_repo}/scripts/pre-push.sh" <<'EOF'
# changed
EOF
  cat > "${tmp_repo}/scripts/tests/pre-push_test.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 2
EOF
  chmod +x "${tmp_repo}/scripts/tests/pre-push_test.sh"

  set +e
  run_pre_push "$tmp_repo" "$fake_flutter" "$log_file" --skip-pub-get --skip-analyze --skip-test
  local code=$?
  set -e

  if [[ "$code" -eq 0 ]]; then
    fail "pre-push 自测失败时应阻断主流程"
  fi
}

main() {
  test_changed_priority_with_guaranteed_coverage
  test_fallback_full_test_for_unmappable_flutter_change
  test_pub_get_hash_short_circuit
  test_run_pre_push_self_test_when_script_changed
  test_fail_when_pre_push_self_test_failed
  echo "[pre-push-test] all passed"
}

main "$@"
