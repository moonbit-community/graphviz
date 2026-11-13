# graphviz

`moonbit-community/graphviz` provides synchronous, in-memory Graphviz parsing,
layout, and rendering in MoonBit, with no external module dependencies.

Packages:

- `cgraph`: graph data model
- `dot`: DOT parser and writer
- `text`: font/run measurement contract and shared font-name resolution
- `text/heuristic`: optional native-compatible heuristic metrics and calibration
- `text/canvas`: optional JavaScript Canvas metrics
- `layout/text`: explicitly bound measurement context
- `layout/dot`: graph layout
- `render/xdot`: XDOT rendering
- `render/svg`: SVG rendering

Supply input as a string to `@dot.parse_dot`. Parsing needs no measurer.
Layout entry points require an explicit `text_context`; for example:

```moonbit
let graph = @dot.parse_dot(input)
let layout = @layout_dot.layout_dot(graph, text_context=@heuristic.context())
let svg = @svg.render_svg(layout)
```

For web applications, use `@text_layout.Context::new(@canvas.Canvas::new(ctx))`
instead of importing `text/heuristic`. The layout output retains this context
for SVG/XDOT rendering and attribute writeback. There is no implicit provider
or fallback. See [text measurement](text/README.md) for units, browser font
loading, cache lifetime, and custom providers.

For layout-annotated DOT, call `layout.apply()` before
`@dot.write_dot(layout.graph)`.

File I/O, command-line processing, and file-based integration tests live in the
separate `moonbit-community/graphviz-cli` module. Its `cli` and `dot/fs` packages
replace the former `moonbit-community/graphviz/cli` and
`moonbit-community/graphviz/dot/fs` packages.

The repository's `moon.work` connects both modules for local development.
Run `moon check --target native --deny-warn` from the repository root to check
both modules.

Output parity fixtures come from upstream Graphviz 14.1.1.
See the repository README and `AGENTS.md` for validation and fixture policy.
