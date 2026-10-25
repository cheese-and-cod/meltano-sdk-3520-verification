# meltano/sdk#3520 version-matrix reproduction: results (2026-10-25)

- Date: 2026-10-25 (Asia/Tokyo)
- Environment: WSL2 Ubuntu 24.04.2 / Python 3.12.3 (same patch release for every case, `/usr/bin/python3.12`) / uv 0.13.5 / git 2.43.0 / TZ = Asia/Tokyo
- Upstream clone: `https://github.com/meltano/sdk.git` at HEAD `6d61a40909b9c81d76c14cb8deffa3b619dc7839` (2026-10-23, matched remote `main` at the time)
- Status: all phases complete. Nothing has been posted to the issue and no upstream PR has been opened.
- Artifacts: [`results/20261025-01/`](../results/20261025-01/) (first run: per-case `result.json`, console logs, dependency lists, consistency checks, phase 4 test logs), [`results/20261025-02/`](../results/20261025-02/) (follow-up 2), [`results/20261025-03/`](../results/20261025-03/) (follow-up 3), [`scripts/`](../scripts/) (reproduction scripts and drivers)
- Prepared with AI assistance (GLM-5.3, Claude Opus 5.5); all results come from the scripts and logs in this repository.

## Conclusions (measured)

1. **The expression from the issue works on current releases, as long as the record has no property named `datetime`** (see conclusion 7 for the case where it does). On the latest stable release, singer-sdk **0.54.9** (PyPI, pins `simpleeval==1.0.8`), and on **main @ `6d61a409`** (built as `0.55.0b8.dev5+g6d61a4090`, simpleeval 1.0.8), `datetime.datetime.utcnow().isoformat()` evaluates to an ISO 8601 string (e.g. `2026-10-25T06:10:51.521707`). The inferred schema type `format: date-time` is the same even in failing cases (B3/B5) because it is derived from the expression text, so it is not used as evidence of success. Python 3.12.3 records a `DeprecationWarning` for `utcnow`, which is kept separate from evaluation errors; evaluation itself succeeds.
2. **v0.53.5 with simpleeval >= 1.0.5 reproduces the symptom class.** Every expression using `datetime` or `json` fails. The SDK wraps the exception, so it surfaces as `singer_sdk.exceptions.MapExpressionError`; the root cause is `simpleeval.FeatureNotAvailable: Sorry, modules are not allowed`, because simpleeval 1.0.5 (the CVE-2026-32640 fix) rejects modules and attribute access on them. **This is a different exception from the `simpleeval.AttributeDoesNotExist` quoted in the issue** (see "Open questions").
3. **simpleeval versions published by the report date (2026-03-02), and 1.0.4 published after it, do not reproduce the failure.** v0.53.5 with simpleeval 0.9.13 / 1.0.0 / 1.0.2 / 1.0.3 (all available at report time) and 1.0.4 (published 2026-03-11) passes every expression, including the original one. simpleeval 1.0.1 cannot be installed with v0.53.5 because of its `!=1.0.1` constraint; the full resolution error is saved in [`results/20261025-02/B1p/resolution_error.log`](../results/20261025-02/B1p/resolution_error.log). 1.0.3, the latest at report time, is also the version locked in v0.53.5's own `uv.lock`, so B1 matches upstream CI at the time.
4. **The v0.53.5 + simpleeval 1.0.5+ breakage still applies today.** v0.53.5 declares `simpleeval>=0.9.13,!=1.0.1` with no upper bound, so a fresh install of `singer-sdk==0.53.5` today resolves simpleeval 1.0.8 and `datetime`/`json` expressions fail (case B3). `uv pip check` reports no conflicts: the breakage is a behavior change, not a resolution failure.
5. **v0.53.7 fixes it (measured).** v0.53.7 includes #3595 via the backport #3601 and pins `simpleeval==1.0.7`; every expression passes, including the original one. This matches the upstream sequence under tracking issue #3561: interim pin #3560 on `main` (shipped in v0.53.6 as the backport #3562, `<1.0.5`), then the full fix #3595 (`simpleeval.ModuleWrapper(datetime/json)` plus the evaluator subclass `_MapperEval`).
6. **The existing tests pass on all three versions in a CI-equivalent environment.** `tests/core/test_mapper.py`: v0.53.5 (lock: simpleeval 1.0.3) = 40 passed, v0.53.7 (1.0.7) = 40 passed, main `6d61a409` (1.0.8) = 43 passed, each with `uv sync --frozen --group testing --extra faker`. Tests with `datetime` expressions (`test_map_transforms`, `test_mapped_stream[dates]`, `json_dumps`, etc.) pass everywhere. The first attempt without the faker extra failed two faker-dependent tests on all three versions; the numbers above come from the re-run with the extra (see "Commands and SHAs").
7. **(Follow-up) The exact exception from the issue is reproduced by a name collision, in all five configurations tested.** When the record has a property named `datetime`, the bare name `datetime` resolves to the record value (simpleeval `names`), so `datetime.datetime` becomes attribute access on that value and raises **`simpleeval.AttributeDoesNotExist: Attribute 'datetime' does not exist in expression 'datetime.datetime.utcnow().isoformat()'`, identical to the issue down to the message**. Measured on five configurations: v0.53.5 + 1.0.3 (S1, equivalent to the reporter's environment at the time), 0.54.9 + 1.0.8 (S2, current), main `6d61a409` + 1.0.8 (S3), v0.53.7 + 1.0.7 (S4), v0.53.5 + 1.0.5 (S5). Every SDK version tested is covered by at least one configuration, but not every SDK × simpleeval combination; simpleeval 0.9.13 / 1.0.0 / 1.0.2 / 1.0.4 / 1.0.6 were not run with the collision. This path is outside the scope of #3595 and follows from name-resolution order. The reporter's record shape cannot be confirmed from the issue, so this remains the strongest hypothesis rather than a confirmed cause (open questions 1 and 2).

**Overall:** within the versions and expressions tested, there are two ways `datetime.*` expressions fail, and whether #3520 is already resolved depends on which one the reporter hit.

- **Path 1 (simpleeval 1.0.5+ rejects modules):** occurs on v0.53.5 with simpleeval 1.0.5+, fixed in v0.53.7 and later (#3595). The exception is `FeatureNotAvailable`, which does not match the wording in the issue.
- **Path 2 (record property named `datetime`):** reproduces the `AttributeDoesNotExist` from the issue word for word, in all five configurations measured (S1–S5). Not addressed by #3595.
- The issue body does not say which path applies, so this report does not claim that #3520 was fixed by #3595.

## Case comparison

All cases use [`scripts/repro_mapper_3520.py`](../scripts/repro_mapper_3520.py), which goes through the SDK's real pipeline (`PluginMapper` → `CustomStreamMap.transform()`). A and B1 ran on an earlier revision of the script (see "Script revision"). Every case used the same Python 3.12.3 and its own venv, and every case confirmed that modules were loaded from inside the venv (no shadowing from the working directory).

| Case | singer-sdk | simpleeval (measured) | Source | Original `utcnow` | Year extraction¹ | Controls² | `json.dumps` | Verdict |
|---|---|---|---|---|---|---|---|---|
| A | 0.54.9 (latest stable) | 1.0.8 | PyPI | ✅ | ✅ 2026 | ✅ | ✅ | **All pass** |
| B1 | 0.53.5 | 1.0.3 (latest at report time = v0.53.5 `uv.lock`) | PyPI | ✅ | ✅ | ✅ | ✅ | **All pass** |
| B2a | 0.53.5 | 1.0.0 | PyPI | ✅ | ✅ | ✅ | ✅ | **All pass** |
| B2b | 0.53.5 | 1.0.2 | PyPI | ✅ | ✅ | ✅ | ✅ | **All pass** |
| B4 | 0.53.5 | 1.0.4 | PyPI | ✅ | ✅ | ✅ | ✅ | **All pass** |
| B5 | 0.53.5 | 1.0.5 (CVE-2026-32640 fix) | PyPI | ❌ | ❌ | ✅ | ❌ | **Reproduced** |
| B3 | 0.53.5 | 1.0.8 (current latest) | PyPI | ❌ | ❌ | ✅ | ❌ | **Reproduced** |
| C | 0.53.5 | 0.9.13 | PyPI | ✅ | ✅ | ✅ | ✅ | **All pass** |
| D | 0.53.7 | 1.0.7 (pinned) | PyPI | ✅ | ✅ | ✅ | ✅ | **All pass** |
| E | main `6d61a409` (0.55.0b8.dev5+g6d61a4090) | 1.0.8 | Local clone at fixed SHA | ✅ | ✅ | ✅ | ✅ | **All pass** |

¹ `int(datetime.date.fromisoformat(create_date).year)` with `create_date="2026-04-01"`, asserting 2026.
² A plain field reference `id` and a string method `owner_email.split('@')[1]`. Both pass on B5/B3, which shows that only module exposure breaks, not the evaluator as a whole.

- **B1p (simpleeval 1.0.1) was not run:** `uv pip install` reports the requirements as unsatisfiable because of v0.53.5's `!=1.0.1` constraint. Per the plan, dependency constraints were not bypassed; only the failure was recorded. The full error and exit code 1 are saved in [`results/20261025-02/B1p/resolution_error.log`](../results/20261025-02/B1p/resolution_error.log).
- `uv pip check` reports "All installed packages are compatible" for every case, so the B5/B3 failures are not resolution failures.
- **Script revision:** the `result.json` files for A (15:10) and B1 (15:11) have no `error_chain` key, while B3 (15:13) and later do. A and B1 ran before the exception-chain recording was added. The earlier revision was not saved, so differences other than `error_chain` cannot be ruled out. A2 and B1r, re-run with the current script in [`results/20261025-02/`](../results/20261025-02/), both pass, include `error_chain`, and match the original verdicts and outputs.

## Exceptions and output (representative)

**B3/B5 (v0.53.5 + simpleeval 1.0.5/1.0.8) failure.** Full exception chain from `results/20261025-01/B3/result.json`:

```
singer_sdk.exceptions.MapExpressionError: Failed to evaluate simpleeval expressions datetime.datetime.utcnow().isoformat().
caused by: simpleeval.FeatureNotAvailable: Sorry, modules are not allowed
```

- All three expressions (`datetime.datetime.utcnow().isoformat()`, `int(datetime.date.fromisoformat(create_date).year)`, `json.dumps(user, default=str)`) fail with the same exception.
- Relevant simpleeval 1.0.5 code: `_check_disallowed_items` (`isinstance(item, types.ModuleType)` → `FeatureNotAvailable`) and `_eval_attribute`. `AttributeDoesNotExist` is raised only when an attribute really does not exist, which is a separate path from module rejection. The first run recorded line numbers from the in-venv source, but those venvs have since been cleaned up, so functions are cited by name. For reference, in simpleeval 1.0.8 (main worktree) the module-rejection `FeatureNotAvailable` is at L630 inside `_check_disallowed_items`.
- simpleeval 1.0.3/1.0.4 contain no module-rejection code ("modules are not allowed" appears 0 times; no `ModuleWrapper` or `_check_disallowed_items`), consistent with every case passing on 0.9.13–1.0.4.

**A/D/E (current and fixed versions) success.** Output of the original expression:

```
issue_original_utcnow: '2026-10-25T06:10:51.521707'  (inferred type: {'type': ['string','null'], 'format': 'date-time'})
  warning: DeprecationWarning: datetime.datetime.utcnow() is deprecated ... Use timezone-aware objects ... datetime.datetime.now(datetime.UTC).
issue_example_year: 2026
helper_json_dumps: '{"name": "Alice", "age": 30}'
```

## Follow-up runs (2 and 3)

Review findings that could be resolved by measuring were re-run. Follow-up 2 artifacts: [`results/20261025-02/`](../results/20261025-02/) (see `SOURCE-NOTE.md` there for output paths). Follow-up 3 artifacts: [`results/20261025-03/`](../results/20261025-03/).

| Finding | Action | Result |
|---|---|---|
| A and B1 ran on the earlier script | Re-ran as A2 and B1r with the current script | Both pass; verdicts and outputs match A and B1; `result.json` includes `error_chain` |
| No evidence log for B1p (1.0.1) | Re-ran the same install and saved the error | "requirements are unsatisfiable" and exit code 1 recorded in full (`B1p/resolution_error.log`) |
| Install command for case E not recorded | Fixed the command string and re-ran it as E2 | All pass. The command is in "Commands and SHAs" and in `scripts/run_followup_cases.sh`; `console.log` contains only the script output, and the built version is in `E2/pip_list.txt` |
| Actual scope of `run_all_cases.sh` | Record corrected only (6 cases actually ran) | No re-run needed |
| Name-collision hypothesis not measured | Measured as S1/S2 (follow-up 2) and S3/S4/S5 (follow-up 3) | **The exact exception from the issue reproduces in all five configurations** |
| Could the v0.53.5 tests detect the breakage? | Ran the v0.53.5 tests with only simpleeval changed to 1.0.8 | **4 failures** (`test_map_transforms`, `test_mapped_stream[dates]`, `test_mapped_stream[json_dumps]`, `test_bench_simple_map_transforms`): the existing tests can detect it. The environment was restored to 1.0.3 per `uv.lock` afterwards (`phase4/phase4-supplemental-*.log`) |

### Name collision (S1–S5)

`--shadow-datetime-field` was added to the reproduction script. It only adds the string `datetime = "2026-04-01"` to the record (and schema); everything else matches the first run. The same five expressions were evaluated.

| Case | singer-sdk | simpleeval | Original `utcnow` | Year extraction | 2 controls | `json.dumps` |
|---|---|---|---|---|---|---|
| S1 | 0.53.5 | 1.0.3 (reporter-era) | ❌ `AttributeDoesNotExist` | ❌ `Attribute 'date' does not exist` | ✅ | ✅ |
| S2 | 0.54.9 | 1.0.8 (current) | ❌ `AttributeDoesNotExist` (message identical to the issue) | ❌ same | ✅ | ✅ |
| S3 | main `6d61a409` (0.55.0b8.dev5+g6d61a4090) | 1.0.8 | ❌ same | ❌ same | ✅ | ✅ |
| S4 | 0.53.7 | 1.0.7 | ❌ same | ❌ same | ✅ | ✅ |
| S5 | 0.53.5 | 1.0.5 | ❌ same | ❌ same | ✅ | ❌ `FeatureNotAvailable` (non-shadowed helper hits module rejection) |

- In every configuration (S1–S5) the original expression raises `simpleeval.AttributeDoesNotExist: Attribute 'datetime' does not exist in expression 'datetime.datetime.utcnow().isoformat()'`, wrapped in the SDK's `MapExpressionError`: **the same exception, message and expression as in #3520.**
- Mechanism: simpleeval resolves bare names from `names` (the record values) before falling back to `functions`. If `datetime` is a record property it resolves to a string, and `datetime.datetime` becomes attribute access on that string. The resolution order is the same in all five configurations measured (not every SDK × simpleeval combination was run). `docs/stream_maps.md` notes that property names can collide with built-in functions and suggests `record['...']` to reach the property; that is a way to read the property value, not a way to reach the shadowed helper module.
- **S5 (v0.53.5 + 1.0.5 + collision):** when both conditions hold, `datetime` expressions hit the collision first and produce the issue's exact `AttributeDoesNotExist`, while the non-shadowed helper (`json.dumps`) fails with `FeatureNotAvailable`. So even on simpleeval 1.0.5+, a `datetime` property yields the error text from the issue.
- Implications: (a) with any simpleeval available on the report date, a `datetime` property produces the issue's exception; it is the only reproduced path that needs no assumption about dependency versions. (b) #3595 does not change this path, and the behavior is the same in all five configurations. The reporter's record shape is not in the issue, so this is not a confirmed cause.

## Minimal repro (for the issue comment)

[`scripts/minimal_repro_3520.py`](../scripts/minimal_repro_3520.py) evaluates the original expression with and without a `datetime` property. Run on 2026-10-25 on native Windows with uv-managed Python 3.12:

```
uv run --no-project --python 3.12 --with singer-sdk==<version> python -W ignore::DeprecationWarning minimal_repro_3520.py
```

| singer-sdk | simpleeval resolved | Without `datetime` property | With `datetime` property |
|---|---|---|---|
| 0.54.9 | 1.0.8 | Succeeds (ISO 8601 string) | `AttributeDoesNotExist` (matches the issue) |
| 0.53.5 | 1.0.8 | `FeatureNotAvailable` | `AttributeDoesNotExist` (matches the issue) |

## Commands and SHAs

Summary of the procedure (full details in `results/20261025-01/<case>/console.log` and `pip_list.txt`):

```bash
# WSL2 Ubuntu 24.04.2 / uv 0.13.5 (~/.local/bin)
# Single case (example: B1)
bash scripts/run_case.sh B1 "singer-sdk==0.53.5" "simpleeval==1.0.3"
# Batch run (A/B1/B2a/B2b/B3/B4/B5/C/D; E is not included)
bash scripts/run_all_cases.sh
# Case E (main at a fixed SHA): the exact first-run command was not recorded, so it was re-run as E2 with this command (all pass)
#   (results/20261025-02/E2/; simpleeval==1.0.8 matches main's pyproject pin)
bash scripts/run_case.sh E2 "singer-sdk @ git+file:///mnt/c/Projects/oss/meltano-sdk@6d61a40909b9c81d76c14cb8deffa3b619dc7839" "simpleeval==1.0.8"
# Follow-up 2 (A2/B1r/E2/S1/S2, B1p evidence log)
bash scripts/run_followup_cases.sh   # note: the first run did not export RUN_ID, so .tmp output went to 20261025-01 (see SOURCE-NOTE.md)
# Follow-up 3 (S3/S4/S5: three more name-collision configurations)
bash scripts/run_followup3_cases.sh
# Single name-collision case: REPRO_ARGS="--shadow-datetime-field" bash scripts/run_case.sh <ID> <spec...>
# Phase 4 (existing tests, CI-equivalent environment pinned by uv.lock)
bash scripts/phase4_run.sh           # create worktrees + first run (uv sync --frozen --group testing, no faker extra)
bash scripts/phase4_rerun.sh         # re-run in the existing worktrees with --extra faker (requires phase4_run.sh first)
bash scripts/phase4_supplemental.sh  # v0.53.5 tests with simpleeval 1.0.8 to check detection (restored to 1.0.3 afterwards)
```

- `run_all_cases.sh` skips cases that already have `exit_code.txt`. A, B1 and B3 had been run individually, so the batch actually ran B2a/B2b/B4/B5/C/D (consistent with the timestamps in each `result.json`).
- Reproduction script: `scripts/repro_mapper_3520.py` uses `PluginMapper` / `register_raw_stream_schema` / `transform`, the same API as `tests/core/test_mapper.py::_run_transform` in both v0.53.5 and main (no API differences between versions).
- SHAs: v0.53.5 = `a6fdc6a7567cac474d1f1c9b0cd715e708c09689`, v0.53.6 = `72f20411cf0721ad2abe529042d793380b44d73b`, v0.53.7 = `a520f7cc5e1715d911ad1d553e7e91e96e32698e`, v0.54.9 = `5abb8117997f20299a953ced30d918a0be1bf735`, main = `6d61a40909b9c81d76c14cb8deffa3b619dc7839`
- Cases A–D and the B group install PyPI distributions by version. Case E builds from the local clone via `git+file://…@6d61a409…` (uv generates version `0.55.0b8.dev5+g6d61a4090`).
- Worktrees for phase 4: `meltano-sdk-wt-v0.53.5`, `meltano-sdk-wt-v0.53.7`, `meltano-sdk-wt-main-6d61a40`, next to the upstream clone (`--frozen`, following each tag's `uv.lock`).
- Phase 4 first run (`phase4/<tag>.log`, no faker extra): `test_mapped_stream[fake_credit_card_number]` and `test_mapped_stream[fake_email_seed_instance]` failed on all three versions (v0.53.5 and v0.53.7 = 2 failed, 38 passed; main = 2 failed, 41 passed). `phase4_run.sh` truncated pytest output to the last 25 lines, so the failure reasons are not in the logs. Both tests passed in the re-run with the faker extra (`phase4/<tag>-faker.log`), so the failures were attributed to the missing faker install (unrelated to #3520). Re-run results: v0.53.5 and v0.53.7 = 40 passed, 3 warnings; main = 43 passed. The three warnings are `SingerSDKDeprecationWarning` on imports in `tests/conftest.py`, unrelated to mapper evaluation.

### Dependency constraints (checked in the clone)

| Version | requires-python | simpleeval in `pyproject.toml` | simpleeval in `uv.lock` |
|---|---|---|---|
| v0.53.5 | >=3.10 | `>=0.9.13,!=1.0.1` (no upper bound) | 1.0.3 |
| v0.53.6 | >=3.10 | `>=0.9.13,!=1.0.1,<1.0.5` | 1.0.3 |
| v0.53.7 | >=3.10 | `==1.0.7` | 1.0.7 |
| v0.54.0 | >=3.10 | `==1.0.7` | 1.0.7 |
| v0.54.9 | >=3.10 | `==1.0.8` | 1.0.8 |
| main `6d61a409` | >=3.10 | `==1.0.8` | 1.0.8 |

simpleeval release dates (PyPI): 0.9.13 = 2023-02-17, 1.0.0 = 2024-10-05, 1.0.1 = 2024-10-28, 1.0.2 = 2024-10-31, 1.0.3 = 2024-11-02, 1.0.4 = 2026-03-11, **1.0.5 = 2026-03-13**, 1.0.6 = 2026-03-13, 1.0.7 = 2026-03-16, 1.0.8 = 2026-09-12. The latest release on the report date (2026-03-02) was **1.0.3**.

## What #3595 changed

- PR #3595 (merged 2026-04-14, merge commit `aff5fc25efcd21159887bd454f343b65e7412c87`) touches **three files only: `pyproject.toml` (pin to `simpleeval==1.0.7`), `singer_sdk/mapper.py` (+78/−4) and `uv.lock`. It adds no tests** (checked via the files API). The `datetime` expressions in `test_mapper.py` (`create_year`, the `dates` parameter) predate #3595 (2022-11 / 2024-11).
- `mapper.py` changes (main): `funcs["datetime"] = simpleeval.ModuleWrapper(datetime)` and `funcs["json"] = simpleeval.ModuleWrapper(json)` (v0.53.5 stored the raw modules), and evaluation moved to `_MapperEval(simpleeval.EvalWithCompoundTypes)`, which overrides `_check_disallowed_items` to skip simpleeval 1.0.5+'s per-node check and enforces safety at the name-resolution boundary instead.
- **main differs from v0.54.9 in `mapper.py`** (113 lines: `uuid4`/`check_uuid` functions, lazy imports, type annotations; the `ModuleWrapper`/`_MapperEval` evaluation logic is unchanged), which is why case E (main at a fixed SHA) was added. Result: all pass.
- The PR description contains two Sourcery-generated summaries (relax to `>=1.0.5` / pin to `1.0.7`). The actual diff pins `simpleeval==1.0.7`. The pin to 1.0.8 came later (v0.54.6 onwards; 1.0.8 was published 2026-09-12).

## Sources

- Issue [#3520](https://github.com/meltano/sdk/issues/3520) (open, 0 comments, not updated since 2026-03-02; body: singer-sdk 0.53.5 / Python 3.12 / no simpleeval version; error `simpleeval.AttributeDoesNotExist: Attribute 'datetime' does not exist in expression 'datetime.datetime.utcnow().isoformat()'`)
- PR [#3595](https://github.com/meltano/sdk/pull/3595) (merged 2026-04-14) / backport PR [#3601](https://github.com/meltano/sdk/pull/3601) → [v0.53.7](https://github.com/meltano/sdk/releases/tag/v0.53.7) (2026-04-15) / interim pin PR [#3560](https://github.com/meltano/sdk/pull/3560) (`main`) and its backport [#3562](https://github.com/meltano/sdk/pull/3562) → v0.53.6 (2026-03-13) / tracking issue [#3561](https://github.com/meltano/sdk/issues/3561)
- Releases: v0.53.5 (2026-01-06), v0.54.9 (2026-10-19, latest stable = `/releases/latest`)
- Code: `singer_sdk/mapper.py` (v0.53.5, main `6d61a409`), `tests/core/test_mapper.py` (same), `simpleeval.py` from simpleeval 1.0.3/1.0.4/1.0.5 (the copies installed in each case venv)
- CVE-2026-32640 / [GHSA-44vg-5wv2-h2hg](https://github.com/advisories/GHSA-44vg-5wv2-h2hg) (fixed in simpleeval 1.0.5)
- PyPI metadata for [singer-sdk](https://pypi.org/project/singer-sdk/) and [simpleeval](https://pypi.org/project/simpleeval/) (release dates, `requires_dist`)

## Open questions (outside the conclusions)

1. **The reporter's exact environment.** The only reproduced path that matches the issue's `AttributeDoesNotExist` word for word is a record property named `datetime` (S1–S5, including the reporter-era and current configurations). simpleeval 1.0.5+'s module rejection raises `FeatureNotAvailable` with a different message, so it does not directly explain the quoted exception. The issue does not state the record shape or the simpleeval version, so which path the reporter hit is still unknown.
2. The reporter might have used a pre-release or git build of simpleeval, or hit another path. Not tested, and not distinguishable from the issue text.
3. Behavior on Python other than 3.12.3 (3.10/3.11/3.13+) and on native Windows/macOS was not tested in the matrix (the issue reports Python 3.12). Only the minimal repro was also run on native Windows.
4. The current CI status of upstream `main` was not checked (`tests/core/test_mapper.py` passed locally on all three versions).
5. `nox -s tests` (full core + cookiecutter) was not run; the scope was limited to the mapper tests as planned.
6. Whether the v0.53.5 tests could detect the simpleeval 1.0.5+ breakage: **resolved in follow-up 2.** With only simpleeval changed to 1.0.8 in the v0.53.5 test environment (faker extra included, otherwise per `uv.lock`), four tests with `datetime`/`json` expressions failed (4 failed, 36 passed; `results/20261025-02/phase4/`). 1.0.8 satisfies v0.53.5's constraints, so this is not a forced install. Before 1.0.5 (2026-03-13) CI had nothing to detect; after it, refreshing the lock would have surfaced the breakage in CI. The environment was restored to 1.0.3 afterwards.

## Mechanism summary

- simpleeval has two namespaces, `functions` (name → callable) and `names` (name → value); bare names resolve from `names` first and then fall back to `functions`.
- v0.53.5 exposed the raw `datetime`/`json` modules in `functions` and had no upper bound on simpleeval. simpleeval 1.0.5 (CVE-2026-32640, released 2026-03-13) rejects modules and attribute access on them, so fresh installs broke from then on.
- #3595 places `simpleeval.ModuleWrapper`-wrapped modules in `functions`, evaluates with the `_MapperEval` subclass, and pins `simpleeval==1.0.7` (later 1.0.8). It ships in v0.53.7 and later.
- Measured: the original expression works on 0.54.9, v0.53.7 and main, and fails only on v0.53.5 with simpleeval 1.0.5+ (`FeatureNotAvailable`). The exception quoted in the issue (`AttributeDoesNotExist`) reproduces word for word with a `datetime` record property in all five configurations measured (S1–S5). #3595 does not address that path.
- Name collision: record values in `names` take precedence over SDK helpers in `functions`. A record key that matches a helper name (`datetime`, `json`, etc.) shadows the helper in all five configurations measured, and when both problems are present the collision wins (S5).
- `utcnow` is deprecated since Python 3.12 (`DeprecationWarning`) but still evaluates. The replacement is `datetime.datetime.now(datetime.UTC)`.

The issue comment draft is in [comment-draft-3520.md](comment-draft-3520.md).
