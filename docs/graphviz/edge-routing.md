# Edge Routing, Labels, and Path Planning

This document summarizes how Graphviz computes edge geometry and label
positions after node layout. It focuses on the path routing phase and the
libraries involved.

## Pipeline overview

Inputs:

- Node positions and shapes from the layout engine
- Edge endpoints (tail/head nodes) and attributes

Outputs:

- Edge geometry in the pos attribute (splineType)
- Label positions in lp (edge label) and headlabel/taillabel positions
- Optional xdot drawing ops for arrowheads and shapes

High-level flow:

  node positions + obstacles
    -> route polyline (shortest path / orthogonal / straight)
    -> fit spline (optional)
    -> clip to node/cluster boundaries
    -> attach label positions

## Edge geometry attributes

The pos attribute stores a splineType string. From the Graphviz types
reference:

- splineType is a semicolon-separated list of spline values
- spline value includes optional start (s, point) and end (e, point)
  markers and a list of 3n+1 control points

This encoding is used by renderers and by -Tdot/-Txdot outputs.

Related attributes:

- lp: edge label position (point)
- headlabel / taillabel: labels near endpoints
- labeldistance / labelangle: adjust head/tail label placement
- decorate: draws a line from label to edge

## libpathplan (shortest paths + spline fitting)

libpathplan is the core routing helper used by Graphviz to compute
paths that avoid obstacles.

Key functions:

- Pshortestpath: shortest path inside a boundary polygon
- Pobsopen / Pobspath: shortest path avoiding polygon obstacles
- Proutespline: fit a cubic B-spline to a polyline route
- Ppolybarriers: build barrier segments from polygon edges

Important details:

- Obstacles are polygons; the path is constrained to avoid them.
- Proutespline can enforce endpoint slopes and returns control points.
- Outputs are polylines and spline control points used to build pos.

## Orthogonal routing (lib/ortho)

Graphviz supports orthogonal edge routing (splines=ortho) for certain
layouts and output formats. The ortho library provides a maze-based
orthogonal router and geometry helpers (trapezoid/partition/maze).

This stage typically:

- Builds a rectangular obstacle field from node boxes
- Finds Manhattan paths through a grid or visibility graph
- Emits polylines that later become orthogonal splines

## Label placement (lib/label)

Label placement is handled by lib/label utilities:

- Compute label bounding boxes and candidate positions
- Position edge labels near the spline midpoint (lp)
- Position headlabel/taillabel near endpoints
- Optionally avoid overlaps and attach decoration segments

Relevant attributes include label, headlabel, taillabel, labelfloat,
labeldistance, labelangle, and decorate.

## Edge styling helpers (lib/edgepaint)

lib/edgepaint provides utilities for geometric computations and
edge/node distinct coloring. This is used to reduce visual ambiguity
in dense drawings (e.g., parallel edges, overlapping nodes).

## xdot drawing ops (lib/xdot)

For xdot output, edge routing results are translated into drawing
operations such as polyline, bezier, and text ops. These are stored
in _draw_, _hdraw_, _tdraw_ and related xdot attributes.

## Open questions for the MoonBit rewrite

- The exact split of responsibility between layout engines and routing
  (some engines use straight edges, others rely on pathplan).
- How multi-edge routing and parallel edge separation is implemented
  in each engine.
- Which routing features are required for the initial MVP.

## References

- refs/graphviz/lib/pathplan/README
- refs/graphviz/lib/pathplan/pathplan.3
- refs/graphviz/lib/ortho
- refs/graphviz/lib/label
- refs/graphviz/lib/edgepaint
- refs/graphviz/lib/xdot/xdot.3
- refs/graphviz/doc/libguide/types.tex
- refs/graphviz/doc/dotguide/dotguide.tex
