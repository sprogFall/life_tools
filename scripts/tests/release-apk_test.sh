#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
RELEASE_SCRIPT="${REPO_ROOT}/scripts/release-apk.sh"

fail() {
  echo "[release-apk-test] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local expected="$2"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "[release-apk-test] file content:" >&2
    cat "$file" >&2 || true
    fail "期望包含: ${expected}"
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"
  if grep -Fq -- "$unexpected" "$file"; then
    echo "[release-apk-test] file content:" >&2
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
    mkdir -p lib
    echo "String app() => 'v1';" > lib/main.dart
    git add .
    git commit -q -m "init"
    git remote add origin "https://github.com/example/demo.git"
  )
}

run_release() {
  local repo_dir="$1"
  local out_file="$2"
  shift 2
  (
    cd "$repo_dir"
    bash "$RELEASE_SCRIPT" "$@"
  ) >"$out_file" 2>&1
}

test_help_is_chinese_and_friendly() {
  local tmp_repo output
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  output="$(mktemp)"
  run_release "$tmp_repo" "$output" --help

  assert_contains "$output" "用法:"
  assert_contains "$output" "一键发布正式 Android APK"
  assert_contains "$output" "等待并返回打包结果"
  assert_contains "$output" "示例:"
}

test_reject_invalid_version() {
  local tmp_repo output
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  output="$(mktemp)"
  set +e
  run_release "$tmp_repo" "$output" 1.2 --dry-run
  local code=$?
  set -e

  if [[ "$code" -eq 0 ]]; then
    fail "非法版本号应返回非 0"
  fi

  assert_contains "$output" "版本号格式不正确"
  assert_contains "$output" "请使用 1.2.3 或 v1.2.3"
}

test_dry_run_with_clean_tree_pushes_branch_tag_and_monitors() {
  local tmp_repo output
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  output="$(mktemp)"
  run_release "$tmp_repo" "$output" 9.8.7 --dry-run --max-polls 3

  assert_contains "$output" "准备发布正式 APK：v9.8.7"
  assert_contains "$output" "[dry-run] 跳过远端 tag 存在性检查：origin/v9.8.7"
  assert_contains "$output" "[dry-run] 更新版本文件 VERSION: <空> -> 9.8.7"
  assert_contains "$output" "检测到待发布改动，先执行发布前校验"
  assert_contains "$output" "[dry-run] bash"
  assert_contains "$output" "pre-push.sh"
  assert_contains "$output" "exec-push.sh"
  assert_contains "$output" "--type chore"
  assert_contains "$output" "--scope-tag release"
  assert_contains "$output" "--summary 发布\\ v9.8.7\\ 正式安装包"
  assert_contains "$output" "[dry-run] git tag -a v9.8.7 -m Release\\ v9.8.7"
  assert_contains "$output" "[dry-run] git push origin v9.8.7"
  assert_contains "$output" "post-push.sh --sha"
  assert_contains "$output" "--branch v9.8.7"
  assert_contains "$output" "--force-monitor"
  assert_contains "$output" "--max-polls 3"
  assert_contains "$output" "Release 页面：https://github.com/example/demo/releases/tag/v9.8.7"
  assert_contains "$output" "APK 直链：https://github.com/example/demo/releases/download/v9.8.7/life_tools-release-v9.8.7.apk"
}

test_dry_run_with_dirty_tree_commits_and_pushes_code_first() {
  local tmp_repo output
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"

  echo "String app() => 'v2';" > "${tmp_repo}/lib/main.dart"

  output="$(mktemp)"
  run_release "$tmp_repo" "$output" v9.8.8 --summary "发布测试版本" --dry-run

  assert_contains "$output" "[dry-run] 更新版本文件 VERSION: <空> -> 9.8.8"
  assert_contains "$output" "检测到待发布改动，先执行发布前校验"
  assert_contains "$output" "exec-push.sh"
  assert_contains "$output" "--stage-all"
  assert_contains "$output" "--push"
  assert_contains "$output" "--summary 发布测试版本"
  assert_contains "$output" "[dry-run] git tag -a v9.8.8"
  assert_not_contains "$output" "工作区干净，校验当前 HEAD"
}

test_reject_existing_local_tag() {
  local tmp_repo output
  tmp_repo="$(mktemp -d)"
  setup_repo "$tmp_repo"
  (
    cd "$tmp_repo"
    git tag v9.8.9
  )

  output="$(mktemp)"
  set +e
  run_release "$tmp_repo" "$output" v9.8.9 --dry-run
  local code=$?
  set -e

  if [[ "$code" -eq 0 ]]; then
    fail "本地 tag 已存在时应返回非 0"
  fi

  assert_contains "$output" "本地 tag 已存在：v9.8.9"
}

main() {
  test_help_is_chinese_and_friendly
  test_reject_invalid_version
  test_dry_run_with_clean_tree_pushes_branch_tag_and_monitors
  test_dry_run_with_dirty_tree_commits_and_pushes_code_first
  test_reject_existing_local_tag
  echo "[release-apk-test] all passed"
}

main "$@"
