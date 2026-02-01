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
- `src/layout/dot/acyclic_helpers.mbt` (acyclic pass:
  `acyclic_dfs`, `acyclic_edge_directions`)
- `src/layout/dot/layout.mbt` (rank constraints: `compute_ranks_directed`)
- `src/layout/dot/rank_helpers.mbt` (rank extremes + same-rank constraints)
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
  `order_rank_by_cluster`, `reorder_rank_groups`, `transpose_rank_groups_limited`)
- `src/layout/dot/ordering_edge_helpers.mbt` (ordering edge utilities:
  `dedup_ordering_edges`, `build_ordering_flat_constraints`,
  `build_edge_index_for_order`, `build_edge_index_for_order_names`,
  `build_edge_index_for_order_with_vnodes`, `add_order_edge`)
- `src/layout/dot/ordering_helpers.mbt` (rank group utilities + crossing counts:
  `collect_rank_same_order`)
- `src/layout/dot/rank_group_helpers.mbt` (Graphviz rank-group seeding:
  `build_rank_groups_graphviz`, `build_rank_groups`)
- `src/layout/dot/vnode_helpers.mbt` (flat/vnode ordering helpers)
- `src/layout/dot/vnode_layout_helpers.mbt` (edge vnodes + flat label vnodes:
  `build_edge_vnodes`, `add_flat_label_vnodes`, `build_virtual_slack_edges`)

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
- `src/layout/dot/rank_position_helpers.mbt` (rank spacing + base positions)
- `src/layout/dot/cluster_layout_helpers.mbt` (cluster spacing + label padding:
  `collect_cluster_rank_heights`, `apply_cluster_rank_heights`)
- `src/layout/dot/cluster_alignment_helpers.mbt` (cluster alignment + bbox helpers:
  `adjust_intercluster_alignment`, `reorder_groups_by_cluster_order`,
  `adjust_cluster_positions_for_rounding`, `collect_cluster_bboxes`)
- `src/layout/dot/cluster_helpers.mbt` (cluster keys, edge cluster ownership)
- `src/layout/dot/self_edge_helpers.mbt` (self-edge port maps + spacing helpers)

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
- `src/layout/dot/edge_routing_helpers.mbt` (dot-specific polyline/dotted tweaks)

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
- `src/layout/dot/layout_bbox.mbt` (bbox + rankdir transform helpers)
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
