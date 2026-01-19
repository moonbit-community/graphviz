///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
fn resolve_label(text : String, name : String) -> String {
  let with_name = text.replace_all(old="\\\\N", new=name)
  with_name.replace_all(old="\\\\n", new="\n")
}

///|
fn label_text(value : String?, fallback : String) -> String {
  match value {
    Some(text) => resolve_label(text, fallback)
    None => fallback
  }
}

///|
fn shape_kind(value : String?) -> String {
  let shape = match value {
    Some(text) => text.to_lower()
    None => "ellipse"
  }
  match shape {
    "box" | "rect" | "rectangle" => "box"
    "ellipse" | "oval" | "circle" => "ellipse"
    _ => "ellipse"
  }
}

///|
fn has_filled_style(value : String?) -> Bool {
  match value {
    Some(text) => text.to_lower().contains("filled")
    None => false
  }
}

///|
fn font_size(value : String?) -> Double {
  match value {
    Some(text) => parse_double(text, 14.0)
    None => 14.0
  }
}

///|
fn font_name(value : String?) -> String {
  match value {
    Some(text) => text
    None => "Times-Roman"
  }
}

///|
fn estimate_text_width(text : String, size : Double) -> Double {
  text.length().to_double() * size * 0.6
}

///|
fn node_rect(layout : @layout_dot.DotLayoutNode) -> @geom.Rect {
  let half_w = layout.width_in * 72.0 / 2.0
  let half_h = layout.height_in * 72.0 / 2.0
  {
    llx: layout.pos.x - half_w,
    lly: layout.pos.y - half_h,
    urx: layout.pos.x + half_w,
    ury: layout.pos.y + half_h,
  }
}

///|
fn rect_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
    { x: rect.urx, y: rect.ury },
    { x: rect.llx, y: rect.ury },
  ]
}

///|
fn midpoint(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  { x: (a.x + b.x) / 2.0, y: (a.y + b.y) / 2.0 }
}

///|
fn spline_midpoint(spline : @geom.Spline) -> @geom.Point {
  let count = spline.points.length()
  if count == 0 {
    { x: 0.0, y: 0.0 }
  } else {
    midpoint(spline.points[0], spline.points[count - 1])
  }
}

///|
fn node_draw_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let node = layout.node
  let ops : Array[@render.DrawOp] = []
  let pen = match node.get_attr("color") {
    Some(value) => value
    None => "black"
  }
  ops.push(@render.DrawOp::PenColor(color=pen))
  let filled = has_filled_style(node.get_attr("style"))
  if filled {
    let fill = match node.get_attr("fillcolor") {
      Some(value) => value
      None => "white"
    }
    ops.push(@render.DrawOp::FillColor(color=fill))
  }
  let rect = node_rect(layout)
  match shape_kind(node.get_attr("shape")) {
    "box" => {
      ops.push(@render.DrawOp::Polygon(filled=filled, points=rect_points(rect)))
    }
    _ => {
      ops.push(@render.DrawOp::Ellipse(filled=filled, rect=rect))
    }
  }
  ops
}

///|
fn node_label_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let node = layout.node
  let ops : Array[@render.DrawOp] = []
  let text = label_text(node.get_attr("label"), node.name())
  if text == "" {
    return ops
  }
  let font = @render.Font::{
    name: font_name(node.get_attr("fontname")),
    size: font_size(node.get_attr("fontsize")),
  }
  ops.push(@render.DrawOp::Font(font=font))
  let color = match node.get_attr("fontcolor") {
    Some(value) => value
    None => "black"
  }
  ops.push(@render.DrawOp::PenColor(color=color))
  let width = estimate_text_width(text, font.size)
  let pos = match layout.label_pos {
    Some(value) => value
    None => layout.pos
  }
  ops.push(@render.DrawOp::Text(
    pos=pos,
    align=@render.TextAlign::Center,
    width=width,
    text=text,
  ))
  ops
}

///|
fn edge_draw_ops(layout : @layout_dot.DotLayoutEdge) -> Array[@render.DrawOp] {
  let edge = layout.edge
  let ops : Array[@render.DrawOp] = []
  let pen = match edge.get_attr("color") {
    Some(value) => value
    None => "black"
  }
  ops.push(@render.DrawOp::PenColor(color=pen))
  for spline in layout.splines {
    ops.push(@render.DrawOp::Bezier(filled=false, points=spline.points))
  }
  ops
}

