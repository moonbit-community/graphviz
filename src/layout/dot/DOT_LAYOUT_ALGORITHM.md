# DOT Layout Algorithm (Implementation Notes)

This document explains how the `src/layout/dot` package computes a DOT layout, with an emphasis on:

- pipeline stages,
- major data structures,
- clustering and virtual-node handling,
- ordering/crossing-reduction flow,
- position and routing flow,
- Graphviz parity constraints.

The implementation targets strict behavior parity with Graphviz (`dot`), validated by byte-level fixtures.

## 1) Entry Point and Stage Boundary

Primary public API:

- `layout_dot` in `src/layout/dot/layout.mbt`

The high-level stage sequence is:

1. validate graph + reset caches
2. prepare layout inputs
3. rank/order stage
4. position stage
5. routing stage
6. postprocess/finalize output graph

The stage orchestration is implemented in:

- `src/layout/dot/layout.mbt`
- `src/layout/dot/layout_dot_pipeline.mbt`

A simplified flow:

```text
layout_dot
  -> prepare_layout_inputs
  -> compute_dot_rank_stage
       -> compute_rank_data
       -> compute_rank_heights
       -> compute_cluster_metadata
       -> compute_ordering_and_vnodes
  -> compute_dot_position_stage
       -> compute_positions
  -> compute_dot_routing_stage
       -> build spatial data + routing context
       -> route_edges
  -> finalize_layout_graph
```

## 2) Core Intermediate Objects

The pipeline is driven by typed intermediate states (see `src/layout/dot/layout_pipeline_helpers.mbt`):

- `LayoutPrep`: canonicalized options, node/edge arrays, size maps, and port-order metadata.
- `RankData`: oriented edge arrays, node ranks, rank groups, rank keys.
- `RankHeights`: per-rank half-heights and spacing in points.
- `ClusterMetadata`: cluster membership/order/range and ordering constraints metadata.
- `OrderingResult`: final rank ordering (with and without vnodes), order graph artifacts, vnode info.
- `PositionResult`: x/y coordinates for real nodes and vnodes, plus cluster boundary x/rank y maps.

These objects are intentionally explicit to keep stage boundaries deterministic and testable.

## 3) Input Preparation Stage

Key implementation files:

- `src/layout/dot/layout_pipeline_input_helpers.mbt`
- `src/layout/dot/layout_pipeline_helpers.mbt` (shared structs/utilities)

What happens:

1. **Option/attribute resolution**
   - `rankdir`, `nodesep`, `ranksep`, `splines` are resolved from options first, then graph attrs.
   - negative spacing is rejected; Graphviz-compatible minimum clamps are applied.

2. **Graph scan and flags**
   - collect ordered nodes and edges
   - detect dotted edges, port edges, edge-label presence

3. **Node ordering seed**
   - build deterministic initial order map from graph/node iteration order, with `rankdir`-specific behavior.

4. **Size preparation**
   - compute node sizes used by ordering vs rendering
   - derive record orientation and record-port order metadata

5. **Port-order contribution metadata**
   - collect per-node port-order contributions from edges for ordering tie-break behavior.

Output is a `LayoutPrep` object that is passed to downstream stages without lossy conversion.

## 4) Rank Stage

Rank stage orchestrator:

- `compute_dot_rank_stage` in `src/layout/dot/layout_dot_pipeline.mbt`

### 4.1 Rank Assignment and Edge Orientation

Key files:

- `src/layout/dot/layout_pipeline_rank_helpers.mbt`
- `src/layout/dot/rank_assignment.mbt`
- `src/layout/dot/network_simplex/*`
- `src/layout/dot/acyclic_helpers.mbt`

Core behavior:

- run acyclic orientation preprocessing
- compute directed ranks (network-simplex style flow)
- build per-rank groups and full rank span
- carry self-edge label metadata for height expansion

### 4.2 Rank Heights

