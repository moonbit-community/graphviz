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