///|
fn edge_label_ops(layout : @layout_dot.DotLayoutEdge) -> Array[@render.DrawOp] {
  let edge = layout.edge
  let ops : Array[@render.DrawOp] = []
  let text = match edge.get_attr("label") {
    Some(value) => value
    None => ""
  }
  if text == "" {
    return ops
  }
  let font = @render.Font::{
    name: font_name(edge.get_attr("fontname")),
    size: font_size(edge.get_attr("fontsize")),
  }
  ops.push(@render.DrawOp::Font(font=font))
  let color = match edge.get_attr("fontcolor") {
    Some(value) => value
    None => "black"
  }
  ops.push(@render.DrawOp::PenColor(color=color))
  let width = estimate_text_width(text, font.size)
  let pos = match layout.label_pos {
    Some(value) => value
    None => match layout.splines.get(0) {
      Some(spline) => spline_midpoint(spline)
      None => { x: 0.0, y: 0.0 }
    }
  }
  ops.push(@render.DrawOp::Text(
    pos=pos,
    align=@render.TextAlign::Center,
    width=width,
    text=text,
  ))
  ops
}

///|
fn append_double(sb : StringBuilder, value : Double) -> Unit {
  sb.write_char(' ')
  sb.write_string(value.to_string())
}

///|
fn append_int(sb : StringBuilder, value : Int) -> Unit {
  sb.write_char(' ')
  sb.write_string(value.to_string())
}

///|
fn append_uint(sb : StringBuilder, value : UInt) -> Unit {
  sb.write_char(' ')
  sb.write_string(value.to_string())
}

///|
fn append_string(sb : StringBuilder, value : String) -> Unit {
  sb.write_char(' ')
  sb.write_string(value.length().to_string())
  sb.write_string(" -")
  sb.write_string(value)
}

///|
fn encode_gradient(gradient : @render.Gradient) -> String {
  let sb = StringBuilder::new()
  match gradient {
    @render.Gradient::Linear(value) => {
      sb.write_char('[')
      sb.write_string(value.start.x.to_string())
      sb.write_char(' ')
      sb.write_string(value.start.y.to_string())
      sb.write_char(' ')
      sb.write_string(value.end.x.to_string())
      sb.write_char(' ')
      sb.write_string(value.end.y.to_string())
      sb.write_char(' ')
      sb.write_string(value.stops.length().to_string())
      for stop in value.stops {
        sb.write_char(' ')
        sb.write_string(stop.offset.to_string())
        sb.write_char(' ')
        sb.write_string(stop.color.length().to_string())
        sb.write_string(" -")
        sb.write_string(stop.color)
      }
      sb.write_char(']')
    }
    @render.Gradient::Radial(value) => {
      sb.write_char('(')
      sb.write_string(value.start_center.x.to_string())
      sb.write_char(' ')
      sb.write_string(value.start_center.y.to_string())
      sb.write_char(' ')
      sb.write_string(value.start_radius.to_string())
      sb.write_char(' ')
      sb.write_string(value.end_center.x.to_string())
      sb.write_char(' ')
      sb.write_string(value.end_center.y.to_string())
      sb.write_char(' ')
      sb.write_string(value.end_radius.to_string())
      sb.write_char(' ')
      sb.write_string(value.stops.length().to_string())
      for stop in value.stops {
        sb.write_char(' ')
        sb.write_string(stop.offset.to_string())
        sb.write_char(' ')
        sb.write_string(stop.color.length().to_string())
        sb.write_string(" -")
        sb.write_string(stop.color)
      }
      sb.write_char(')')
    }
  }
  sb.to_string()
}