- start from node/self-edge half-heights
- apply edge-label midpoint height requirements
- apply vnode half-height expansion
- convert to `rank_ht1` / `rank_ht2` plus `nodesep_pt` and `ranksep_pt`

This keeps y-spacing compatible with Graphviz rank/position semantics.

### 4.3 Cluster Metadata

Key behavior:

- derive cluster membership (`cluster_keys`) and cluster order/parents
- compute cluster rank min/max bounds
- build cluster skeleton metadata
- derive `rank=same` related maps and flat constraints

This metadata is consumed heavily by ordering, x constraints, and routing.

## 5) Ordering + VNode Expansion Stage

Entry:

- `compute_ordering_and_vnodes` in `src/layout/dot/layout_pipeline_helpers.mbt`

Supporting files (after refactoring):

- `src/layout/dot/layout_pipeline_order_edge_helpers.mbt`
- `src/layout/dot/layout_pipeline_order_graph_helpers.mbt`
- `src/layout/dot/layout_pipeline_cluster_reorder_helpers.mbt`
- `src/layout/dot/layout_pipeline_root_cluster_reorder_helpers.mbt`
- `src/layout/dot/layout_pipeline_helpers.mbt` (dispatch/orchestration + remincross path)
- `src/layout/dot/ordering_helpers.mbt`
- `src/layout/dot/mincross.mbt`

### 5.1 Order-edge Materialization

The engine converts original edges into ordering edges with penalties and port metadata:

- endpoint normalization (including virtual-direction remaps)
- edge-chain expansion over edge vnodes
- per-tail bucketization and merge/coalescing rules
- deterministic creation-order replay

### 5.2 Root Mincross Pass

A Graphviz-like mincross pass is run over rank groups to reduce crossings, preserving deterministic tie-break rules.

### 5.3 Cluster-local Reorder

For clustered graphs, each cluster may run local reorder/build-ranks logic with cluster-local edge bundles and graphviz-neighbor maps.

### 5.4 Root-cluster Reorder

A root-level cluster reorder pass computes cluster rank order and reprojects ordering for clustered cases.

### 5.5 ReMincross Pass

A second pass (remincross path) rematerializes ordering graphs with cluster/vnode-aware constraints and reruns crossing reduction on the rematerialized structure.

### 5.6 Final Ordering Output

The stage emits:

- `ordered_groups` (real nodes)
- `ordered_groups_with_vnodes`
- vnode maps (rank, cluster, edge-vnode chains)
- order graph edge arrays and order index maps

Notes:

- `rank=same` ordering constraints are intentionally restricted (`build_rank_same_constraints` currently returns empty constraints), matching current parity behavior.
- cluster skeleton nodes are used internally in ordering/x-stage and later removed from final visible groups.

## 6) Position Stage

Entry:

- `compute_positions` in `src/layout/dot/layout_pipeline_helpers.mbt`

Core logic:

1. **mode gates**
   - decide whether vnode-aware x positioning is used
   - decide whether xpos reorder path is allowed

2. **x-stage seed construction**
   - build x-groups (real + optional vnodes)
   - build x cluster key overlays
   - compute edge port-x/order arrays for constraint solving

3. **optional xpos reorder + transpose cleanup**
   - reorder by medians/transpose when enabled
   - cleanup to avoid unstable artifacts

4. **constraint graph and x solve**
   - use class2/xpos-style constraints
   - include cluster boundary constraints and optional flat-label augmentation

5. **y projection**
   - compute `rank_y` from rank heights
   - map node/vnode positions from rank/x results
   - derive cluster left/right boundary x maps and bbox heights

Important details:

- cluster boundary nodes (`ln`/`rn`) are translated back into cluster x-bound maps.
- vnode output positions use either direct rank/x projection or endpoint interpolation fallback.

## 7) Routing Stage

Entry:

- `compute_dot_routing_stage` in `src/layout/dot/layout_dot_pipeline.mbt`

