# CLI Tools and I/O Formats

This document summarizes Graphviz command-line tools, common flags, and
input/output formats. It is a quick map for the MoonBit rewrite.

## Core layout commands

These commands share the same CLI and differ mostly by layout engine.

- dot: hierarchical (directed) layouts
- neato: symmetric (spring) layouts
- fdp: force-directed layouts
- sfdp: multiscale force-directed (large graphs)
- twopi: radial layouts
- circo: circular layouts
- patchwork: squarified treemaps
- osage: cluster-based layouts

## Common layout flags

Common flags from Dot.ref and dot(1):

- -T<format>: output format (dot, xdot, svg, png, pdf, ...)
- -o<file>: output file (default: stdout)
- -K<engine>: select layout engine (overrides executable name)
- -Gname=value: set graph default attribute
- -Nname=value: set node default attribute
- -Ename=value: set edge default attribute
- -s[scale]: input scale (defaults to 72 if omitted)
- -v / -V: verbose / version
- -n[num]: neato no-op layout using pre-positioned nodes
- -x: neato prune isolated nodes/peninsulas

Plugin variants:

- dot -T: prints available output formats
- dot -Tpng: lists plugin variants for png
- dot -Tpng:gd selects a specific variant

## Output formats

Traditional output formats (dot.1):

- dot: DOT with layout attributes
- xdot: DOT with full drawing ops
- ps / pdf
- svg / svgz
- fig (XFIG)
- png / gif / jpg / jpeg
- json (xdot in JSON)
- imap / cmapx (imagemaps)

The default renderer for a format is chosen by plugin quality; variants
can be selected with the colon syntax.

## Input formats

Primary input is DOT (GV). Converters support additional formats:

- gml2gv / gv2gml: GML <-> GV
- graphml2gv: GraphML -> GV
- gxl2gv / gv2gxl: GXL <-> GV
- mm2gv: Matrix Market -> GV

## Graph processing and analysis tools

Filters that consume DOT and emit DOT (or statistics):

- acyclic: reverse edges to break cycles
- tred: transitive reduction
- sccmap: strongly connected components
- ccomps: connected components
- bcomps: biconnected components
- gc: counts nodes/edges/components
- dijkstra: shortest path distances (dist/maxdist attributes)
- gvcolor: propagate colors along edges (requires dot layout)
- unflatten: adjust aspect ratio for dot
- gvpack: pack multiple laid-out graphs
- nop: pretty-print / validate DOT
- gvpr: graph stream processing language
- gvgen: synthetic graph generator

## Rendering/visualization helpers

Tools that rely on layout attributes:

- gvmap: clusters into geographic-style map (xdot output)
- edgepaint: recolor edges to disambiguate crossings
- mingle: edge bundling

## GUI tools

- gvedit: Graphviz viewer/editor
- smyrna: interactive graph viewer (OpenGL-based)

## Example pipelines

- Layout to SVG:
  dot -Tsvg input.gv -o output.svg

- Split, layout, pack, and render:
  ccomps -x input.gv | dot | gvpack | neato -s -n2 -Tps -o output.ps

## References

- refs/graphviz/cmd/dot/dot.1
- refs/graphviz/graphviz.7
- refs/graphviz/cmd/tools/*.1
- refs/graphviz/cmd/gvpr/gvpr.1
- refs/graphviz/cmd/gvmap/gvmap.1
- refs/graphviz/cmd/edgepaint/edgepaint.1
- refs/graphviz/cmd/mingle/mingle.1
- refs/graphviz/doc/Dot.ref
