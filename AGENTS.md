# Agent Instructions

This repository aims for strict Graphviz parity (`dot` / `xdot` / `svg`) using byte-for-byte fixtures.

## Commit Guard Rules (Mandatory)

Before creating **any commit**, run the full local guard and ensure it passes:

```bash
scripts/run_local_guard.sh
```

`scripts/run_local_guard.sh` validates:

- full release MoonBit test suite via `scripts/run_moon_test_full.sh`
  - runs `moon test --target native --release --deny-warn` with `DOT_RUN_FULL_PARITY_TESTS=1`
  - default parallelism auto-detects CPU count (override via `MOON_TEST_JOBS`)
  - includes full snapshot/parity coverage for `dot` / `xdot` / `svg`
- snapshot-input candidate alignment (`scripts/check_snapshot_input_candidates.py`)
- strict parity case-list invariants (`scripts/check_strict_parity_case_lists.py`)
- `DOT_CAPTURE_ORDERING_INPUTS` env-invariance (`dot` / `xdot` / `svg`) on `tests/capture_env_invariant_cases.txt`

Performance/reliability mode:

- guard reuses `_build/local_guard/worktree/_build`, `.mooncakes`, and `refs/graphviz` between runs for faster iterative refactors
- set `LOCAL_GUARD_PRISTINE=1` to force a fully clean worktree build when needed
- set `LOCAL_GUARD_TIMING=1` to print per-step guard timing breakdown
- guard caches last successful result by staged tree hash + `moon --version`; use `LOCAL_GUARD_FORCE=1` to bypass cache
- cache auto-bypasses when `LOCAL_GUARD_PRISTINE=1` or `LOCAL_GUARD_TIMING=1`; set `LOCAL_GUARD_CACHE=0` to disable cache globally
- cache key also includes guard tuning env overrides (`LOCAL_GUARD_FROZEN`, `LOCAL_GUARD_SUBMODULE_CHECK`, `LOCAL_GUARD_SUPPRESS_CLANG_EXIT_WARNING`, `LOCAL_GUARD_SANITIZE_DOT_ENV`, `MOON_TEST_JOBS`, `CAPTURE_ENV_INVARIANCE_JOBS`, `DOT_WRITE_PARITY_ARTIFACTS`)
- guard skips `git submodule update` when worktree `refs/graphviz` already matches staged gitlink (set `LOCAL_GUARD_SUBMODULE_CHECK=0` to always sync)
- guard defaults to `--frozen` for moon commands when `.mooncakes` deps are available, and auto-falls back to non-frozen on failure (set `LOCAL_GUARD_FROZEN=0` to disable)
- guard clears ambient `DOT_*` env vars before running checks (except `DOT_WRITE_PARITY_ARTIFACTS`; set `LOCAL_GUARD_SANITIZE_DOT_ENV=0` to keep caller DOT env)
- parity tests only persist snapshot artifacts for mismatches by default; set `DOT_WRITE_PARITY_ARTIFACTS=1` to force writing all parity outputs under `target/render/*`
- set `CAPTURE_ENV_INVARIANCE_JOBS` to tune env-invariance checker parallelism (defaults to `MOON_TEST_JOBS`)
- guard uses `git -c core.hooksPath=/dev/null` for worktree sync to avoid local hook noise/interference
- guard defaults to `scripts/moon_cc_wrapper.sh` to suppress known generated-C `exit` redeclaration noise (disable via `LOCAL_GUARD_SUPPRESS_CLANG_EXIT_WARNING=0`)
- `scripts/run_local_guard.sh` is intentionally argument-free; tune behavior via `LOCAL_GUARD_*` env vars

If the guard fails:

- do **not** commit
- fix regressions first
- rerun the guard until it passes

## Guard Changes

When changing guard scripts/workflows (`scripts/run_local_guard.sh`, `scripts/run_moon_test_full.sh`, `scripts/check_capture_env_invariance.py`, `scripts/check_strict_parity.py`, `scripts/check_strict_parity_case_lists.py`, `scripts/scan_strict_parity_history.py`, `scripts/find_first_strict_parity_regression.py`, `.github/workflows/*strict-parity*`), also run at least one local smoke command for the changed path.

History/bisect workflow defaults:

- `tests/strict_parity_history_focus_cases.txt` is the default focus file for strict parity history and bisect workflows.
- `tests/strict_parity_known_regression_cases_f9bfd00.txt` is the required known-regression cluster; history focus list must cover it.
- `tests/strict_parity_uncovered_input_cases.txt` lists input-corpus cases intentionally excluded from strict parity manifests.
- keep this list aligned with known high-signal regression clusters.
