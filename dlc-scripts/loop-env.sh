#!/usr/bin/env bash

loop_env_get() {
  local key="${1:-}"
  local file="${2:-.loop-env}"

  [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || return 2
  [[ -f "$file" ]] || return 0

  awk -v key="$key" 'index($0, key "=") == 1 { value = substr($0, length(key) + 2); found = 1 } END { if (found) print value }' "$file"
}