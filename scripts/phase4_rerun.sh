#!/usr/bin/env bash
# Phase 4 (rerun): mapper tests with the faker extra included, full logs.
set -u
BASE="/mnt/c/Projects/oss/meltano-sdk-3520-verification"
OUT="$BASE/.tmp/repro-3520/20261025-01/phase4"
UV="$HOME/.local/bin/uv"
PY=/usr/bin/python3.12
mkdir -p "$OUT"

run_tag() {
  local tag="$1" wt="$2"
  cd "/mnt/c/Projects/oss/$wt" || return
  {
    echo "== $tag worktree HEAD: $(git rev-parse HEAD)"
    "$UV" sync --frozen --group testing --extra faker --python "$PY"
    echo "== pytest tests/core/test_mapper.py =="
    .venv/bin/pytest tests/core/test_mapper.py -q -p no:cacheprovider
    echo "== exit: $? =="
    .venv/bin/python -c "import importlib.metadata as m; print('singer-sdk(dist):', m.version('singer-sdk'), '| simpleeval:', m.version('simpleeval'), '| faker:', m.version('faker'))"
  } >"$OUT/$tag-faker.log" 2>&1
  echo "$tag done: $(grep -E 'passed|failed|error' "$OUT/$tag-faker.log" | tail -1)"
}

run_tag v0.53.5 meltano-sdk-wt-v0.53.5
run_tag v0.53.7 meltano-sdk-wt-v0.53.7
run_tag 6d61a40909b9c81d76c14cb8deffa3b619dc7839 meltano-sdk-wt-main-6d61a40
echo "PHASE4-RERUN DONE"
