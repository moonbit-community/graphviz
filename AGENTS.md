# Agent Instructions

This repository aims for strict Graphviz parity (`dot` / `xdot` / `svg`) using byte-for-byte fixtures.

## Commit Guard Rules (Mandatory)

Before creating **any commit**, run the full local guard and ensure it passes:

```bash
scripts/run_local_guard.sh
```

`scripts/run_local_guard.sh` validates:

- ordering-input fixture parity (`plugins` root/remincross capture path)
- trapezium SVG shape invariant (polygon-only node families)
- strict parity sentinel list (`tests/strict_parity_sentinel_cases.txt`)
- strict parity full corpus (`dot` / `xdot` / `svg`)

If the guard fails:

- do **not** commit
- fix regressions first
- rerun the guard until it passes

## Guard Changes

When changing guard scripts/workflows (`scripts/check_strict_parity.py`, `scripts/scan_strict_parity_history.py`, `scripts/find_first_strict_parity_regression.py`, `.github/workflows/*strict-parity*`), also run at least one local smoke command for the changed path.

History/bisect workflow defaults:

- `tests/strict_parity_history_focus_cases.txt` is the default focus file for strict parity history and bisect workflows.
- keep this list aligned with known high-signal regression clusters.
