# Strict Parity Guard

This repository keeps `dot`, `xdot`, and `svg` outputs byte-for-byte aligned
with Graphviz fixtures.

## 1) Full strict check

Run this before landing layout/rendering changes:

```bash
scripts/check_strict_parity.py --formats dot xdot svg
```

What it enforces:

- strict whole-file byte comparison (no fuzzy matching)
- fixture manifest coverage (no extra/missing fixture files)
- manifest alignment between `dot` / `xdot` / `svg`
- optional JSON report output via `--report-json`

## 2) Fast sentinel check

For quick iteration on known fragile cases:

```bash
scripts/check_strict_parity.py --formats dot xdot svg --focus ldbxtried typeshar
```

## 3) History scan for regressions

To locate where regressions entered a commit chain:

```bash
scripts/scan_strict_parity_history.py \
  --good <known-good-commit> \
  --bad <range-end-commit> \
  --formats dot xdot svg
```

Optional fast mode:

```bash
scripts/scan_strict_parity_history.py \
  --good <known-good-commit> \
  --bad <range-end-commit> \
  --formats dot xdot svg \
  --focus ldbxtried typeshar
```

## 4) CI guard

- `.github/workflows/strict-parity.yml` runs on PR/push and enforces:
  - sentinel strict checks (`ldbxtried`, `typeshar`)
  - full strict corpus checks (`dot`/`xdot`/`svg`)
  - uploads a parity report artifact (and mismatch outputs when present)
- `.github/workflows/strict-parity-history.yml` is manual (`workflow_dispatch`)
  and runs commit-range scans using `scripts/scan_strict_parity_history.py`.
- `.github/workflows/strict-parity-bisect.yml` is manual (`workflow_dispatch`)
  and finds the first bad commit using
  `scripts/find_first_strict_parity_regression.py`.

## 5) First bad commit bisect (local)

```bash
scripts/find_first_strict_parity_regression.py \
  --good <known-good-commit> \
  --bad <known-bad-commit> \
  --formats dot xdot svg
```

Optional fast mode:

```bash
scripts/find_first_strict_parity_regression.py \
  --good <known-good-commit> \
  --bad <known-bad-commit> \
  --formats dot xdot svg \
  --focus ldbxtried typeshar
```
