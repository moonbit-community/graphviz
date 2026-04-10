// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Options for SVG output.
pub(all) struct SvgOptions {
  pretty : Bool?
  include_xml_decl : Bool?
} derive(Show, Eq)

///|
#declaration_only
pub fn SvgOptions::default() -> SvgOptions {
  ...
}

///|
/// Render an SVG document from a laid-out graph.
#declaration_only
pub fn render_svg(
  layout : @layout_dot.DotLayoutGraph,
  options? : SvgOptions = SvgOptions::default(),
) -> String {
  ...
}
