#!/usr/bin/env bash
# Phase 4 supplemental: do the v0.53.5 mapper tests catch the simpleeval>=1.0.5 breakage?
# Syncs the v0.53.5 worktree to its locked env (simpleeval 1.0.3), overrides ONLY
# simpleeval to 1.0.8 (still within v0.53.5's declared constraint ">=0.9.13,!=1.0.1",
# i.e. the same state a plain `pip install singer-sdk==0.53.5` resolves to today),
# runs the mapper tests, then restores the locked env.
set -u
BASE="/mnt/c/Projects/oss/meltano-sdk-3520-verification"
OUT="$BASE/.tmp/repro-3520/20261025-02"
UV="$HOME/.local/bin/uv"
PY=/usr/bin/python3.12
WT="/mnt/c/Projects/oss/meltano-sdk-wt-v0.53.5"
mkdir -p "$OUT"

cd "$WT" || exit 1
{
  echo "== worktree: $(git rev-parse HEAD) (tag v0.53.5) =="
  echo "== baseline sync (uv.lock: simpleeval 1.0.3) =="
  "$UV" sync --frozen --group testing --extra faker --python "$PY"
  echo "baseline simpleeval: $(.venv/bin/python -c 'import importlib.metadata as m; print(m.version("simpleeval"))')"
  echo
  echo "== override simpleeval to 1.0.8 (satisfies >=0.9.13,!=1.0.1) =="
  "$UV" pip install --python .venv/bin/python "simpleeval==1.0.8"
  .venv/bin/python -c "import importlib.metadata as m; print('effective simpleeval:', m.version('simpleeval'))"
  "$UV" pip check --python .venv/bin/python || true
  echo
  echo "== pytest tests/core/test_mapper.py (simpleeval 1.0.8) =="
  set +e
  .venv/bin/pytest tests/core/test_mapper.py -q -p no:cacheprovider
  echo "pytest exit: $?"
  set -e
  echo
  echo "== restore locked env =="
  "$UV" sync --frozen --group testing --extra faker --python "$PY"
  .venv/bin/python -c "import importlib.metadata as m; print('restored simpleeval:', m.version('simpleeval'))"
} >"$OUT/phase4-supplemental-v0.53.5-simpleeval-1.0.8.log" 2>&1
echo "supplemental done: $(grep -E 'passed|failed' "$OUT/phase4-supplemental-v0.53.5-simpleeval-1.0.8.log" | tail -1)"
