# Dot Base Function Mapping (MoonBit <-> Graphviz)

This document records where each dot layout subsystem lives in the MoonBit
rewrite and which Graphviz C sources it must align with. It is the lookup
map for instrumenting Graphviz to capture unit-test fixtures and for
prioritizing alignment work.

## Alignment order (P0)

1. Text metrics + label sizing (required to compute node/edge sizes)
2. Record/port layout (node geometry, port positions)
3. Cycle removal + rank constraints + network simplex (rank assignment)
4. Ordering / mincross / transpose (rank ordering)
5. X-positioning + cluster constraints + sameport/compound hooks
6. Edge routing + splines + pathplan (edge geometry)
7. Postprocess (rankdir rotation, label offsets, cluster label adjustments)

## Mapping by subsystem

### Text metrics + label sizing

MoonBit:
- `src/layout/dot/font_metrics/font_metrics.generated.mbt` (font widths, kerning)
- `src/layout/dot/textspan.mbt` (label size helpers: `record_label_text_dimensions`,
  label size calculations used by node/edge/cluster sizing)
- `src/layout/dot/label_layout.mbt` (graph/edge/port label placement + overlap nudges)

Graphviz:
- `refs/graphviz/lib/common/textspan.c`
- `refs/graphviz/lib/common/textspan_lut.c`
- `refs/graphviz/lib/common/labels.c`
- `refs/graphviz/lib/label/xlabels.c`

Notes:
- Capture font name/size + raw string -> width/height points.
- Keep integer/float outputs exact; no tolerance expected in unit tests.

### Record / port layout

MoonBit:
- `src/layout/dot/record_layout.mbt` (record parser + layout: `record_nodes`,
  `record_layout_nodes`, `record_rects`, `record_ports`)
- `src/layout/dot/edge_spline/edge_spline.mbt` (record port clipping helpers)

Graphviz:
- `refs/graphviz/lib/common/shapes.c` (record_* layout)
- `refs/graphviz/lib/common/output.c` (record rects/ports emission)

Notes:
- Record orientation ties into rankdir; verify size -> rects -> port centers.

### Cycle removal + rank assignment

MoonBit:
- `src/layout/dot/layout.mbt` (acyclic pass + rank constraints: `acyclic_dfs`,
  `acyclic_edge_directions`, `compute_ranks_directed`,
  `add_rank_same_constraints`, `collect_rank_extremes`, `apply_rank_extremes`)
- `src/layout/dot/network_simplex/network_simplex.mbt` (network simplex core:
  `NsGraph`, `network_simplex`, tree/cutvalue updates)

Graphviz:
- `refs/graphviz/lib/dotgen/acyclic.c`
- `refs/graphviz/lib/dotgen/rank.c`
- `refs/graphviz/lib/common/ns.c`

Notes:
- Capture graph -> constraint edges -> ranks and any reversed edges.

### Ordering / mincross

MoonBit:
- `src/layout/dot/layout.mbt` (rank ordering + transpose:
  `build_edge_index_for_order`, `collect_rank_same_order`,
  `order_rank_by_cluster`, `reorder_rank_groups`,
  `transpose_rank_groups_limited`)

Graphviz:
- `refs/graphviz/lib/dotgen/mincross.c`
- `refs/graphviz/lib/dotgen/fastgr.c`
- `refs/graphviz/lib/dotgen/flat.c`

Notes:
- Capture per-rank ordering before/after transpose passes.

### X-positioning + cluster constraints

MoonBit:
- `src/layout/dot/xpos.mbt` (constraint construction + simplex positioning:
  `build_cluster_constraints`, `build_constraint_graph`,
  `x_positions_from_simplex`, `compute_x_positions`,
  `edge_port_offset`/`edge_port_offset_by_name`)
- `src/layout/dot/layout.mbt` (cluster spacing + alignment:
  `collect_cluster_rank_heights`, `apply_cluster_rank_heights`,
  `adjust_intercluster_alignment`)

Graphviz:
- `refs/graphviz/lib/dotgen/position.c`
- `refs/graphviz/lib/dotgen/cluster.c`
- `refs/graphviz/lib/dotgen/compound.c`
- `refs/graphviz/lib/dotgen/sameport.c` (not yet mirrored explicitly in MoonBit)

Notes:
- Cluster margin/label padding affect rank spacing and x constraints.

### Edge routing + splines + pathplan

MoonBit:
- `src/layout/dot/routesplines/routesplines.mbt` (routing + obstacles:
  `edge_pathplan_polyline`, `route_pathplan_from_boxes`,
  `maximal_bbox_for_name`, `boxes_to_polygon_points`)
- `src/layout/dot/pathplan/pathplan.mbt` (visibility + shortest path:
  `shortest_path_in_poly`, triangulation helpers)
- `src/layout/dot/edge_spline/edge_spline.mbt` (bezier, clipping, arrowheads,
  miter joins)

Graphviz:
- `refs/graphviz/lib/dotgen/dotsplines.c`
- `refs/graphviz/lib/common/routespl.c`
- `refs/graphviz/lib/common/splines.c`
- `refs/graphviz/lib/common/arrows.c`
- `refs/graphviz/lib/pathplan/route.c`
- `refs/graphviz/lib/pathplan/shortest.c`
- `refs/graphviz/lib/pathplan/shortestpth.c`
- `refs/graphviz/lib/pathplan/triang.c`
- `refs/graphviz/lib/pathplan/visibility.c`
- `refs/graphviz/lib/ortho/ortho.c` (if orthogonal routing is used)

Notes:
- Capture obstacle polygons + start/end points -> polyline -> final bezier.

### Geometry helpers

MoonBit:
- `src/layout/dot/shared/shared.mbt` (node sizes, port keys)
- `src/layout/dot/geom_utils.mbt` (clip/rect math, polyline helpers)
- `src/layout/dot/edge_spline/edge_spline.mbt` (point math, bezier helpers)

Graphviz:
- `refs/graphviz/lib/common/geom.c`
- `refs/graphviz/lib/common/geom.h`
- `refs/graphviz/lib/common/utils.c`

Notes:
- Keep coordinate system conventions (points vs inches) identical.

## Next instrumentation targets

When adding Graphviz logging hooks, start from these C entry points:
- `lib/dotgen/rank.c` -> rank constraints -> network simplex
- `lib/dotgen/mincross.c` -> rank ordering
- `lib/dotgen/position.c` -> x constraints and positions
- `lib/dotgen/dotsplines.c` -> edge routing
- `lib/common/shapes.c` + `lib/common/textspan.c` -> node size + record layout
