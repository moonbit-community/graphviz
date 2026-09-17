This package keeps xdot snapshots pre-generated to avoid expensive MoonBit pre-build steps.

Manual regeneration:
- `bash scripts/generate_xdot_snapshots.sh` (requires Graphviz `dot`; regenerates `tests/render/xdot/*.xdot` from `tests/render/xdot/cases.txt`).
