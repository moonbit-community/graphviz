///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
priv struct ArrowFlags {
  head : Bool
  tail : Bool
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
fn arrow_flags(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> ArrowFlags {
  if kind != @cgraph.GraphKind::Directed {
    return { head: false, tail: false }
  }
  let dir = match edge.get_attr("dir") {
    Some(value) => value.to_lower()
    None => "forward"
  }
  let mut head = true
  let mut tail = false
  match dir {
    "none" => {
      head = false
      tail = false
    }
    "back" => {
      head = false
      tail = true
    }
    "both" => {
      head = true
      tail = true
    }
    _ => ()
  }
  let head_shape = match edge.get_attr("arrowhead") {
    Some(value) => value.to_lower()
    None => ""
  }
  if head_shape == "none" {
    head = false
  }
  let tail_shape = match edge.get_attr("arrowtail") {
    Some(value) => value.to_lower()
    None => ""
  }
  if tail_shape == "none" {
    tail = false
  }
  { head, tail }
}

///|
fn arrow_size(edge : @cgraph.Edge) -> Double {
  match edge.get_attr("arrowsize") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
}

///|
fn arrow_triangle(
  tip : @geom.Point,
  from : @geom.Point,
  size : Double,
) -> Array[@geom.Point] {
  let dx = tip.x - from.x
  let dy = tip.y - from.y
  let len = Double::sqrt(dx * dx + dy * dy)
  if len < 0.0001 {
    return []
  }
  let ux = dx / len
  let uy = dy / len
  let length = 10.0 * size
  let width = 6.0 * size
  let base_x = tip.x - ux * length
  let base_y = tip.y - uy * length
  let px = -uy
  let py = ux
  let half = width / 2.0
  [
    tip,
    { x: base_x + px * half, y: base_y + py * half },
    { x: base_x - px * half, y: base_y - py * half },
  ]
}

///|
fn arrow_points(
  layout : @layout_dot.DotLayoutEdge,
  at_head : Bool,
) -> Array[@geom.Point] {
  if layout.splines.length() == 0 {
    return []
  }
  let spline = if at_head {
    layout.splines[layout.splines.length() - 1]
  } else {
    layout.splines[0]
  }
  if spline.points.length() < 2 {
    return []
  }
  let tip = if at_head {
    spline.points[spline.points.length() - 1]
  } else {
    spline.points[0]
  }
  let from = if at_head {
    spline.points[spline.points.length() - 2]
  } else {
    spline.points[1]
  }
  arrow_triangle(tip, from, arrow_size(layout.edge))
}

///|
fn escape_xml(text : String) -> String {
  let sb = StringBuilder::new()
  for ch in text {
    match ch {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      '"' => sb.write_string("&quot;")
      '\'' => sb.write_string("&apos;")
      _ => sb.write_char(ch)
    }
  }
  sb.to_string()
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
fn shift_point(point : @geom.Point, llx : Double, lly : Double) -> @geom.Point {
  { x: point.x - llx, y: point.y - lly }
}

///|
fn spline_path(
  spline : @geom.Spline,
  llx : Double,
  lly : Double,
) -> String {
  let sb = StringBuilder::new()
  let points = spline.points
  if points.length() == 0 {
    return ""
  }
  let first = shift_point(points[0], llx, lly)
  sb.write_string("M ")
  sb.write_string(first.x.to_string())
  sb.write_char(' ')
  sb.write_string(first.y.to_string())
  let mut index = 1
  while index + 2 < points.length() {
    let p1 = shift_point(points[index], llx, lly)
    let p2 = shift_point(points[index + 1], llx, lly)
    let p3 = shift_point(points[index + 2], llx, lly)
    sb.write_string(" C ")
    sb.write_string(p1.x.to_string())
    sb.write_char(' ')
    sb.write_string(p1.y.to_string())
    sb.write_char(' ')
    sb.write_string(p2.x.to_string())
    sb.write_char(' ')
    sb.write_string(p2.y.to_string())
    sb.write_char(' ')
    sb.write_string(p3.x.to_string())
    sb.write_char(' ')
    sb.write_string(p3.y.to_string())
    index = index + 3
  }
  sb.to_string()
}

///|
fn polygon_points(
  points : Array[@geom.Point],
  llx : Double,
  lly : Double,
) -> String {
  let sb = StringBuilder::new()
  for i in 0..<points.length() {
    let point = shift_point(points[i], llx, lly)
    if i > 0 {
      sb.write_char(' ')
    }
    sb.write_string(point.x.to_string())
    sb.write_char(',')
    sb.write_string(point.y.to_string())
  }
  sb.to_string()
}

///|
fn write_line(
  sb : StringBuilder,
  text : String,
  indent : String,
  pretty : Bool,
) -> Unit {
  if pretty {
    sb.write_string(indent)
  }
  sb.write_string(text)
  if pretty {
    sb.write_char('\n')
  }
}

///|
pub fn SvgOptions::default() -> SvgOptions {
  { pretty: Some(true), include_xml_decl: Some(true) }
}

///|
pub fn render_svg(
  layout : @layout_dot.DotLayoutGraph,
  options? : SvgOptions = SvgOptions::default(),
) -> String {
  let opts = options
  let pretty = match opts.pretty {
    Some(value) => value
    None => true
  }
  let include_xml_decl = match opts.include_xml_decl {
    Some(value) => value
    None => true
  }
  let bbox = layout.bbox
  let width = bbox.urx - bbox.llx
  let height = bbox.ury - bbox.lly
  let sb = StringBuilder::new()
  if include_xml_decl {
    write_line(sb, "<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "", pretty)
  }
  write_line(
    sb,
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{width}pt\" height=\"\{height}pt\" viewBox=\"0 0 \{width} \{height}\">",
    "",
    pretty,
  )
  write_line(
    sb,
    "<g transform=\"translate(0 \{height}) scale(1 -1)\">",
    "  ",
    pretty,
  )
  let edge_indent = if pretty { "    " } else { "" }
  let kind = layout.graph.kind()
  for edge_layout in layout.edges {
    let edge = edge_layout.edge
    let color = match edge.get_attr("color") {
      Some(value) => value
      None => "black"
    }
    for spline in edge_layout.splines {
      let path = spline_path(spline, bbox.llx, bbox.lly)
      if path != "" {
        write_line(
          sb,
          "<path d=\"\{path}\" fill=\"none\" stroke=\"\{color}\"/>",
          edge_indent,
          pretty,
        )
      }
    }
    let flags = arrow_flags(edge, kind)
    if flags.head {
      let points = arrow_points(edge_layout, true)
      if points.length() > 0 {
        let attrs = polygon_points(points, bbox.llx, bbox.lly)
        write_line(
          sb,
          "<polygon points=\"\{attrs}\" fill=\"\{color}\" stroke=\"\{color}\"/>",
          edge_indent,
          pretty,
        )
      }
    }
    if flags.tail {
      let points = arrow_points(edge_layout, false)
      if points.length() > 0 {
        let attrs = polygon_points(points, bbox.llx, bbox.lly)
        write_line(
          sb,
          "<polygon points=\"\{attrs}\" fill=\"\{color}\" stroke=\"\{color}\"/>",
          edge_indent,
          pretty,
        )
      }
    }
  }
  let node_indent = if pretty { "    " } else { "" }
  for node_layout in layout.nodes {
    let node = node_layout.node
    let rect = node_rect(node_layout)
    let kind = shape_kind(node.get_attr("shape"))
    let stroke = match node.get_attr("color") {
      Some(value) => value
      None => "black"
    }
    let filled = has_filled_style(node.get_attr("style"))
    let fill = if filled {
      match node.get_attr("fillcolor") {
        Some(value) => value
        None => "white"
      }
    } else {
      "none"
    }
    if kind == "box" {
      let x = rect.llx - bbox.llx
      let y = rect.lly - bbox.lly
      let w = rect.urx - rect.llx
      let h = rect.ury - rect.lly
      write_line(
        sb,
        "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{fill}\" stroke=\"\{stroke}\"/>",
        node_indent,
        pretty,
      )
    } else {
      let cx = node_layout.pos.x - bbox.llx
      let cy = node_layout.pos.y - bbox.lly
      let rx = (rect.urx - rect.llx) / 2.0
      let ry = (rect.ury - rect.lly) / 2.0
      write_line(
        sb,
        "<ellipse cx=\"\{cx}\" cy=\"\{cy}\" rx=\"\{rx}\" ry=\"\{ry}\" fill=\"\{fill}\" stroke=\"\{stroke}\"/>",
        node_indent,
        pretty,
      )
    }
    let text = label_text(node.get_attr("label"), node.name())
    if text != "" {
      let font = font_name(node.get_attr("fontname"))
      let size = font_size(node.get_attr("fontsize"))
      let color = match node.get_attr("fontcolor") {
        Some(value) => value
        None => "black"
      }
      let pos = match node_layout.label_pos {
        Some(value) => value
        None => node_layout.pos
      }
      let x = pos.x - bbox.llx
      let y = pos.y - bbox.lly
      let escaped = escape_xml(text)
      write_line(
        sb,
        "<text x=\"\{x}\" y=\"\{y}\" text-anchor=\"middle\" dominant-baseline=\"middle\" font-family=\"\{font}\" font-size=\"\{size}\" fill=\"\{color}\">\{escaped}</text>",
        node_indent,
        pretty,
      )
    }
  }
  write_line(sb, "</g>", "  ", pretty)
  write_line(sb, "</svg>", "", pretty)
  sb.to_string()
}
