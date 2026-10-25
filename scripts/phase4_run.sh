#!/usr/bin/env bash
# Phase 4: run existing mapper tests at each tag in CI-equivalent locked envs.
# Worktrees are placed under /mnt/c/Projects/oss per the verification plan.
# Logs are saved under $BASE/.tmp/repro-3520/20261025-01/phase4/
set -u
BASE="/mnt/c/Projects/oss/meltano-sdk-3520-verification"
OUT="$BASE/.tmp/repro-3520/20261025-01/phase4"
CLONE="/mnt/c/Projects/oss/meltano-sdk"
UV="$HOME/.local/bin/uv"
PY=/usr/bin/python3.12
mkdir -p "$OUT"

run_tag() {
  local tag="$1" wt="$2"
  if [ ! -d "/mnt/c/Projects/oss/$wt" ]; then
    git -C "$CLONE" worktree add --detach "/mnt/c/Projects/oss/$wt" "$tag" || { echo "$tag worktree FAILED"; return; }
  fi
  cd "/mnt/c/Projects/oss/$wt" || return
  {
    echo "== $tag worktree: $(git -C /mnt/c/Projects/oss/$wt rev-parse HEAD)"
    "$UV" sync --frozen --group testing --python "$PY"
    echo "== pytest =="
    .venv/bin/pytest tests/core/test_mapper.py -q 2>&1 | tail -25
    echo "== versions =="
    .venv/bin/python -c "import importlib.metadata as m; print('singer-sdk(dist):', m.version('singer-sdk')); print('simpleeval:', m.version('simpleeval')); import simpleeval,sys; print('simpleeval file:', simpleeval.__file__); print('python:', sys.version)"
  } >"$OUT/$tag.log" 2>&1
  echo "$tag done: $(grep -E 'passed|failed|error' "$OUT/$tag.log" | tail -1)"
}

run_tag v0.53.5 meltano-sdk-wt-v0.53.5
run_tag v0.53.7 meltano-sdk-wt-v0.53.7
run_tag 6d61a40909b9c81d76c14cb8deffa3b619dc7839 meltano-sdk-wt-main-6d61a40
echo "PHASE4 DONE; logs in $OUT"
