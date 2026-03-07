#!/usr/bin/env bash
set -euo pipefail

DOC_PREFIX_REGEX='^docs?($|[:( ].*)'

SHA=""
BRANCH_NAME=""
REMOTE_NAME=""
WORKFLOW_NAME=""
MONITOR="auto"
FORCE_MONITOR="false"
MAX_POLLS=""
DRY_RUN="false"
LOG_TAIL_LINES=""

JSON_MODE=""
PYTHON_CMD=()
SKIP_REASON=""
CHANGED_FILES=()

log() {
  echo "[post-push] $*"
}

die() {
  echo "[post-push] ERROR: $*" >&2
  exit 1
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    die "缺少命令: $1"
  fi
}

usage() {
  cat <<'USAGE'
用法:
  bash scripts/post-push.sh [options]

功能:
  - push 后按规则监控 GitHub Action 状态
  - 默认读取 exec-push 产出的上下文（sha/branch/remote/workflow）

选项:
  --sha <sha>
  --branch <name>
  --remote <name>
  --workflow <name>
  --monitor                 强制开启监控
  --no-monitor              关闭监控
  --force-monitor           忽略 doc/backend/dashboard/workflow 跳过规则，强制轮询
  --max-polls <n>           最大轮询次数（0/不传表示不限）
  --log-lines <n>           失败日志尾部行数（默认 50，0=不获取）

  --dry-run
  -h, --help

示例:
  bash scripts/post-push.sh
  bash scripts/post-push.sh --sha <sha> --workflow "Build Android APK"
  bash scripts/post-push.sh --force-monitor --max-polls 20
USAGE
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sha)
        [[ $# -ge 2 ]] || die "--sha 需要参数"
        SHA="$2"
        shift
        ;;
      --branch)
        [[ $# -ge 2 ]] || die "--branch 需要参数"
        BRANCH_NAME="$2"
        shift
        ;;
      --remote)
        [[ $# -ge 2 ]] || die "--remote 需要参数"
        REMOTE_NAME="$2"
        shift
        ;;
      --workflow)
        [[ $# -ge 2 ]] || die "--workflow 需要参数"
        WORKFLOW_NAME="$2"
        shift
        ;;
      --monitor)
        MONITOR="true"
        ;;
      --no-monitor)
        MONITOR="false"
        ;;
      --force-monitor)
        FORCE_MONITOR="true"
        ;;
      --max-polls)
        [[ $# -ge 2 ]] || die "--max-polls 需要参数"
        MAX_POLLS="$2"
        shift
        ;;
      --log-lines)
        [[ $# -ge 2 ]] || die "--log-lines 需要参数"
        LOG_TAIL_LINES="$2"
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

load_context_file() {
  local context_file
  context_file="$(git rev-parse --git-dir)/cicd-last-push.env"

  if [[ ! -f "$context_file" ]]; then
    return
  fi

  local k v
  while IFS='=' read -r k v; do
    case "$k" in
      PUSHED_SHA)
        [[ -z "$SHA" ]] && SHA="$v"
        ;;
      PUSHED_BRANCH)
        [[ -z "$BRANCH_NAME" ]] && BRANCH_NAME="$v"
        ;;
      PUSHED_REMOTE)
        [[ -z "$REMOTE_NAME" ]] && REMOTE_NAME="$v"
        ;;
      WORKFLOW_NAME)
        [[ -z "$WORKFLOW_NAME" ]] && WORKFLOW_NAME="$v"
        ;;
      *)
        ;;
    esac
  done < "$context_file"
}

