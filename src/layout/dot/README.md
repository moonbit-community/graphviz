This package uses pre-generated assets to avoid expensive MoonBit pre-build steps.

Manual regeneration:
- `bash scripts/generate_font_metrics.sh` (updates `src/layout/dot/font_metrics.generated.mbt` with text widths + kerning; requires `dot` and `python3`).
- `bash scripts/generate_dot_snapshots.sh` (refreshes `tests/layout/dot/*.gv.dot`; requires `dot`).
