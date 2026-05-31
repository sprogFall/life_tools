#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=""
STAGE=""
MODULE=""
EXIT_CODE=""
COMMAND_TEXT=""
LOG_FILE=""
LOG_LINES="160"
CHANGED_FILES=()

die() {
  echo "[failure-record] ERROR: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
用法:
  bash scripts/failure-record.sh [options]

功能:
  - 将 pre-push / exec-push / post-push 的失败信息记录到 failure-records/<module>/
  - 生成待归纳模板，供 AI 修复后补充“精简错误信息 / 解决方案 / 预防方案”

选项:
  --repo-root <path>         仓库根目录（默认自动识别）
  --stage <name>             阶段，如 pre-push / exec-push / post-push
  --module <name>            模块，如 flutter / backend / dashboard / docs / repo
  --exit-code <code>         失败退出码或构建结论
  --command <text>           失败命令或动作
  --log-file <path>          失败日志文件
  --log-lines <n>            记录日志尾部行数（默认 160）
  --changed-file <path>      关联改动文件，可重复传入

示例:
  bash scripts/failure-record.sh --stage pre-push --module flutter --exit-code 1 --command "flutter analyze"
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo-root)
        [[ $# -ge 2 ]] || die "--repo-root 需要参数"
        REPO_ROOT="$2"
        shift
        ;;
      --stage)
        [[ $# -ge 2 ]] || die "--stage 需要参数"
        STAGE="$2"
        shift
        ;;
      --module)
        [[ $# -ge 2 ]] || die "--module 需要参数"
        MODULE="$2"
        shift
        ;;
      --exit-code)
        [[ $# -ge 2 ]] || die "--exit-code 需要参数"
        EXIT_CODE="$2"
        shift
        ;;
      --command)
        [[ $# -ge 2 ]] || die "--command 需要参数"
        COMMAND_TEXT="$2"
        shift
        ;;
      --log-file)
        [[ $# -ge 2 ]] || die "--log-file 需要参数"
        LOG_FILE="$2"
        shift
        ;;
      --log-lines)
        [[ $# -ge 2 ]] || die "--log-lines 需要参数"
        LOG_LINES="$2"
        shift
        ;;
      --changed-file)
        [[ $# -ge 2 ]] || die "--changed-file 需要参数"
        CHANGED_FILES+=("$2")
        shift
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
  if [[ -n "$REPO_ROOT" ]]; then
    [[ -d "$REPO_ROOT" ]] || die "--repo-root 不存在: $REPO_ROOT"
    cd "$REPO_ROOT"
    REPO_ROOT="$(pwd)"
    return
  fi

  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$REPO_ROOT" ]] || die "当前目录不在 git 仓库内，请通过 --repo-root 指定"
  cd "$REPO_ROOT"
}

validate_args() {
  [[ -n "$STAGE" ]] || die "缺少 --stage"
  [[ -n "$MODULE" ]] || die "缺少 --module"
  [[ -n "$EXIT_CODE" ]] || die "缺少 --exit-code"
  [[ -n "$COMMAND_TEXT" ]] || COMMAND_TEXT="未提供"

  if [[ ! "$LOG_LINES" =~ ^[0-9]+$ ]]; then
    die "--log-lines 仅支持非负整数"
  fi
}

sanitize_name() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | sed -E 's#[^a-z0-9._-]+#-#g; s#^[.-]+##; s#[.-]+$##; s#-+#-#g')"
  if [[ -z "$value" ]]; then
    value="repo"
  fi
  printf '%s' "$value"
}

sanitize_log() {
  sed -E \
    -e 's/(Authorization:[[:space:]]*Bearer[[:space:]]+)[^[:space:]]+/\1[REDACTED]/g' \
    -e 's/([A-Za-z_][A-Za-z0-9_]*([Tt][Oo][Kk][Ee][Nn]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]|[Aa][Pp][Ii]_?[Kk][Ee][Yy]|[Kk][Ee][Yy])[A-Za-z0-9_]*=)[^[:space:]]+/\1[REDACTED]/g' \
    -e 's#([?&]([Aa][Cc][Cc][Ee][Ss][Ss]_?[Tt][Oo][Kk][Ee][Nn]|[Tt][Oo][Kk][Ee][Nn]|[Aa][Pp][Ii]_?[Kk][Ee][Yy])=)[^&[:space:]]+#\1[REDACTED]#g'
}

load_changed_files_if_missing() {
  if [[ ${#CHANGED_FILES[@]} -gt 0 ]]; then
    return
  fi

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    mapfile -t CHANGED_FILES < <(
      {
        git diff --name-only 2>/dev/null || true
        git diff --cached --name-only 2>/dev/null || true
        git diff-tree --no-commit-id --name-only -r --root HEAD 2>/dev/null || true
      } | sed '/^$/d' | sort -u
    )
  fi
}

write_changed_files() {
  if [[ ${#CHANGED_FILES[@]} -eq 0 ]]; then
    echo "- 未记录"
    return
  fi

  local file
  for file in "${CHANGED_FILES[@]}"; do
    echo "- ${file}"
  done
}

write_log_excerpt() {
  if [[ -z "$LOG_FILE" || ! -f "$LOG_FILE" ]]; then
    echo "未提供日志文件。"
    return
  fi

  if [[ "$LOG_LINES" -eq 0 ]]; then
    echo "已按 --log-lines 0 跳过日志摘录。"
    return
  fi

  tail -n "$LOG_LINES" "$LOG_FILE" | sanitize_log
}

current_branch() {
  git branch --show-current 2>/dev/null || true
}

current_sha() {
  git rev-parse --short HEAD 2>/dev/null || true
}

create_record() {
  local module_slug stage_slug timestamp record_dir record_file suffix
  module_slug="$(sanitize_name "$MODULE")"
  stage_slug="$(sanitize_name "$STAGE")"
  timestamp="$(date -u '+%Y%m%dT%H%M%SZ')"
  record_dir="${REPO_ROOT}/failure-records/${module_slug}"
  record_file="${record_dir}/${timestamp}-${stage_slug}.md"

  mkdir -p "$record_dir"
  if [[ -e "$record_file" ]]; then
    suffix="$$"
    record_file="${record_dir}/${timestamp}-${stage_slug}-${suffix}.md"
  fi

  {
    echo "# ${STAGE} 失败记录 - ${module_slug} - ${timestamp}"
    echo
    echo "状态: 待归纳"
    echo "阶段: ${STAGE}"
    echo "模块: ${module_slug}"
    echo "退出码/结论: ${EXIT_CODE}"
    echo "记录时间(UTC): ${timestamp}"
    echo "分支: $(current_branch)"
    echo "提交: $(current_sha)"
    echo
    echo "## 失败命令"
    echo '```bash'
    printf '%s\n' "$COMMAND_TEXT" | sanitize_log
    echo '```'
    echo
    echo "## 关联改动文件"
    write_changed_files
    echo
    echo "## 精简错误信息"
    echo "- 待修复后填写：保留关键报错、失败步骤、影响范围，删除重复日志。"
    echo
    echo "## 解决方案"
    echo "- 待修复后填写：说明根因、修改文件、验证命令。"
    echo
    echo "## 预防方案"
    echo "- 待修复后填写：后续开发该模块前需要检查的规则、测试或文档。"
    echo
    echo "## 原始失败信息"
    echo '```text'
    write_log_excerpt
    echo '```'
  } > "$record_file"

  echo "record_file=${record_file}"
}

main() {
  parse_args "$@"
  resolve_repo_root
  validate_args
  load_changed_files_if_missing
  create_record
}

main "$@"
