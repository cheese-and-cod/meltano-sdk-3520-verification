# Where results/20261025-02 came from

- Run date: 2026-10-25 (follow-up runs addressing review findings; see "Follow-up runs" in [docs/verification-results-2026-10-25.md](../../docs/verification-results-2026-10-25.md))
- Scripts: `scripts/run_followup_cases.sh`, `scripts/phase4_supplemental.sh`, `scripts/repro_mapper_3520.py` (the version with `--shadow-datetime-field`)
- Environment: same as the first run (`results/20261025-01/`). WSL2 Ubuntu 24.04.2 / Python 3.12.3 / uv 0.13.5 / TZ Asia/Tokyo

## Note on output paths

The first run of `run_followup_cases.sh` did not export `RUN_ID`, so output went to unintended locations:

- A2, B1r, E2, S1, S2 → `.tmp/repro-3520/20261025-01/<case>/` (intended: `20261025-02`)
- B1p (resolution error log) and the phase 4 supplemental log → `.tmp/repro-3520/20261025-02/` (the script set `$T` directly)

Every file in this directory was copied from those locations; `meta.argv` in `result.json` and the contents of `console.log` are as recorded at run time. The script now exports `RUN_ID`, so re-runs write everything under `20261025-02`.
