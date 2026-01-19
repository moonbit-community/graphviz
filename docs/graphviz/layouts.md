# Layout Engines and Constraints

This document summarizes Graphviz layout engines, their phases, and the
key attributes that shape layout. It focuses on the layout stage (graph
model -> geometry attributes), not rendering.

## Common layout phases

All layout engines are invoked through gvLayout and follow a shared pattern.

- initialize
  - Allocate common data structures and per-engine data
  - Measure node sizes and label metrics (e.g., ND_width/ND_height)
- position / rank / adjust (engine-specific)
  - Assign coordinates or ranks and apply constraints
- splines
  - Route edges and compute edge geometry
- postprocess
  - Apply rankdir rotation (dot), attach root label, normalize origin

Notes:

- Setting graph attribute splines="" disables edge routing entirely.
- For non-dot engines, node positions are stored in ND_pos (in inches).

## dot (lib/dotgen)

Purpose: Sugiyama-style hierarchical layout for directed graphs.

Pipeline:

- initialize
- rank (integer program for rank assignment)
- mincross (reorder nodes to reduce crossings)
- position (assign X coordinates, compact layout)
- sameports (merge edge ports using samehead/sametail)
- splines (route edges as B-splines)
- compoundEdges (clip splines for lhead/ltail cluster edges)

Key attributes:

- rankdir (rotate layout)
- samehead / sametail (merge edge ports)
- lhead / ltail + compound=true (logical cluster endpoints)
- splines (edge routing on/off)

## neato (lib/neatogen)

Purpose: Stress-based symmetric layouts.

Pipeline:

- initialize
- position
- adjust (optional overlap removal, controlled by overlap)
- splines (line segments or splines)

Key attributes:

- mode: major (stress majorization) or KK (Kamada-Kawai)
- model: shortpath (default), circuit, subset
- len (edge ideal length, in inches)
- overlap (enables adjust step)
- splines (line vs spline routing)

Limitations noted in the guide:

- KK mode can cycle and fail to converge
- Multi-edges share the same spline
- No cluster drawing support

## fdp (lib/fdpgen)

Purpose: Force-directed layout (Fruchterman-Reingold).

Pipeline:

- initialize
- position
- splines

Notes:

- Supports clusters and edges between clusters and nodes/clusters.
- Overlap removal is effectively required to keep clusters separate.

## sfdp (lib/sfdpgen)

Purpose: Multilevel force-directed layout for large graphs.

Pipeline:

- initialize
- position
- adjust
- splines

Notes:

- No cluster support.
- Does not model edge lengths or weights.

## twopi (lib/twopigen)

Purpose: Radial layout with concentric rings based on graph distance.

Pipeline:

- initialize
- position
- adjust
- splines

Key attributes:

- root: central node (defaults to a "most central" node)
- overlap: enables adjust

## circo (lib/circogen)

Purpose: Circular layouts using biconnected components.

Pipeline:

- initialize
- position
- splines

Notes:

- Avoids node overlaps by construction (no adjust step).

## osage (lib/osage)

Purpose: Cluster layout based on user specifications.

Notes:

- Intended for clustered graphs.
- Detailed algorithm is not described in the libguide; see code for specifics.

## patchwork (lib/patchwork)

Purpose: Squarified treemap layout.

Notes:

- Used for hierarchical, space-filling layouts.
- Details are not covered in the libguide; see code for specifics.

## Unconnected graphs and packing

All layouts expect connected graphs; Graphviz provides helpers to split and
pack components.

- ccomps splits a graph into connected component subgraphs.
- nodeInduce populates a component with its internal edges.
- pack_graph / packGraphs reassemble components without overlap.

Packing uses packmode and pack attributes:

- packmode: node, clust, graph (granularity of packing)
- pack: enables packing; packmode controls polyomino packing behavior

Special cases:

- dot aligns components by highest rank.
- neato uses packing by default, except mode=KK with pack=false.

## References

- refs/graphviz/doc/libguide/layouts.tex
- refs/graphviz/doc/libguide/unconnect.tex
- refs/graphviz/doc/libguide/intro.tex
- refs/graphviz/lib/pack/pack.3