///|
fn encode_op(op : @render.DrawOp) -> String {
  let sb = StringBuilder::new()
  match op {
    @render.DrawOp::Ellipse(filled~, rect~) => {
      let center_x = (rect.llx + rect.urx) / 2.0
      let center_y = (rect.lly + rect.ury) / 2.0
      let radius_x = (rect.urx - rect.llx) / 2.0
      let radius_y = (rect.ury - rect.lly) / 2.0
      sb.write_char(if filled { 'E' } else { 'e' })
      append_double(sb, center_x)
      append_double(sb, center_y)
      append_double(sb, radius_x)
      append_double(sb, radius_y)
    }
    @render.DrawOp::Polygon(filled~, points~) => {
      sb.write_char(if filled { 'P' } else { 'p' })
      append_int(sb, points.length())
      for point in points {
        append_double(sb, point.x)
        append_double(sb, point.y)
      }
    }
    @render.DrawOp::Bezier(filled~, points~) => {
      sb.write_char(if filled { 'b' } else { 'B' })
      append_int(sb, points.length())
      for point in points {
        append_double(sb, point.x)
        append_double(sb, point.y)
      }
    }
    @render.DrawOp::Polyline(points~) => {
      sb.write_char('L')
      append_int(sb, points.length())
      for point in points {
        append_double(sb, point.x)
        append_double(sb, point.y)
      }
    }
    @render.DrawOp::Text(pos~, align~, width~, text~) => {
      sb.write_char('T')
      append_double(sb, pos.x)
      append_double(sb, pos.y)
      let align_code = match align {
        @render.TextAlign::Left => -1
        @render.TextAlign::Center => 0
        @render.TextAlign::Right => 1
      }
      append_int(sb, align_code)
      append_double(sb, width)
      append_string(sb, text)
    }
    @render.DrawOp::Image(rect~, name~) => {
      sb.write_char('I')
      append_double(sb, rect.llx)
      append_double(sb, rect.lly)
      append_double(sb, rect.urx - rect.llx)
      append_double(sb, rect.ury - rect.lly)
      append_string(sb, name)
    }
    @render.DrawOp::FillColor(color~) => {
      sb.write_char('C')
      append_string(sb, color)
    }
    @render.DrawOp::PenColor(color~) => {
      sb.write_char('c')
      append_string(sb, color)
    }
    @render.DrawOp::GradFill(gradient~) => {
      sb.write_char('C')
      append_string(sb, encode_gradient(gradient))
    }
    @render.DrawOp::GradPen(gradient~) => {
      sb.write_char('c')
      append_string(sb, encode_gradient(gradient))
    }
    @render.DrawOp::Font(font~) => {
      sb.write_char('F')
      append_double(sb, font.size)
      append_string(sb, font.name)
    }
    @render.DrawOp::Style(name~) => {
      sb.write_char('S')
      append_string(sb, name)
    }
    @render.DrawOp::FontChar(codepoint~) => {
      sb.write_char('t')
      append_uint(sb, codepoint)
    }
  }
  sb.to_string()
}

///|
pub fn XDotOptions::default() -> XDotOptions {
  { version: Some("1.7") }
}

///|
pub fn encode_xdot_ops(ops : Array[@render.DrawOp]) -> String {
  let parts : Array[String] = []
  for op in ops {
    parts.push(encode_op(op))
  }
  parts.join(" ")
}

///|
pub fn attach_xdot_attrs(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> Unit {
  let version = match options.version {
    Some(value) => value
    None => "1.7"
  }
  let graph = layout.graph
  graph.set_attr("xdotversion", version)
  for node_layout in layout.nodes {
    let draw_ops = node_draw_ops(node_layout)
    node_layout.node.set_attr("_draw_", encode_xdot_ops(draw_ops))
    let label_ops = node_label_ops(node_layout)
    if label_ops.length() > 0 {
      node_layout.node.set_attr("_ldraw_", encode_xdot_ops(label_ops))
    }
  }
  for edge_layout in layout.edges {
    let draw_ops = edge_draw_ops(edge_layout)
    edge_layout.edge.set_attr("_draw_", encode_xdot_ops(draw_ops))
    let label_ops = edge_label_ops(edge_layout)
    if label_ops.length() > 0 {
      edge_layout.edge.set_attr("_ldraw_", encode_xdot_ops(label_ops))
    }
  }
}

///|
pub fn render_xdot(
  layout : @layout_dot.DotLayoutGraph,
  options? : XDotOptions = XDotOptions::default(),
) -> String {
  layout.apply()
  attach_xdot_attrs(layout, options=options)
  @dot.write_dot(layout.graph)
}
