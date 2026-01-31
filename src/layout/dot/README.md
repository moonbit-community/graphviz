This package uses pre-generated assets to avoid expensive MoonBit pre-build steps.

Manual regeneration:
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_font_metrics.sh` (updates `src/layout/dot/font_metrics/font_metrics.generated.mbt` with text widths + kerning; requires Graphviz build + `python3`).
- `bash scripts/generate_textspan_fixtures_from_xdot.sh` (updates `tests/fixtures/graphviz/textspan.jsonl` from xdot snapshots; requires `python3`).
- `bash scripts/generate_textspan_overrides.sh` (updates `src/layout/dot/font_metrics/textspan_overrides.generated.mbt` from `tests/fixtures/graphviz/textspan.jsonl`).
- `bash scripts/generate_dot_snapshots.sh` (refreshes `tests/layout/dot/*.gv.dot`; requires `dot`).

Integration tests are currently skipped (via `#skip`) while unit-level Graphviz
fixtures are built and parity is restored. Re-enable once fixture tasks land:
- `src/render/svg/svg_test.mbt`
- `src/render/svg/svg_wbtest.mbt`
- `src/render/xdot/xdot_wbtest.mbt`
- `src/render/xdot/snapshot_test.mbt`
- `src/layout/dot/complex_test.mbt`
- `src/layout/dot/snapshot_test.mbt`
- `src/layout/dot/neato_test.mbt`
