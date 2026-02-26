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

- guard reuses `_build/local_guard/worktree/_build` between runs for faster iterative refactors
- set `LOCAL_GUARD_PRISTINE=1` to force a fully clean worktree build when needed
- guard uses `git -c core.hooksPath=/dev/null` for worktree sync to avoid local hook noise/interference
- guard defaults to `scripts/moon_cc_wrapper.sh` to suppress known generated-C `exit` redeclaration noise (disable via `LOCAL_GUARD_SUPPRESS_CLANG_EXIT_WARNING=0`)

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
