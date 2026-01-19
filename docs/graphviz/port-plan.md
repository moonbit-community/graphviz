# MoonBit Rewrite Scope and Module Plan

This document defines a staged plan for rewriting Graphviz in MoonBit,
using the analysis documents in docs/graphviz/*.md as inputs.

## Goals

- Implement a MoonBit-native Graphviz core with:
  - DOT parsing + serialization
  - Graph data model with attributes
  - At least one layout engine (dot) for MVP
  - svg output for initial render parity tests
- Provide a CLI that mirrors the current dot/neato tool patterns
- Build parity against a curated corpus (docs/graphviz/test-corpus.md)

## Non-goals (early phases)

- Full plugin system parity on day one
- All render formats (pdf/png) in MVP
- Full performance parity with the C implementation

## Proposed MoonBit module layout

Suggested package structure (each directory is a MoonBit package):

- graphviz/core
  - common types, errors, config
- graphviz/geom
  - points, boxes, splines, geometry helpers
- graphviz/attrs
  - attribute tables, defaults, parsing helpers
- graphviz/cgraph
  - graph/node/edge/subgraph model
- graphviz/dot
  - DOT lexer, parser, AST, serializer
- graphviz/layout
  - layout registry and shared layout helpers
- graphviz/layout/dot
  - dot engine implementation
- graphviz/layout/neato (later)
  - neato/fdp/sfdp (separate packages)
- graphviz/route
  - path routing (pathplan, ortho) utilities
- graphviz/render/svg
  - svg renderer for human-visible output (first output format)
- graphviz/cli
  - dot/neato-compatible CLI
- graphviz/test
  - test helpers, snapshot utilities

This mirrors the existing Graphviz separation while staying MoonBit-friendly.

## Phased roadmap

### Phase 0: Project bootstrap

- Create moon.mod.json and base packages
- Implement core geometry and attribute types
- Add parser skeleton and test harness

Definition of done:

- moon check passes
- DOT parser accepts a minimal graph

### Phase 1: DOT parsing + cgraph model

- Implement DOT grammar, node/edge/subgraph creation rules
- Attribute scoping and defaults (graph/node/edge)
- Serialization to canonical DOT

Definition of done:

- Tier 0 + Tier 1 corpora parse and re-emit
- Round-trip tests stable

### Phase 2: dot layout MVP

- Implement dot pipeline: rank -> mincross -> position -> splines
- Support key attributes (rankdir, splines, samehead/sametail)
- Emit core layout attributes (pos, bb, lp, width/height)

Definition of done:

- Tier 2 dot cases produce -Tdot output with stable attributes
- Layout output is sufficient for downstream rendering

### Phase 3: svg output + render testing

- Implement svg renderer and serializer
- Emit core node/edge/label drawing in svg
- Snapshot svg output for test corpus (small subset)

Definition of done:

- Tier 1 subset pass svg snapshot comparisons

### Phase 4: CLI parity and tools (subset)

- dot CLI (input files, -T, -o, -G/-N/-E)
- neato CLI stub (optional) with clear unsupported errors
- Minimal filters: nop (pretty-print), gvpack (optional)

Definition of done:

- Can run dot -Tdot and dot -Tsvg on corpus

### Phase 5: Additional layouts and routing

- Add neato and fdp
- Add orthogonal routing and overlap removal
- Expand attribute coverage

Definition of done:

- Tier 2 engines for neato/fdp and Tier 3 routing pass

### Phase 6: Additional rendering formats

- PNG/PDF output
- Basic textlayout and image handling

Definition of done:

- Tier 1 subset renders in PNG/PDF with basic fidelity

## Risks and dependencies

- Layout algorithms are complex and need incremental validation.
- Plugin parity can be deferred by using static registries.
- Numeric stability and tolerance thresholds must be defined early.

## References

- docs/graphviz/architecture.md
- docs/graphviz/dot-language.md
- docs/graphviz/cgraph-model.md
- docs/graphviz/layouts.md
- docs/graphviz/edge-routing.md
- docs/graphviz/rendering.md
- docs/graphviz/cli-and-formats.md
- docs/graphviz/test-corpus.md
