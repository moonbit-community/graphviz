# Text measurement

All packages below belong to `moonbit-community/graphviz`; no additional module
is needed.

| Package | Responsibility |
| --- | --- |
| `text` | `Font`, `Metrics`, `InkBounds`, and the open `Measurer` trait |
| `layout/text` | Bind a measurer to a layout and its subsequent rendering |
| `text/heuristic` | Existing width/kerning tables, font fitting, captured spans, and calibration |
| `text/canvas` | Whole-run Canvas measurements and a reusable cache; JavaScript only |

Core parsing, layout and rendering do not import either provider. DOT parsing
is independent of text measurement. All layout entry points, including neato
and no-op layouts, require `text_context`. `DotLayoutGraph` retains the context,
so SVG, XDOT and `layout.apply()` cannot accidentally select another provider.

## Contract and layout ownership

`Measurer.measure(font, text)` receives a complete, decoded run in a single font.
It returns advance width, logical font height, ascent/descent, and optional ink
bounds. Sizes and distances are floating-point **points (1/72 inch)**. Ink bounds
are not advance width or line height; spaces can advance without leaving ink.
Logical font height can include the font's own leading, but not layout padding
or extra line spacing.

The layout still handles DOT escapes, line breaks, alignment, record syntax,
HTML spans/tables, padding, line advances and baseline positioning. Font ascent
is not substituted for Graphviz's optical baseline offset.

`layout/text.Calibration` is a separate, optional set of captured metric
corrections. `@heuristic.context()` explicitly installs the existing calibration,
including span overrides and optical offsets. It contains no label parser.
Canvas contexts do not install these corrections or initialize their data.
Absence of calibration never selects a different measurer.

The shared `resolve_font` function maps Graphviz font names to the same family,
weight, style and stretch in SVG and Canvas. These are font-selection rules,
not character widths or fitted metrics.

## Native / CLI

Import `text/heuristic` as `@heuristic`, `dot` as `@dot`, and `layout/dot` as
`@layout_dot`:

```moonbit
let graph = @dot.parse_dot(input)
let layout = @layout_dot.layout_dot(graph, text_context=@heuristic.context())
```

The CLI explicitly makes this selection. A native application can instead
implement `text.Measurer` using a font parser and construct its own
`@text_layout.Context::new(provider)`.

## Web / Canvas

Import `text/canvas` as `@canvas` and `layout/text` as `@text_layout`. Supply a
`CanvasRenderingContext2D` or `OffscreenCanvasRenderingContext2D` through the
external type `@canvas.Context2D`:

```moonbit
let measurer = @canvas.Canvas::new(ctx)
let text_context = @text_layout.Context::new(measurer)
let graph = @dot.parse_dot(input)
let layout = @layout_dot.layout_dot(graph, text_context~)
let svg = @svg.render_svg(layout)
```

Retain `measurer` and `text_context` across layout calls. The cache key contains
the font name, fractional size and full text run. Measurement calls `measureText`
once per cache miss, not once per character. It saves/restores the supplied
context and normalizes text state so unrelated Canvas drawing does not alter
the result.

Canvas uses `size_pt * 96 / 72` CSS pixels for the font and converts returned
metrics by `72 / 96`, without integer rounding or `devicePixelRatio` scaling.
It requires finite `fontBoundingBoxAscent/Descent` and `actualBoundingBox*`
metrics. Unsupported metrics are reported as a JavaScript error; there is no
heuristic fallback.

Font availability remains an application responsibility. Wait for the relevant
`document.fonts.load(...)` / `document.fonts.ready` before layout where possible.
Whenever loaded fonts change:

```moonbit
measurer.clear_cache()
// Run layout again with the retained text_context, then render the new output.
```

Clearing the cache does not update old geometry. Renderers write layout
attributes back to their graph, so recompute from the original DOT input or an
unmodified graph when relaying out after a font change. Retain the measurer and
context, not the previous layout output.

The package does not register font-loading listeners or trigger layout
implicitly. Browser-selected fonts and metrics need not equal the native
heuristic or upstream fixture values.
