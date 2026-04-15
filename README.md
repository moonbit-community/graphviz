# graphviz.mbt

`graphviz.mbt` is a MoonBit rewrite of Graphviz focused on strict output parity for the `dot` pipeline.

The repository currently targets byte-for-byte compatibility with upstream Graphviz `14.1.1` fixtures for:

- `dot`
- `xdot`
- `svg`

This project is built as a multi-package MoonBit module and includes a native `dot`-style CLI, a DOT parser/writer, layout code, and renderers.

## Status

The project is under active development. The main engineering goal is not just "similar rendering", but reproducible Graphviz-compatible behavior backed by strict fixtures and regression guards.

Today the repository includes:

- a native CLI frontend at `src/cmd/dot`
- DOT parsing and writing
- DOT layout implementation in MoonBit
- XDOT and SVG renderers
- strict parity tests against upstream Graphviz reference outputs

The top-level parity contract is intentionally narrow: fixture expectations are authored from upstream Graphviz `14.1.1`, not from this repository's own binary.

## Requirements

- [MoonBit](https://www.moonbitlang.com/) with the `moon` CLI
- a native toolchain supported by `moon --target native`
- Python 3 for some repository scripts
- upstream Graphviz `14.1.1` when refreshing parity fixtures

For fixture authoring and refreshes, use an external Graphviz `14.1.1` binary such as:

- `/opt/homebrew/opt/graphviz@14.1.1/bin/dot`
- `/usr/local/opt/graphviz@14.1.1/bin/dot`

Do not generate parity fixtures with this repository's own `dot.exe`.

## Quick Start

Build the native CLI:

```bash
moon build src/cmd/dot --target native
```

Run it on a DOT file:

```bash
_build/native/debug/build/cmd/dot/dot.exe -Tsvg input.gv -o output.svg
```

Write layout-annotated DOT to stdout:

```bash
_build/native/debug/build/cmd/dot/dot.exe -Tdot input.gv
```

List currently supported output formats:

```bash
_build/native/debug/build/cmd/dot/dot.exe -T
```

Current CLI coverage includes:

- output formats: `dot`, `xdot`, `svg`
- frontend behavior compatible with `dot` and `neato` program names
- common flags: `-T`, `-K`, `-o`, `-G`, `-N`, `-E`, `-s`, `-n`, `-x`, `-v`, `-V`

## Development

Basic local validation:

```bash
moon check --target native --deny-warn
moon test --target native --release --deny-warn
```

Before pushing a no-regression milestone, run the full local guard:

```bash
scripts/run_local_guard.sh
```

That guard covers:

- the full release MoonBit test suite
- strict parity checks for `dot`, `xdot`, and `svg`
- fixture/case-list invariants
- `DOT_CAPTURE_ORDERING_INPUTS` environment-invariance checks

For faster parity iteration on a small focus set:

```bash
scripts/check_strict_parity.py --formats dot xdot svg --focus ldbxtried typeshar
```

## Fixture Policy

Strict parity fixtures are reference artifacts, not self-generated expectations.

- The fixture source of truth is upstream Graphviz `14.1.1`.
- Use an external Graphviz `14.1.1` binary to generate or refresh `dot`, `xdot`, and `svg` fixtures.
- Treat `refs/graphviz` as source/input corpus and upstream code reference, not as the default fixture-authoring binary.
- Do not use the repository's own `dot.exe` to define expected parity outputs.

Manual snapshot regeneration helpers include:

- `bash scripts/generate_dot_snapshots.sh`
- `bash scripts/generate_xdot_snapshots.sh`
- `bash scripts/generate_svg_snapshots.sh`
- `bash scripts/generate_svg_renderer_snapshots.sh`

Some layout assets are intentionally pre-generated to avoid expensive pre-build steps. See:

- `src/layout/dot/README.md`
- `src/render/xdot/README.md`
- `src/render/svg/README.md`

## Repository Layout

Core packages:

- `src/cgraph`: graph data model
- `src/dot`: DOT parsing and writing
- `src/layout/dot`: DOT layout pipeline
- `src/render/xdot`: XDOT renderer
- `src/render/svg`: SVG renderer
- `src/cli`: CLI parsing and render pipeline orchestration
- `src/cmd/dot`: native executable entrypoint

Useful documentation:

- `docs/parity_guard.md`: strict parity workflow and history scan tools
- `docs/graphviz/architecture.md`: upstream Graphviz architecture notes
- `docs/graphviz/cli-and-formats.md`: CLI and I/O format reference
- `src/layout/dot/DOT_LAYOUT_ALGORITHM.md`: end-to-end DOT layout pipeline notes

## License

This project is licensed under the Eclipse Public License 2.0. See `LICENSE`.
