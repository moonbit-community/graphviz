This package uses pre-generated assets to avoid expensive MoonBit pre-build steps.

Manual regeneration:
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_font_metrics.sh` (updates `src/layout/dot/font_metrics/font_metrics.generated.mbt` with text widths + kerning; requires Graphviz build + `python3`).
- `bash scripts/generate_textspan_fixtures_from_xdot.sh` (updates `tests/fixtures/graphviz/textspan.jsonl` from xdot snapshots; requires `python3`).
- `bash scripts/generate_textspan_overrides.sh` (updates `src/layout/dot/font_metrics/textspan_overrides.generated.mbt` from `tests/fixtures/graphviz/textspan.jsonl`).
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_dot_snapshots.sh` (refreshes `tests/layout/dot/*.gv.dot`; requires Graphviz build or `dot` on PATH).
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_xdot_snapshots.sh` (refreshes `tests/render/xdot/*.xdot`; requires Graphviz build or `dot` on PATH).
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_svg_snapshots.sh` (refreshes `tests/render/svg/*.svg`; requires Graphviz build or `dot` on PATH).
- `bash scripts/capture_graphviz_label_vnodes.sh` (updates `tests/fixtures/graphviz/label_vnode.jsonl`; requires Graphviz build).
- `bash scripts/capture_graphviz_edge_label_pos.sh` (updates `tests/fixtures/graphviz/edge_label_pos.jsonl`; requires Graphviz build).
- `bash scripts/capture_graphviz_port_label_pos.sh` (updates `tests/fixtures/graphviz/port_label_pos.jsonl`; requires Graphviz build).

Graphviz source map (layout/dot parity)
- Rank assignment / network simplex
  - MoonBit: `src/layout/dot/network_simplex/network_simplex.mbt` + `src/layout/dot/layout.mbt` (rank build/merge)
  - Graphviz: `refs/graphviz/lib/dotgen/rank.c`, `refs/graphviz/lib/common/ns.c`, `refs/graphviz/lib/dotgen/acyclic.c`
- Crossing reduction (mincross / ordering)
  - MoonBit: `src/layout/dot/layout.mbt` (reorder_rank_groups, transpose_rank, reorder_by_medians)
  - Graphviz: `refs/graphviz/lib/dotgen/mincross.c`, `refs/graphviz/lib/dotgen/flat.c`
- X-position constraints (class2 / position)
  - MoonBit: `src/layout/dot/xpos.mbt` + `src/layout/dot/layout.mbt` (order index, vnode ordering)
  - Graphviz: `refs/graphviz/lib/dotgen/position.c`, `refs/graphviz/lib/dotgen/class2.c`, `refs/graphviz/lib/dotgen/cluster.c`, `refs/graphviz/lib/dotgen/sameport.c`
- Edge routing + splines / pathplan
  - MoonBit: `src/layout/dot/pathplan/pathplan.mbt`, `src/layout/dot/routesplines/routesplines.mbt`, `src/layout/dot/edge_spline/edge_spline.mbt`
  - Graphviz: `refs/graphviz/lib/pathplan/route.c`, `refs/graphviz/lib/pathplan/shortest.c`, `refs/graphviz/lib/pathplan/visibility.c`, `refs/graphviz/lib/common/routespl.c`, `refs/graphviz/lib/common/splines.c`, `refs/graphviz/lib/dotgen/dotsplines.c`
- Label placement + text metrics
  - MoonBit: `src/layout/dot/font_metrics/*`, `src/layout/dot/textspan.mbt` (text metrics), `src/layout/dot/label_layout.mbt` (label positions)
  - Graphviz: `refs/graphviz/lib/common/textspan.c`, `refs/graphviz/lib/common/labels.c`, `refs/graphviz/lib/label/xlabels.c`
- Record shape layout / ports
  - MoonBit: `src/layout/dot/record_layout.mbt` (record sizing, port centers)
  - Graphviz: `refs/graphviz/lib/common/shapes.c` (record_*), `refs/graphviz/lib/common/output.c` (record rects)
