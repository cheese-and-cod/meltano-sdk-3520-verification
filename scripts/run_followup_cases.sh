#!/usr/bin/env bash
# Follow-up runs addressing the 2026-10-25 review findings.
# Run ID 20261025-02; results copied to results/20261025-02/.
#
# Cases:
#   A2  - singer-sdk 0.54.9, current script (with error_chain) rerun
#   B1r - singer-sdk 0.53.5 + simpleeval 1.0.3, current script rerun
#   E2  - main @ fixed SHA from the local clone, command string recorded below
#   S1  - 0.53.5 + 1.0.3 with --shadow-datetime-field (name-shadowing hypothesis)
#   S2  - 0.54.9 + 1.0.8 with --shadow-datetime-field
#   B1p - capture the resolver refusal for simpleeval 1.0.1 (no install)
set -u
BASE="/mnt/c/Projects/oss/meltano-sdk-3520-verification"
# NOTE: must be exported -- run_case.sh reads it as an env var. The first
# follow-up run (2026-10-25) omitted the export, so case outputs landed under
# .tmp/repro-3520/20261025-01/ while the B1p log below used $T directly and
# landed under 20261025-02/. See results/20261025-02/SOURCE-NOTE.md.
export RUN_ID="20261025-02"
S="$BASE/scripts/run_case.sh"
T="$BASE/.tmp/repro-3520/$RUN_ID"
UV="$HOME/.local/bin/uv"
PY=/usr/bin/python3.12

REPRO_ARGS="" bash "$S" A2 "singer-sdk==0.54.9"
REPRO_ARGS="" bash "$S" B1r "singer-sdk==0.53.5" "simpleeval==1.0.3"
REPRO_ARGS="" bash "$S" E2 \
  "singer-sdk @ git+file:///mnt/c/Projects/oss/meltano-sdk@6d61a40909b9c81d76c14cb8deffa3b619dc7839" \
  "simpleeval==1.0.8"
REPRO_ARGS="--shadow-datetime-field" bash "$S" S1 "singer-sdk==0.53.5" "simpleeval==1.0.3"
REPRO_ARGS="--shadow-datetime-field" bash "$S" S2 "singer-sdk==0.54.9"

# B1p: record the dependency-resolution refusal for simpleeval 1.0.1 (evidence log only)
mkdir -p "$T/B1p"
{
  echo "# Command attempted (WSL2 Ubuntu, uv $("$UV" --version 2>/dev/null | awk '{print $2}')):"
  echo 'uv venv --clear --python /usr/bin/python3.12 .venv'
  echo 'uv pip install --python .venv/bin/python "singer-sdk==0.53.5" "simpleeval==1.0.1"'
  echo
  cd "$T/B1p" || exit 1
  "$UV" venv --clear --python "$PY" .venv
  set +e
  "$UV" pip install --python "$T/B1p/.venv/bin/python" "singer-sdk==0.53.5" "simpleeval==1.0.1"
  echo "installer exit code: $?"
  set -e
} >"$T/B1p/resolution_error.log" 2>&1
echo "B1p resolution_error.log captured (exit recorded inside log)"

echo "FOLLOWUP CASES DONE (run id $RUN_ID)"
