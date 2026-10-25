#!/usr/bin/env bash
# Case runner for meltano/sdk #3520 verification.
# Usage: run_case.sh <CASE_ID> <uv-pip-install-spec...>
# Creates .tmp/repro-3520/<RUN_ID>/<CASE_ID>/.venv, installs the given specs,
# records the dependency list and consistency check, then runs the repro script.
set -euo pipefail

CASE_ID="$1"; shift
BASE="/mnt/c/Projects/oss/meltano-sdk-3520-verification"
RUN_ID="${RUN_ID:-20261025-01}"
CASE_DIR="$BASE/.tmp/repro-3520/$RUN_ID/$CASE_ID"
PY=/usr/bin/python3.12
UV="$HOME/.local/bin/uv"

mkdir -p "$CASE_DIR"
cd "$CASE_DIR"

echo "== venv =="
"$UV" venv --clear --python "$PY" .venv
VP="$CASE_DIR/.venv/bin/python"

echo "== install: $* =="
"$UV" pip install --python "$VP" "$@"
"$UV" pip list --python "$VP" >"$CASE_DIR/pip_list.txt"
"$UV" pip check --python "$VP" >"$CASE_DIR/pip_check.txt" 2>&1 || true
"$VP" -c "import importlib.metadata as m; d=m.distribution('singer-sdk'); print('\n'.join(sorted(f'{r}' for r in d.requires if r)))" >"$CASE_DIR/singer_sdk_requires.txt" 2>&1 || true

echo "== run repro (cwd: $CASE_DIR) =="
set +e
# shellcheck disable=SC2086  # REPRO_ARGS is intentionally word-split repro args
"$VP" "$BASE/scripts/repro_mapper_3520.py" --out "$CASE_DIR/result.json" ${REPRO_ARGS:-} 2>&1 | tee "$CASE_DIR/console.log"
RC=${PIPESTATUS[0]}
set -e
echo "$RC" >"$CASE_DIR/exit_code.txt"
echo "CASE $CASE_ID exit=$RC"
