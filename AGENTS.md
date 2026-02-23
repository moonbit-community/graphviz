# Agent Instructions

This repository aims for strict Graphviz parity (`dot` / `xdot` / `svg`) using byte-for-byte fixtures.

## Commit Guard Rules (Mandatory)

Before creating **any commit**, run the full local guard and ensure it passes:

```bash
scripts/run_local_guard.sh
```

`scripts/run_local_guard.sh` validates:

- `DOT_CAPTURE_ORDERING_INPUTS` env-invariance (`dot` / `xdot` / `svg`) on `tests/capture_env_invariant_cases.txt`
- ordering-input fixture parity (`plugins` root/remincross capture path)
- trapezium SVG shape invariant (polygon-only node families)
- strict parity case-list invariants (`scripts/check_strict_parity_case_lists.py`)
- strict parity sentinel list (`tests/strict_parity_sentinel_cases.txt`)
- strict parity history focus list (`tests/strict_parity_history_focus_cases.txt`)
- strict parity full corpus (`dot` / `xdot` / `svg`)

If the guard fails:

- do **not** commit
- fix regressions first
- rerun the guard until it passes

## Guard Changes

When changing guard scripts/workflows (`scripts/check_strict_parity.py`, `scripts/check_strict_parity_case_lists.py`, `scripts/scan_strict_parity_history.py`, `scripts/find_first_strict_parity_regression.py`, `.github/workflows/*strict-parity*`), also run at least one local smoke command for the changed path.

History/bisect workflow defaults:

- `tests/strict_parity_history_focus_cases.txt` is the default focus file for strict parity history and bisect workflows.
- `tests/strict_parity_known_regression_cases_f9bfd00.txt` is the required known-regression cluster; history focus list must cover it.
- `tests/strict_parity_uncovered_input_cases.txt` lists input-corpus cases intentionally excluded from strict parity manifests.
- keep this list aligned with known high-signal regression clusters.
