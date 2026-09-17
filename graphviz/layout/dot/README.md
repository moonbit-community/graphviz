This package uses pre-generated assets to avoid expensive MoonBit pre-build steps.

Detailed algorithm documentation:
- `graphviz/layout/dot/DOT_LAYOUT_ALGORITHM.md` (end-to-end DOT layout pipeline, ordering/remincross details, routing/postprocess flow).

Manual regeneration:
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_font_metrics.sh` (updates `graphviz/layout/dot/font_metrics/font_metrics.generated.mbt` with text widths + kerning; requires Graphviz build + `python3`).
- `bash scripts/generate_textspan_fixtures_from_xdot.sh` (updates `graphviz/layout/dot/font_metrics/textspan_overrides.jsonl` from xdot snapshots; requires `python3`).
- `bash scripts/generate_textspan_fixtures_from_xdot.sh --capture-jsonl /path/to/graphviz-14.1.1-textspan.jsonl` (merges exact textspan metrics captured from the external 14.1.1 reference; captured keys supersede older values).
- `bash scripts/generate_textspan_overrides.sh` (updates `graphviz/layout/dot/font_metrics/textspan_overrides.generated.mbt` from `graphviz/layout/dot/font_metrics/textspan_overrides.jsonl`).
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_dot_snapshots.sh` (refreshes `tests/layout/dot/*.gv.dot`; requires Graphviz build or `dot` on PATH).
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_xdot_snapshots.sh` (refreshes `tests/render/xdot/*.xdot` from `tests/render/xdot/cases.txt`; requires Graphviz build or `dot` on PATH).
- `DOT_BIN=refs/graphviz/build/cmd/dot/dot_builtins bash scripts/generate_svg_snapshots.sh` (refreshes `tests/render/svg/*.svg` from `tests/render/svg/cases.txt`; requires Graphviz build or `dot` on PATH).

Graphviz source map (layout/dot parity)
- Rank assignment / network simplex
  - MoonBit: `graphviz/layout/dot/ordering/rank_stage/*`, `graphviz/layout/dot/rank_assignment/*`, `graphviz/layout/dot/network_simplex/network_simplex.mbt`
  - Graphviz: `refs/graphviz/lib/dotgen/rank.c`, `refs/graphviz/lib/common/ns.c`, `refs/graphviz/lib/dotgen/acyclic.c`
- Crossing reduction (mincross / ordering)
  - MoonBit: `graphviz/layout/dot/ordering/rank_stage/*`, `graphviz/layout/dot/ordering/*`
  - Graphviz: `refs/graphviz/lib/dotgen/mincross.c`, `refs/graphviz/lib/dotgen/flat.c`
- X-position constraints (class2 / position)
  - MoonBit: `graphviz/layout/dot/positioning/*`, `graphviz/layout/dot/ordering/core.mbt`
  - Graphviz: `refs/graphviz/lib/dotgen/position.c`, `refs/graphviz/lib/dotgen/class2.c`, `refs/graphviz/lib/dotgen/cluster.c`, `refs/graphviz/lib/dotgen/sameport.c`
- Edge routing + splines / pathplan
  - MoonBit: `graphviz/layout/dot/routing/integration/*`, `graphviz/layout/dot/clustering/subgraph_layout.mbt`, `graphviz/layout/dot/routing/*`, `graphviz/layout/dot/routing/pathplan/*`, `graphviz/layout/dot/routing/routesplines/*`, `graphviz/layout/dot/routing/edge_spline/*`, `graphviz/layout/dot/routing/edge_ops/*`
  - Graphviz: `refs/graphviz/lib/pathplan/route.c`, `refs/graphviz/lib/pathplan/shortest.c`, `refs/graphviz/lib/pathplan/visibility.c`, `refs/graphviz/lib/common/routespl.c`, `refs/graphviz/lib/common/splines.c`, `refs/graphviz/lib/dotgen/dotsplines.c`
- Label placement + text metrics
  - MoonBit: `graphviz/layout/dot/font_metrics/*`, `graphviz/layout/dot/label_metrics/*`, `graphviz/layout/dot/label_layout/*`, `graphviz/layout/dot/finalization/*`
  - Graphviz: `refs/graphviz/lib/common/textspan.c`, `refs/graphviz/lib/common/labels.c`, `refs/graphviz/lib/label/xlabels.c`
- Record shape layout / ports
  - MoonBit: `graphviz/layout/dot/node_geometry/*`, `graphviz/layout/dot/label_layout/record_layout/*`, `graphviz/layout/dot/label_layout/html_layout/*`, `graphviz/layout/dot/label_layout/port_geometry/*`
  - Graphviz: `refs/graphviz/lib/common/shapes.c` (record_*), `refs/graphviz/lib/common/output.c` (record rects)