fill_defaults() {
  [[ -n "$SHA" ]] || SHA="$(git rev-parse HEAD)"
  [[ -n "$BRANCH_NAME" ]] || BRANCH_NAME="$(git branch --show-current 2>/dev/null || true)"
  [[ -n "$REMOTE_NAME" ]] || REMOTE_NAME="origin"
  [[ -n "$WORKFLOW_NAME" ]] || WORKFLOW_NAME="Build Android APK"

  case "$MONITOR" in
    auto)
      MONITOR="true"
      ;;
    true|false)
      ;;
    *)
      die "monitor 参数非法: $MONITOR"
      ;;
  esac

  if [[ -n "$MAX_POLLS" && ! "$MAX_POLLS" =~ ^[0-9]+$ ]]; then
    die "--max-polls 仅支持非负整数"
  fi

  [[ -n "$LOG_TAIL_LINES" ]] || LOG_TAIL_LINES="50"
  if [[ ! "$LOG_TAIL_LINES" =~ ^[0-9]+$ ]]; then
    die "--log-lines 仅支持非负整数"
  fi
}

load_changed_files() {
  mapfile -t CHANGED_FILES < <(git diff-tree --no-commit-id --name-only -r --root "$SHA")
}

trim_ascii_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

normalize_yaml_scalar() {
  local value="$1"
  value="$(trim_ascii_whitespace "$value")"

  if [[ ${#value} -ge 2 ]]; then
    if [[ "${value:0:1}" == "'" && "${value: -1}" == "'" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "${value:0:1}" == '"' && "${value: -1}" == '"' ]]; then
      value="${value:1:${#value}-2}"
    fi
  fi

  printf '%s
' "$value"
}

find_workflow_file_by_name() {
  local workflow_file workflow_name

  [[ -d .github/workflows ]] || return 0

  while IFS= read -r workflow_file; do
    workflow_name="$(awk '
      /^[[:space:]]*name:[[:space:]]*/ {
        line = $0
        sub(/^[[:space:]]*name:[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line)
        print line
        exit
      }
    ' "$workflow_file")"
    workflow_name="$(normalize_yaml_scalar "$workflow_name")"

    if [[ "$workflow_name" == "$WORKFLOW_NAME" ]]; then
      printf '%s
' "$workflow_file"
      return 0
    fi
  done < <(find .github/workflows -maxdepth 1 -type f \( -name '*.yml' -o -name '*.yaml' \) | sort)
}

extract_workflow_push_list() {
  local workflow_file="$1"
  local list_key="$2"

  awk -v list_key="$list_key" '
    function indent_of(line) {
      match(line, /^[ ]*/)
      return RLENGTH
    }

    function is_blank(line) {
      return line ~ /^[[:space:]]*$/
    }

    function is_comment(line) {
      return line ~ /^[[:space:]]*#/
    }

    {
      line = $0
      if (is_blank(line) || is_comment(line)) {
        next
      }

      indent = indent_of(line)

      if (in_list && indent <= list_indent && line !~ /^[[:space:]]*-/) {
        in_list = 0
      }
      if (in_push && indent <= push_indent && line !~ /^[[:space:]]*(branches|paths):[[:space:]]*$/) {
        in_push = 0
      }
      if (in_on && indent <= on_indent && line !~ /^[[:space:]]*push:[[:space:]]*$/) {
        in_on = 0
      }

      if (line ~ /^[[:space:]]*on:[[:space:]]*$/) {
        in_on = 1
        on_indent = indent
        next
      }
      if (in_on && line ~ /^[[:space:]]*push:[[:space:]]*$/) {
        in_push = 1
        push_indent = indent
        next
      }
      if (in_push && line ~ ("^[[:space:]]*" list_key ":[[:space:]]*$")) {
        in_list = 1
        list_indent = indent
        next
      }
      if (in_list && line ~ /^[[:space:]]*-[[:space:]]*/) {
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line)
        print line
      }
    }
  ' "$workflow_file" | while IFS= read -r value; do
    normalize_yaml_scalar "$value"
  done
}

workflow_rule_matches_value() {
  local value="$1"
  local rule="$2"

  [[ -n "$rule" ]] || return 1
  [[ "$value" == $rule ]]
}

workflow_matches_current_push() {
  local workflow_file
  local rule
  local file
  local branch_matched="false"
  local -a branch_rules=()
  local -a path_rules=()

  workflow_file="$(find_workflow_file_by_name)"
  [[ -n "$workflow_file" ]] || return 0

  mapfile -t branch_rules < <(extract_workflow_push_list "$workflow_file" "branches")
  if [[ ${#branch_rules[@]} -gt 0 && -n "$BRANCH_NAME" ]]; then
    for rule in "${branch_rules[@]}"; do
      if workflow_rule_matches_value "$BRANCH_NAME" "$rule"; then
        branch_matched="true"
        break
      fi
    done

    if [[ "$branch_matched" != "true" ]]; then
      return 1
    fi
  fi

  mapfile -t path_rules < <(extract_workflow_push_list "$workflow_file" "paths")
  if [[ ${#path_rules[@]} -eq 0 ]]; then
    return 0
  fi

  for file in "${CHANGED_FILES[@]}"; do
    for rule in "${path_rules[@]}"; do
      if workflow_rule_matches_value "$file" "$rule"; then
        return 0
      fi
    done
  done

  return 1
}

extract_repo_from_remote() {
  local remote_url="$1"
  local path

  path="$(echo "$remote_url" | sed -E \
    -e 's#^https?://github.com/##' \
    -e 's#^git@github.com:##' \
    -e 's#^ssh://git@ssh.github.com:443/##' \
    -e 's#\.git$##')"

  if [[ "$path" != */* ]]; then
    echo ""
    return
  fi

  echo "$path"
}

select_json_mode() {
  if command -v jq >/dev/null 2>&1; then
    JSON_MODE="jq"
    return
  fi

  if command -v python3 >/dev/null 2>&1; then
    JSON_MODE="python"
    PYTHON_CMD=("python3")
    return
  fi

  if command -v python >/dev/null 2>&1; then
    JSON_MODE="python"
    PYTHON_CMD=("python")
    return
  fi

  if command -v py >/dev/null 2>&1; then
    JSON_MODE="python"
    PYTHON_CMD=("py" "-3")
    return
  fi

  die "缺少 JSON 解析器：请安装 jq 或 python/python3/py"
}

gh_api() {
  local -a headers=(-H 'Accept: application/vnd.github+json')
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi
  curl -fsSL "${headers[@]}" "$@"
}

pick_run_json() {
  local runs_json="$1"

  if [[ "$JSON_MODE" == "jq" ]]; then
    echo "$runs_json" | jq -c --arg workflow "$WORKFLOW_NAME" '(.workflow_runs | map(select(.name == $workflow)) | .[0]) // .workflow_runs[0] // empty'
    return
  fi

  local tmp
  tmp="$(mktemp)"
  printf '%s' "$runs_json" > "$tmp"

  "${PYTHON_CMD[@]}" - "$tmp" "$WORKFLOW_NAME" <<'PY'
import json
import sys

path = sys.argv[1]
workflow = sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

runs = data.get("workflow_runs") or []
run = None
for item in runs:
    if item.get("name") == workflow:
        run = item
        break

if run is None and runs:
    run = runs[0]

if run is not None:
    print(json.dumps(run, separators=(",", ":")))
PY

  rm -f "$tmp"
}

json_field() {
  local json_text="$1"
  local field="$2"

  if [[ "$JSON_MODE" == "jq" ]]; then
    echo "$json_text" | jq -r --arg f "$field" '.[$f] // empty'
    return
  fi

  local tmp
  tmp="$(mktemp)"
  printf '%s' "$json_text" > "$tmp"

  "${PYTHON_CMD[@]}" - "$tmp" "$field" <<'PY'
import json
import sys

path = sys.argv[1]
field = sys.argv[2]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

value = data.get(field)
print("" if value is None else value)
PY

  rm -f "$tmp"
}

print_failed_steps() {
  local jobs_json="$1"

  if [[ "$JSON_MODE" == "jq" ]]; then
    echo "$jobs_json" | jq -r '.jobs[] | .steps[] | select(.conclusion == "failure") | "- step=\(.name)"'
    return
  fi

  local tmp
  tmp="$(mktemp)"
  printf '%s' "$jobs_json" > "$tmp"

  "${PYTHON_CMD[@]}" - "$tmp" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for job in data.get("jobs") or []:
    for step in job.get("steps") or []:
        if step.get("conclusion") == "failure":
            print(f"- step={step.get('name', '')}")
PY

  rm -f "$tmp"
}

extract_failed_job_ids() {
  local jobs_json="$1"

  if [[ "$JSON_MODE" == "jq" ]]; then
    echo "$jobs_json" | jq -r '.jobs[] | select(.conclusion == "failure") | "\(.id)\t\(.name)"'
    return
  fi

  local tmp
  tmp="$(mktemp)"
  printf '%s' "$jobs_json" > "$tmp"

  "${PYTHON_CMD[@]}" - "$tmp" <<'PY'
import json
import sys

path = sys.argv[1]
with open(path, 'r', encoding='utf-8') as f:
    data = json.load(f)

for job in data.get("jobs") or []:
    if job.get("conclusion") == "failure":
        print(f"{job['id']}\t{job.get('name', '')}")
PY

  rm -f "$tmp"
}

print_job_failure_detail() {
  local owner="$1" repo="$2" job_id="$3" job_name="$4" tail_lines="$5"
  local log_url="https://api.github.com/repos/${owner}/${repo}/actions/jobs/${job_id}/logs"
  local tmp_log
  tmp_log="$(mktemp)"

  if ! gh_api -o "$tmp_log" "$log_url" 2>/dev/null; then
    log "  无法下载 job [${job_name}] 的日志"
    rm -f "$tmp_log"
    return
  fi

  log "─── job: ${job_name} (id=${job_id}) ───"

  # Extract ##[error] annotation lines as key error messages
  local error_lines
  error_lines="$(grep '##\[error\]' "$tmp_log" 2>/dev/null | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z //' || true)"

  if [[ -n "$error_lines" ]]; then
    log "  错误注解:"
    while IFS= read -r line; do
      echo "    $line"
    done <<< "$error_lines"
  fi

  # Print last N lines for context
  log "  日志尾部（最后 ${tail_lines} 行）:"
  tail -n "$tail_lines" "$tmp_log" | sed -E 's/^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:.]+Z //' | while IFS= read -r line; do
    echo "    $line"
  done

  rm -f "$tmp_log"
}

print_failure_logs() {
  local owner="$1" repo="$2" jobs_json="$3" tail_lines="$4"

  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    log "提示: 设置 GITHUB_TOKEN 环境变量可获取失败日志详情"
    return
  fi

  if [[ "$tail_lines" -eq 0 ]]; then
    return
  fi

  local job_id job_name
  while IFS=$'\t' read -r job_id job_name; do
    [[ -z "$job_id" ]] && continue
    print_job_failure_detail "$owner" "$repo" "$job_id" "$job_name" "$tail_lines"
  done < <(extract_failed_job_ids "$jobs_json")
}

is_monitor_skippable_file() {
  local file="$1"

  case "$file" in
    backend/*|dashboard/*|docs/*|examples/*|*.md)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

should_skip_monitoring() {
  local lower_message
  local only_backend_dashboard_or_docs="true"
  local file

  if [[ "$FORCE_MONITOR" == "true" ]]; then
    return 1
  fi

  COMMIT_MESSAGE="$(git show -s --format=%s "$SHA")"
  lower_message="$(echo "$COMMIT_MESSAGE" | tr '[:upper:]' '[:lower:]')"

  if [[ "$lower_message" =~ $DOC_PREFIX_REGEX ]]; then
    SKIP_REASON="commit message starts with doc/docs"
    return 0
  fi

  for file in "${CHANGED_FILES[@]}"; do
    [[ -z "$file" ]] && continue
    if ! is_monitor_skippable_file "$file"; then
      only_backend_dashboard_or_docs="false"
      break
    fi
  done

  if [[ "$only_backend_dashboard_or_docs" == "true" ]]; then
    SKIP_REASON="backend/dashboard/docs only changes"
    return 0
  fi

  if ! workflow_matches_current_push; then
    SKIP_REASON="workflow path/branch filters do not match current push"
    return 0
  fi

  return 1
}

run_monitor_loop() {
  local remote_url
  local repo_path
  local owner
  local repo
  local runs_api
  local runs_json
  local run_json
  local run_id
  local status
  local conclusion
  local url
  local name
  local jobs_api
  local jobs_json

  remote_url="$(git remote get-url "$REMOTE_NAME")"
  repo_path="$(extract_repo_from_remote "$remote_url")"
  [[ -n "$repo_path" ]] || die "无法从 remote 解析仓库: $remote_url"

  owner="${repo_path%%/*}"
  repo="${repo_path##*/}"

  log "repo=${owner}/${repo}"
  log "sha=${SHA}"

  local attempt=0
  local wait_seconds=0
  local max_polls_value=0
  max_polls_value="${MAX_POLLS:-0}"

  while true; do
    if (( attempt == 0 )); then
      wait_seconds=10
    elif (( attempt == 1 )); then
      wait_seconds=30
    else
      wait_seconds=60
    fi

    sleep "$wait_seconds"
    attempt=$((attempt + 1))

    if (( max_polls_value > 0 && attempt > max_polls_value )); then
      die "达到最大轮询次数 MAX_POLLS=${max_polls_value}"
    fi

    runs_api="https://api.github.com/repos/${owner}/${repo}/actions/runs?head_sha=${SHA}&per_page=20"
    if ! runs_json="$(gh_api "$runs_api")"; then
      log "[try=${attempt}] 查询失败，继续重试"
      continue
    fi

    run_json="$(pick_run_json "$runs_json")"
    if [[ -z "$run_json" ]]; then
      log "[try=${attempt}] 未找到对应 run"
      continue
    fi

    run_id="$(json_field "$run_json" "id")"
    status="$(json_field "$run_json" "status")"
    conclusion="$(json_field "$run_json" "conclusion")"
    url="$(json_field "$run_json" "html_url")"
    name="$(json_field "$run_json" "name")"

    log "[try=${attempt}] workflow=${name} run_id=${run_id} status=${status} conclusion=${conclusion}"
    log "[url] ${url}"

    if [[ "$status" != "completed" ]]; then
      continue
    fi

    if [[ "$conclusion" == "success" ]]; then
      log "done: success"
      return 0
    fi

    jobs_api="https://api.github.com/repos/${owner}/${repo}/actions/runs/${run_id}/jobs"
    if jobs_json="$(gh_api "$jobs_api")"; then
      log "done: ${conclusion}"
      print_failed_steps "$jobs_json"
      print_failure_logs "$owner" "$repo" "$jobs_json" "$LOG_TAIL_LINES"
    else
      log "done: ${conclusion}（获取 jobs 失败）"
    fi

    return 1
  done
}

main() {
  parse_args "$@"
  need_cmd git
  need_cmd curl

  resolve_repo_root
  load_context_file
  fill_defaults

  git rev-parse --verify "$SHA^{commit}" >/dev/null 2>&1 || die "无效的 commit SHA: $SHA"
  load_changed_files

  log "sha=$SHA"
  log "branch=${BRANCH_NAME:-unknown}"
  log "remote=$REMOTE_NAME"
  log "workflow=$WORKFLOW_NAME"
  log "monitor=$MONITOR force_monitor=$FORCE_MONITOR max_polls=${MAX_POLLS:-0} log_lines=$LOG_TAIL_LINES"
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    log "GITHUB_TOKEN: 已设置"
  else
    log "GITHUB_TOKEN: 未设置（失败时无法获取详细日志）"
  fi

  if [[ "$MONITOR" != "true" ]]; then
    log "已关闭监控，退出"
    exit 0
  fi

  if should_skip_monitoring; then
    log "跳过监控: $SKIP_REASON"
    exit 0
  fi

  if [[ "$DRY_RUN" == "true" ]]; then
    log "[dry-run] 将执行轮询（10s -> 30s -> 60s...），并输出 run URL 与结论"
    exit 0
  fi

  select_json_mode
  run_monitor_loop
  log "完成"
}

main "$@"
