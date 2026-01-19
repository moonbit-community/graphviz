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
