# Rendering Pipeline and Plugin System

This document summarizes how Graphviz renders a laid-out graph and how
plugins are discovered and selected. It focuses on libgvc, GVJ jobs, and
renderer/device plugins.

## GVC context (libgvc)

The Graphviz context (GVC_t) stores process-wide state:

- plugin registries (layouts, renderers, devices, loadimage, textlayout)
- parsed command-line options
- version/build info (gvcInfo/gvcVersion/gvcBuildDate)
- the current graph and active jobs

A single GVC_t is intended to live for the duration of the process.

Key entry points:

- gvContext / gvNEWcontext: create context
- gvParseArgs: parse CLI-style args into jobs
- gvLayout / gvLayoutJobs: run layout
- gvRender / gvRenderJobs: render layout
- gvFreeLayout / gvFreeContext: cleanup

## Rendering job flow

High-level flow:

  DOT parse -> layout (gvLayout) -> job creation -> render

Jobs (GVJ_t) capture output intent:

- output format (-T) and destination (-o or FILE*)
- selected renderer and device plugins
- page/layout settings (dpi, margin, pages)
- per-job callbacks (interactive device use)

The rendering pipeline typically follows this sequence:

1) gvLayout(gvc, graph, engine)  // attach layout + geometry attributes
2) gvRender(gvc, graph, format, out) or gvRenderJobs
3) gvrender_begin_job / begin_graph / begin_page / begin_node / begin_edge
4) gvrender_* drawing calls (ellipses, polylines, bezier, text, images)
5) gvrender_end_* and gvdevice_finalize

## Renderer vs device

Graphviz splits output into two plugin types:

- Renderer: emits drawing primitives in a target language
- Device: manages output destination and device-specific lifecycle

Renderer API highlights (gvrender_engine_t):

- begin_job/end_job, begin_graph/end_graph, begin_page/end_page
- begin_node/end_node, begin_edge/end_edge
- textspan, ellipse, polygon, beziercurve, polyline, comment

Device API highlights (gvdevice_engine_t):

- initialize
- format
- finalize

Renderer features (gvrender_features_t) describe capabilities such as:

- arrowhead support, layer support, coordinate transforms
- map/URL support (rect/circle/polygon/ellipse/bspline)
- tooltips/targets, 3D support, background handling
- defaults (margin, pad, page size, dpi, known colors)

## Text layout and image loading

Two supporting plugin APIs are used during rendering:

- Textlayout (gvtextlayout_engine_t)
  - resolves font names and text size for labels
- Loadimage (gvloadimage_engine_t)
  - converts and rasterizes embedded images for node shapes

The image loader also provides caching via usershape_t fields.

## Plugin system

Graphviz plugins are organized by API kind:

- API_layout
- API_render
- API_device
- API_loadimage
- API_textlayout

A plugin library defines:

- gvplugin_installed_t[]: entries with type name, quality, engine, features
- gvplugin_api_t[]: groups of plugin types by API kind
- gvplugin_library_t: library name + API list

The library exports a symbol named:

  gvplugin_<name>_LTX_library

Library filenames follow:

  libgvplugin_<name>.<so|dylib|dll>

## Built-in plugin packages

The repo includes plugin packages under refs/graphviz/plugin, such as:

- core: core renderers/devices (dot, fig, map, ps, svg, json, tk, pic, pov)
- dot_layout: dot engine
- neato_layout: neato/fdp/sfdp/twopi/circo/patchwork/osage/nop
- gd, cairo, gdk, quartz, xlib, pango, rsvg, webp, etc.

Core packages register via gvplugin_core_LTX_library and similar symbols.

## Plugin discovery

At install time, Graphviz scans plugin libraries and writes a config
using `dot -c`. The config is read at runtime to populate available
plugins and their qualities. The highest-quality match for a requested
format/type is selected.

## References

- refs/graphviz/doc/libguide/drivers.tex
- refs/graphviz/doc/libguide/plugins.tex
- refs/graphviz/lib/gvc/gvc.3
- refs/graphviz/lib/gvc/gvplugin.h
- refs/graphviz/lib/gvc/gvplugin_render.h
- refs/graphviz/plugin/core/gvplugin_core.c
- refs/graphviz/plugin/dot_layout/gvplugin_dot_layout.c
- refs/graphviz/plugin/neato_layout/gvlayout_neato_layout.c
