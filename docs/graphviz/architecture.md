# Graphviz Architecture and Pipeline

This document summarizes the current Graphviz codebase structure and the
end-to-end pipeline from DOT input to rendered output. It is meant as a
starting point for the MoonBit rewrite.

## Repository map (high level)

- cmd/
  - CLI entry points (dot, neato, fdp, sfdp, twopi, circo, etc.)
  - Each command mostly wires together libraries
- lib/
  - Core libraries (graph model, layout engines, render orchestration)
  - Most Graphviz logic lives here
- plugin/
  - Renderers, devices, and other plugins discovered by GVC
- tclpkg/
  - Language bindings and Tcl integration
- tests/, graphs/, dot.demo/
  - Test inputs and sample graphs

## Core libraries (intent and rough roles)

- lib/cgraph
  - Graph data model (graphs, nodes, edges)
  - DOT parsing and attribute handling
- lib/cdt
  - Core container data structures used widely
- lib/gvc
  - Graphviz context object (GVC) and orchestration of layouts and renders
  - Plugin discovery and renderer/device management
- lib/common
  - Shared utilities, attribute helpers, geometry helpers
- Layout engines
  - lib/dotgen (dot)
  - lib/neatogen (neato)
  - lib/fdpgen (fdp)
  - lib/sfdpgen (sfdp)
  - lib/twopigen (twopi)
  - lib/circogen (circo)
  - lib/osage (osage)
  - lib/patchwork (patchwork)
- Geometry and routing
  - lib/pathplan, lib/ortho, lib/edgepaint, lib/label, lib/vpsc
- Output helpers
  - lib/xdot (xdot output helpers)

## Pipeline overview

Graphviz follows a "program-as-filter" design: tools accept DOT graphs as input
and emit graphs (often DOT or xdot) with additional attributes attached.

ASCII flow:

  DOT text
    -> cgraph parser (lib/cgraph)
    -> in-memory graph model + attributes
    -> layout engine (lib/*gen)
    -> graph enriched with geometry attributes
    -> render pipeline (lib/gvc + plugins)
    -> output format (dot, xdot, svg, pdf, png, etc.)

Key points:

- Input is always DOT (even if the output is not DOT).
- Layout engines attach geometry as graph/node/edge attributes.
- Rendering can be done by emitting DOT/xdot or by running a renderer plugin.

## Layout output attributes (core examples)

From the library guide, layout engines typically attach:

- Graph attributes:
  - bb: bounding box rectangle in points
  - lp: label position (point)
- Node attributes:
  - pos: center position (point)
  - width/height: node size in inches
  - rects/vertices: shape geometry for record or polygon nodes
- Edge attributes:
  - pos: splineType describing routed edge geometry
  - lp: edge label position (point)

These attributes provide the bridge from layout to rendering.

## Type representations used in attributes

- point: "x,y" integers in points (72 points per inch)
- pointf: "x,y" floating-point in inches
- rectangle: "llx,lly,urx,ury" in points
- splineType: semicolon-separated list of spline values

## GVC lifecycle (summary)

GVC manages the lifetime and reuse of layout/render resources. The simplified
lifecycle described in lib/gvc/README.lifecycles is:

- gvc: exists for the full process lifetime
- input file: may include multiple graphs
- graph: one graph instance from parsing
- layout: per graph, per layout engine
- job / render: per layout, per output format or device
- page: optional, for multi-page outputs
- gvdevice: usually one per render job

This lifecycle helps define what should be reusable vs. per-graph state.

## Implications for the MoonBit rewrite

- Treat cgraph (graph model + DOT parsing) as the core front door.
- Treat layout engines as independent modules that consume the graph model and
  attach geometry attributes.
- Treat rendering as a separate pipeline stage that consumes the same model and
  attributes, with multiple output backends.

## References

- refs/graphviz/DEVELOPERS.md
- refs/graphviz/lib/gvc/README.lifecycles
- refs/graphviz/doc/libguide/intro.tex
- refs/graphviz/doc/libguide/types.tex
