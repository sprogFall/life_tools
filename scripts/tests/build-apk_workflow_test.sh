#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/build-apk.yml"

fail() {
  echo "[build-apk-workflow-test] FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local expected="$1"
  grep -Fq -- "$expected" "$WORKFLOW" || fail "期望 workflow 包含: ${expected}"
}

assert_not_contains() {
  local unexpected="$1"
  if grep -Fq -- "$unexpected" "$WORKFLOW"; then
    fail "workflow 不应包含: ${unexpected}"
  fi
}

assert_contains "tags:"
assert_contains "workflow_dispatch:"
assert_contains "- 'v*'"
assert_contains "branches:"
assert_contains "- main"
assert_contains "- dev"
assert_contains "- 'VERSION'"
assert_contains "fetch-depth: 0"
assert_contains "get_version_from_file()"
assert_contains "APP_VERSION=\"\${BRANCH#v}\""
assert_contains "BASE_VERSION=\$(get_version_from_file)"
assert_contains "APP_VERSION=\"\${BASE_VERSION}-beta.\${RUN_NUMBER}\""
assert_contains "--build-name=\"\$APP_VERSION\""
assert_contains "--dart-define=APP_VERSION=\"\$APP_VERSION\""
assert_contains "APK_NAME=\"life_tools-release-\${VERSION_TAG}.apk\""
assert_contains "PRERELEASE_FLAG=\"\""
assert_contains "Building RELEASE APK (main branch auto-build) with version"
assert_contains "Building DEBUG APK (dev branch auto-build) with version"
assert_contains "TAG_NAME=\"apk-\${BRANCH}-\${SHORT_SHA}\""
assert_contains "PRERELEASE_FLAG=\"--prerelease\""
assert_contains "MIRROR_BASE_URL=\"\${{ vars.APK_MIRROR_BASE_URL }}\""
assert_contains "APK-Mirror: \${MIRROR_URL}"
assert_contains "mirror_url=\$MIRROR_URL"

echo "[build-apk-workflow-test] all passed"
