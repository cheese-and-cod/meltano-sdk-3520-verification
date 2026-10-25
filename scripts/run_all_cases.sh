#!/usr/bin/env bash
# Batch runner: executes all remaining verification cases sequentially.
# Variables live inside this file to avoid Windows->WSL quoting issues.
set -u
BASE="/mnt/c/Projects/oss/meltano-sdk-3520-verification"
S="$BASE/scripts/run_case.sh"
T="$BASE/.tmp/repro-3520/20261025-01"

run() {
  local id="$1"; shift
  if [ -f "$T/$id/exit_code.txt" ] && grep -q . "$T/$id/exit_code.txt" 2>/dev/null; then
    echo "SKIP $id (already has exit_code)"
    return
  fi
  bash "$S" "$id" "$@" >/dev/null 2>&1
  echo "$id exit=$(cat "$T/$id/exit_code.txt" 2>/dev/null || echo RUN_FAILED)"
}

run B2a "singer-sdk==0.53.5" "simpleeval==1.0.0"
run B2b "singer-sdk==0.53.5" "simpleeval==1.0.2"
run B4  "singer-sdk==0.53.5" "simpleeval==1.0.4"
run B5  "singer-sdk==0.53.5" "simpleeval==1.0.5"
run C   "singer-sdk==0.53.5" "simpleeval==0.9.13"
run D   "singer-sdk==0.53.7"
run A   "singer-sdk==0.54.9"
run B1  "singer-sdk==0.53.5" "simpleeval==1.0.3"
run B3  "singer-sdk==0.53.5" "simpleeval==1.0.8"
echo "ALL CASES DONE"
