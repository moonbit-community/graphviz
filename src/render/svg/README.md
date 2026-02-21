This package keeps SVG snapshots pre-generated to avoid expensive MoonBit pre-build steps.

Manual regeneration:
- `bash scripts/generate_svg_snapshots.sh` (requires `dot`).
- `bash scripts/generate_svg_renderer_snapshots.sh` (requires Graphviz `dot`; regenerates `tests/render/svg_snapshot/*.svg` from the fixture filenames).
