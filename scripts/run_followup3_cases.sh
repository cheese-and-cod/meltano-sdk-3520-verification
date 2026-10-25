#!/usr/bin/env bash
# Follow-up round 3 (2026-10-25): close the shadowing-generalization gap from the
# second review. The name-shadowing behavior was only measured on
# v0.53.5+1.0.3 (S1) and 0.54.9+1.0.8 (S2). Measure the remaining configs:
#   S3 - main @ fixed SHA + simpleeval 1.0.8 + shadow
#   S4 - v0.53.7 + simpleeval 1.0.7 + shadow
#   S5 - v0.53.5 + simpleeval 1.0.5 + shadow  (which error wins: shadow or module check?)
set -u
BASE="/mnt/c/Projects/oss/meltano-sdk-3520-verification"
export RUN_ID="20261025-03"
S="$BASE/scripts/run_case.sh"

REPRO_ARGS="--shadow-datetime-field" bash "$S" S3 \
  "singer-sdk @ git+file:///mnt/c/Projects/oss/meltano-sdk@6d61a40909b9c81d76c14cb8deffa3b619dc7839" \
  "simpleeval==1.0.8"
REPRO_ARGS="--shadow-datetime-field" bash "$S" S4 "singer-sdk==0.53.7"
REPRO_ARGS="--shadow-datetime-field" bash "$S" S5 "singer-sdk==0.53.5" "simpleeval==1.0.5"

echo "FOLLOWUP3 CASES DONE (run id $RUN_ID)"
