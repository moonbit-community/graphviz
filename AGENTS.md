# Agent Instructions

This repository aims for strict Graphviz parity (`dot` / `xdot` / `svg`) using byte-for-byte fixtures.

## Commit Guard Rules (Mandatory)

Before creating **any commit**, run the full local guard and ensure it passes:

```bash
scripts/run_local_guard.sh
```

`scripts/run_local_guard.sh` validates:

- strict parity sentinel (`ldbxtried`, `typeshar`)
- strict parity full corpus (`dot` / `xdot` / `svg`)

If the guard fails:

- do **not** commit
- fix regressions first
- rerun the guard until it passes

## Guard Changes

When changing guard scripts/workflows (`scripts/check_strict_parity.py`, `scripts/scan_strict_parity_history.py`, `scripts/find_first_strict_parity_regression.py`, `.github/workflows/*strict-parity*`), also run at least one local smoke command for the changed path.
