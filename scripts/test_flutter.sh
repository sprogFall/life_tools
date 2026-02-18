#!/usr/bin/env bash
set -euo pipefail

FLUTTER_BIN="${FLUTTER_BIN:-flutter}"

resolve_os() {
  local uname_s
  uname_s="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$uname_s" in
    msys*|mingw*|cygwin*) echo "windows" ;;
    darwin*) echo "macos" ;;
    *) echo "linux" ;;
  esac
}

prepare_sqlite_linux() {
  local sqlite_so_target="/usr/lib/x86_64-linux-gnu/libsqlite3.so.0"
  local sqlite_so_link="/tmp/libsqlite3.so"

  if [[ ! -e "$sqlite_so_target" ]]; then
    return 0
  fi

  ln -sf "$sqlite_so_target" "$sqlite_so_link"

  local current_ld="${LD_LIBRARY_PATH:-}"
  if [[ -z "$current_ld" ]]; then
    export LD_LIBRARY_PATH="/tmp"
  else
    case ":$current_ld:" in
      *":/tmp:"*) ;;
      *) export LD_LIBRARY_PATH="/tmp:$current_ld" ;;
    esac
  fi
}

main() {
  local os_type
  os_type="$(resolve_os)"

  if [[ "$os_type" == "linux" ]]; then
    prepare_sqlite_linux
  fi

  "$FLUTTER_BIN" test "$@"
}

main "$@"
