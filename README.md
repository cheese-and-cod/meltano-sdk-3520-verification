# meltano/sdk#3520 version-matrix reproduction

Reproduces [meltano/sdk#3520](https://github.com/meltano/sdk/issues/3520) (stream map expressions such as `datetime.datetime.utcnow().isoformat()` failing with `simpleeval.AttributeDoesNotExist`) across singer-sdk and simpleeval versions. What was confirmed is kept apart from what is still unknown; the report does not assume the issue can be closed.

## Findings

- The expression from the issue works on singer-sdk **0.53.7, 0.54.9 and main (`6d61a409`)** when the record has no property named `datetime` (only Python 3.12's `DeprecationWarning` for `utcnow`).
- **v0.53.5 with simpleeval >= 1.0.5** fails with `FeatureNotAvailable: Sorry, modules are not allowed`. v0.53.5 has no upper bound on simpleeval, so fresh installs pick this up. Fixed by [#3595](https://github.com/meltano/sdk/pull/3595) (0.53.7 and 0.54.0+).
- The **exact exception from the issue** (`AttributeDoesNotExist: Attribute 'datetime' does not exist ...`) reproduces when the record has a **property named `datetime`**, which shadows the SDK's `datetime` helper. This happened in all five configurations tested, including the latest release and main, and #3595 does not change it.
- The issue does not say which case the reporter hit, so this repository does not claim #3520 is resolved.

Details, the full case table and open questions: [docs/verification-results-2026-10-25.md](docs/verification-results-2026-10-25.md). Draft comment for the issue: [docs/comment-draft-3520.md](docs/comment-draft-3520.md).

## Minimal repro

```bash
cd scripts
uv run --no-project --python 3.12 --with singer-sdk==0.54.9 python minimal_repro_3520.py
```

[`scripts/minimal_repro_3520.py`](scripts/minimal_repro_3520.py) evaluates the original expression through `PluginMapper` with and without a `datetime` property. On 0.54.9 the first run succeeds and the second raises the issue's `AttributeDoesNotExist`. Replace the version with `0.53.5` to see the separate `FeatureNotAvailable` failure.

## Full version matrix

Environment used: WSL2 Ubuntu 24.04.2, Python 3.12.3 (same for every case), uv 0.13.5, with an upstream clone of `meltano/sdk` at `6d61a409` next to this repository (`../meltano-sdk`). Run inside WSL:

```bash
# One case: case ID, then package specs. Output goes to .tmp/repro-3520/<RUN_ID>/<case>/ (git-ignored)
bash scripts/run_case.sh B1 "singer-sdk==0.53.5" "simpleeval==1.0.3"

# Cases A/B1/B2a/B2b/B3/B4/B5/C/D (cases that already have exit_code.txt are skipped)
bash scripts/run_all_cases.sh

# Case E2: main at a fixed SHA, built from the local clone
bash scripts/run_case.sh E2 "singer-sdk @ git+file:///mnt/c/Projects/oss/meltano-sdk@6d61a40909b9c81d76c14cb8deffa3b619dc7839" "simpleeval==1.0.8"

# Follow-up runs (A2/B1r/E2/S1/S2 and the B1p resolution log; then S3/S4/S5)
bash scripts/run_followup_cases.sh
bash scripts/run_followup3_cases.sh

# Name-collision variant of any case
REPRO_ARGS="--shadow-datetime-field" bash scripts/run_case.sh <ID> <spec...>

# Summarize results
python scripts/summarize_results.py results/20261025-01/*/result.json

# Existing mapper tests on v0.53.5 / v0.53.7 / main, pinned by each tag's uv.lock
bash scripts/phase4_run.sh           # creates worktrees and runs without the faker extra (2 faker tests fail)
bash scripts/phase4_rerun.sh         # re-runs with --extra faker (numbers in the report come from this)
bash scripts/phase4_supplemental.sh  # v0.53.5 tests with simpleeval 1.0.8, then restores uv.lock versions
```

[`scripts/repro_mapper_3520.py`](scripts/repro_mapper_3520.py) runs five expressions (the original, year extraction, two controls and `json.dumps`) one at a time through `PluginMapper` → `CustomStreamMap.transform`. It records warnings without suppressing them and keeps both the SDK's `MapExpressionError` and the underlying simpleeval exception. `--shadow-datetime-field` adds a `datetime` property to the record.

## Layout

| Path | Contents |
|---|---|
| `docs/verification-results-2026-10-25.md` | Full report: conclusions, case tables, exceptions, commands, SHAs, sources, open questions |
| `docs/comment-draft-3520.md` | Comment to post on the issue, with the reasoning behind it and next steps |
| `scripts/` | Reproduction scripts and run drivers |
| `results/20261025-01/` | First run: per-case `result.json`, console logs, dependency lists, `pip check`, phase 4 test logs |
| `results/20261025-02/` | Follow-up 2: A2/B1r/E2, name collision S1/S2, B1p resolution log, phase 4 supplemental log |
| `results/20261025-03/` | Follow-up 3: name collision S3/S4/S5 |

`.tmp/` holds disposable venvs and raw run output and is not committed; the kept results were copied into `results/`.