Key files:

- `src/layout/dot/layout_routing_helpers.mbt`
- `src/layout/dot/routesplines/*`
- `src/layout/dot/pathplan/*`
- `src/layout/dot/edge_spline/*`

Flow:

1. Build final node geometry and port maps from positioned nodes.
2. Compute cluster bboxes for routing constraints.
3. Apply `ratio/fill` scaling if required (with round-trip normalization rules).
4. Build routing context using:
   - rank maps,
   - final order groups/x-groups,
   - vnode positions,
   - cluster bboxes,
   - label port maps.
5. Route edges according to `splines` mode.
6. Emit routed splines and label positions.

Routing is designed to preserve Graphviz-compatible edge clipping/port behavior and ordering-sensitive path selection.

## 8) Postprocess and Graph Attribute Writeback

Finalization file:

- `src/layout/dot/layout_postprocess_helpers.mbt`

Writeback responsibilities:

- graph/subgraph bbox (`bb`) and label metrics attrs
- node attrs (`pos`, `width`, `height`, record `rects`, label/xlabel positions)
- edge `pos` spline encoding and label positions (`lp`, `head_lp`, `tail_lp`, `xlp`)

Special handling includes arrowhead/arrowtail `none` behavior and shape-specific parity nuances.

## 9) Determinism and Parity Controls

Determinism/parity principles:

- preserve Graphviz creation order semantics (node/edge AGSEQ-style ordering)
- keep stage argument wiring stable and explicit
- avoid implicit map iteration assumptions for externally visible order

Useful env toggles for diagnostics (implementation-level):

- `DOT_TRACE`
- `DOT_TRACE_GROUPS`
- `DOT_TRACE_POS`
- `DOT_TRACE_EDGES`
- `DOT_TRACE_ROUTE`
- `DOT_TRACE_REMINCROSS_INPUT`
- `DOT_CAPTURE_ORDERING_INPUTS`
- `DOT_CAPTURE_ORDERING_FIXTURE_MODE`

The repository guard validates strict parity and env invariance for ordering-capture mode.

## 10) Source Map by Responsibility

- Entry + stage orchestrator:
  - `layout.mbt`, `layout_dot_pipeline.mbt`
- Input canonicalization:
  - `layout_pipeline_input_helpers.mbt`
- Rank assignment/heights:
  - `layout_pipeline_rank_helpers.mbt`, `rank_assignment.mbt`, `network_simplex/*`
- Cluster metadata + main ordering dispatch:
  - `layout_pipeline_helpers.mbt`
- Ordering edge/order-graph helpers:
  - `layout_pipeline_order_edge_helpers.mbt`, `layout_pipeline_order_graph_helpers.mbt`
- Cluster-local reorder + root-cluster reorder:
  - `layout_pipeline_cluster_reorder_helpers.mbt`, `layout_pipeline_root_cluster_reorder_helpers.mbt`
- X-position internals:
  - `xpos.mbt`, `ordering_helpers.mbt`, `mincross.mbt`
- Routing:
  - `layout_routing_helpers.mbt`, `routesplines/*`, `pathplan/*`, `edge_spline/*`
- Final output mapping:
  - `layout_postprocess_helpers.mbt`

## 11) Practical Reading Order for New Contributors

Recommended reading sequence:

1. `layout.mbt` (`layout_dot`)
2. `layout_dot_pipeline.mbt` (stage boundaries)
3. `layout_pipeline_input_helpers.mbt`
4. `layout_pipeline_rank_helpers.mbt`
5. ordering helpers (`layout_pipeline_order_*`, `layout_pipeline_cluster_*`, `layout_pipeline_root_cluster_*`)
6. `layout_pipeline_helpers.mbt` (ordering dispatch + position stage)
7. `layout_routing_helpers.mbt`
8. `layout_postprocess_helpers.mbt`

This sequence follows data flow and makes parity-sensitive behavior easier to reason about.
