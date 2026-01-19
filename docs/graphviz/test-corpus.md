# Test Corpus and Parity Checks

This document proposes a curated test corpus for the MoonBit rewrite.
The goal is to cover parsing, layout, edge routing, and rendering with a
small but representative set of inputs, plus a larger set for regression
and performance checks.

## Parity strategy

Preferred output formats for parity checks:

- -Tdot: layout attributes only (pos, bb, lp, etc.)
- -Tplain: compact numeric output for basic layout sanity
- -Tsvg: rendering parity for a small subset (text-based snapshots)

Note: xdot is not planned; svg is the first rendering target.

When outputs differ:

- compare topology and attribute presence first (pos, bb, lp)
- compare numeric values within tolerances (layout is not bit-exact)
- treat SVG/png as visual checkpoints, not strict byte-for-byte matches

## Tier 0: Smoke tests (parser + minimal layout)

Small graphs and core language constructs:

- refs/graphviz/doc/dotguide/graph1.dot
- refs/graphviz/doc/dotguide/graph2.dot
- refs/graphviz/graphs/directed/try.gv
- refs/graphviz/graphs/directed/tree.gv
- refs/graphviz/graphs/undirected/ER.gv

Expected outputs: -Tdot, -Tplain

## Tier 1: Feature coverage

Attributes, shapes, ports, clusters, and labels:

- Clusters and subgraphs:
  - refs/graphviz/graphs/directed/clust.gv
  - refs/graphviz/graphs/directed/clust4.gv
- Record labels and ports:
  - refs/graphviz/graphs/directed/records.gv
  - refs/graphviz/graphs/directed/structs.gv
- HTML-like labels:
  - refs/graphviz/graphs/directed/table.gv
- Arrowheads and styles:
  - refs/graphviz/graphs/directed/arrows.gv
  - refs/graphviz/graphs/directed/oldarrows.gv
- Shapes and polygons:
  - refs/graphviz/graphs/directed/polypoly.gv
  - refs/graphviz/graphs/directed/trapeziumlr.gv
- Fonts and text encoding:
  - refs/graphviz/graphs/directed/psfonttest.gv
  - refs/graphviz/graphs/directed/Latin1.gv

Expected outputs: -Tdot, spot-check -Tsvg

## Tier 2: Layout engine coverage

Exercise each layout engine with a small but representative graph:

- dot:
  - refs/graphviz/graphs/directed/grammar.gv
- neato:
  - refs/graphviz/graphs/undirected/Heawood.gv
- fdp:
  - refs/graphviz/graphs/undirected/Petersen.gv
- sfdp:
  - refs/graphviz/graphs/directed/awilliams.gv
- twopi:
  - refs/graphviz/graphs/directed/switch.gv
- circo:
  - refs/graphviz/graphs/undirected/ngk10_4.gv
- patchwork:
  - refs/graphviz/graphs/directed/pm2way.gv
- osage:
  - refs/graphviz/graphs/directed/clust5.gv

Expected outputs: -Tdot, -Tplain

## Tier 3: Routing and label stress

Edge routing and label placement edge cases:

- Orthogonal routing:
  - refs/graphviz/tests/144_ortho.dot
  - refs/graphviz/tests/144_no_ortho.dot
- Dense edges:
  - refs/graphviz/graphs/directed/crazy.gv
  - refs/graphviz/graphs/directed/jsort.gv
- Label placement:
  - refs/graphviz/graphs/directed/ctext.gv
  - refs/graphviz/graphs/directed/hashtable.gv

Expected outputs: -Tdot, spot-check -Tsvg

## Tier 4: Regression and performance

Use these for larger-scale or long-running parity checks:

- refs/graphviz/tests/1864.dot (very large)
- refs/graphviz/tests/2064.dot
- refs/graphviz/tests/2593.dot
- refs/graphviz/tests/regression_tests/large/long_chain
- refs/graphviz/tests/regression_tests/large/wide_clusters

Expected outputs: -Tplain or metrics-only (runtime, node/edge counts)

## Format conversion tests

Verify import/export paths for non-DOT formats:

- GML:
  - refs/graphviz/tests/1869-1.gml
- GXL:
  - refs/graphviz/tests/2300.gxl
- GraphML:
  - refs/graphviz/tests/2094.xml
- Matrix Market:
  - refs/graphviz/tests/mm2gv input from sample matrices (see cmd/tools/mm2gv.1)

Expected outputs: parse + re-emit to DOT, then run -Tdot

## Expected-output fixtures

Existing fixtures for byte-level diffs:

- refs/graphviz/tests/2636.dot
- refs/graphviz/tests/2636.svg (expected)
- refs/graphviz/tests/usershape.dot
- refs/graphviz/tests/usershape.svg (expected)

These are good candidates for early svg parity.

## Notes for MoonBit integration

- Start with Tier 0 and Tier 1 to validate DOT parsing and attribute
  propagation.
- Defer Tier 4 until the layout core is stable.
- Use svg outputs as the rendering parity target. Normalize whitespace
  and tolerate minor numeric differences.

## References

- refs/graphviz/graphs
- refs/graphviz/tests
- refs/graphviz/doc/dotguide
