///|
/// Options for xdot output.
pub(all) struct XDotOptions {
  version : String?
} derive(Show, Eq)

///|
#declaration_only
pub fn XDotOptions::default() -> XDotOptions {
  ...
}

///|
/// Encode draw operations into a single xdot string.
#declaration_only
pub fn encode_xdot_ops(ops : Array[@render.DrawOp]) -> String {
  ...
}

///|
/// Attach xdot draw attributes (_draw_, _ldraw_, _hdraw_, _tdraw_) to the graph.
#declaration_only
pub fn attach_xdot_attrs(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> Unit {
  ...
}

///|
/// Render DOT with xdot attributes and xdotversion metadata.
#declaration_only
pub fn render_xdot(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> String {
  ...
}

///|
/// Render DOT with xdot attributes and return encoded output bytes.
#declaration_only
pub fn render_xdot_bytes(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> Bytes {
  ...
}
