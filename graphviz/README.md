# graphviz

`moonbit-community/graphviz` provides synchronous, in-memory Graphviz parsing,
layout, and rendering in MoonBit, with no external module dependencies.

Packages:

- `cgraph`: graph data model
- `dot`: DOT parser and writer
- `layout/dot`: graph layout
- `render/xdot`: XDOT rendering
- `render/svg`: SVG rendering

Supply input as a string to `@dot.parse_dot`, pass the graph to
`@layout_dot.layout_dot`, then render it with `@svg.render_svg` or
`@xdot.render_xdot`. For layout-annotated DOT, call `layout.apply()` before
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
