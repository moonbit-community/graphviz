///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

const LINE_SPACING : Double = 1.2

const TEXT_SCALE : Double = 0.9706

///|
fn char_width_units(ch : Char) -> Int {
  match ch {
    ' ' => 250
    '\t' => 250
    '!' => 333
    '"' => 408
    '#' => 500
    '$' => 500
    '%' => 833
    '&' => 778
    '\'' => 180
    '(' | ')' | '[' | ']' => 333
    '*' => 500
    '+' | '<' | '=' | '>' => 564
    ',' | '.' => 250
    '-' => 333
    '/' | '\\' => 278
    '0'..='9' => 500
    ':' | ';' => 278
    '?' => 444
    '@' => 921
    'A' => 722
    'B' => 667
    'C' => 667
    'D' => 722
    'E' => 611
    'F' => 556
    'G' => 722
    'H' => 722
    'I' => 333
    'J' => 389
    'K' => 722
    'L' => 611
    'M' => 889
    'N' => 722
    'O' => 722
    'P' => 556
    'Q' => 722
    'R' => 667
    'S' => 556
    'T' => 611
    'U' => 722
    'V' => 722
    'W' => 944
    'X' => 722
    'Y' => 722
    'Z' => 611
    '^' => 469
    '_' => 500
    '`' => 333
    'a' => 444
    'b' => 500
    'c' => 444
    'd' => 500
    'e' => 444
    'f' => 333
    'g' => 500
    'h' => 500
    'i' => 278
    'j' => 278
    'k' => 500
    'l' => 278
    'm' => 778
    'n' => 500
    'o' => 500
    'p' => 500
    'q' => 500
    'r' => 333
    's' => 389
    't' => 278
    'u' => 500
    'v' => 500
    'w' => 722
    'x' => 500
    'y' => 500
    'z' => 444
    '{' => 480
    '|' => 200
    '}' => 480
    '~' => 541
    _ => 500
  }
}

///|
fn label_text_dimensions(label : String, font_size_pt : Double) -> (Double, Double) {
  let mut max_units = 0
  let mut current_units = 0
  let mut lines = 1
  let mut escaping = false
  for ch in label {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        if current_units > max_units {
          max_units = current_units
        }
        current_units = 0
        lines = lines + 1
      } else {
        current_units = current_units + char_width_units(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      if current_units > max_units {
        max_units = current_units
      }
      current_units = 0
      lines = lines + 1
    } else {
      current_units = current_units + char_width_units(ch)
    }
  }
  if escaping {
    current_units = current_units + char_width_units('\\')
  }
  if current_units > max_units {
    max_units = current_units
  }
  let width_pt = max_units.to_double() * font_size_pt * TEXT_SCALE / 1000.0
  let height_pt = lines.to_double() * font_size_pt * LINE_SPACING
  (width_pt, height_pt)
}

///|
priv struct ArrowFlags {
  head : Bool
  tail : Bool
}

///|
fn format_double(value : Double) -> String {
  let rounded = (value * 100.0).round() / 100.0
  if rounded == 0.0 {
    return "0"
  }
  let text = rounded.to_string()
  if !text.contains(".") {
    return text
  }
  let mut result = text
  while result.length() > 0 && result.has_suffix("0") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  if result.has_suffix(".") {
    let next_len = result.length() - 1
    result = result.unsafe_substring(start=0, end=next_len)
  }
  result
}

///|
fn resolve_label(text : String, name : String) -> String {
  let with_name = text.replace_all(old="\\\\N", new=name)
  with_name.replace_all(old="\\\\n", new="\n")
}

///|
fn normalize_color(value : String) -> String {
  let lower = value.to_lower()
  if lower.has_prefix("#") {
    return lower
  }
  match lower {
    "black" => "#000000"
    "white" => "#ffffff"
    "red" => "#ff0000"
    "green" => "#00ff00"
    "blue" => "#0000ff"
    "yellow" => "#ffff00"
    "orange" => "#ffa500"
    "cyan" => "#00ffff"
    "magenta" => "#ff00ff"
    "hotpink" => "#ff69b4"
    "purple" => "#a020f0"
    "slateblue" => "#6a5acd"
    _ => lower
  }
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
    "record" => "record"
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
  let (width, _) = label_text_dimensions(text, size)
  width
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
fn arrow_ops(
  layout : @layout_dot.DotLayoutEdge,
  at_head : Bool,
) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  if layout.splines.length() == 0 {
    return ops
  }
  let spline = if at_head {
    layout.splines[layout.splines.length() - 1]
  } else {
    layout.splines[0]
  }
  if spline.points.length() < 2 {
    return ops
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
  let points = arrow_triangle(tip, from, arrow_size(layout.edge))
  if points.length() == 0 {
    return ops
  }
  let style = match layout.edge.get_attr("style") {
    Some(value) => value.to_lower()
    None => "solid"
  }
  ops.push(@render.DrawOp::Style(name=style))
  let color = match layout.edge.get_attr("color") {
    Some(value) => value
    None => "black"
  }
  let normalized = normalize_color(color)
  ops.push(@render.DrawOp::PenColor(color=normalized))
  ops.push(@render.DrawOp::FillColor(color=normalized))
  ops.push(@render.DrawOp::Polygon(filled=true, points=points))
  ops
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
    { x: rect.urx, y: rect.ury },
    { x: rect.llx, y: rect.ury },
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
  ]
}

///|
fn outline_rect_points(rect : @geom.Rect) -> Array[@geom.Point] {
  [
    { x: rect.llx, y: rect.lly },
    { x: rect.llx, y: rect.ury },
    { x: rect.urx, y: rect.ury },
    { x: rect.urx, y: rect.lly },
  ]
}

///|
fn split_record_fields(label : String) -> Array[String] {
  let fields : Array[String] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut in_port = false
  for ch in label {
    if escaping {
      escaping = false
      sb.write_char(ch)
      continue
    }
    if ch == '\\' {
      escaping = true
      sb.write_char(ch)
      continue
    }
    if ch == '<' {
      in_port = true
      sb.write_char(ch)
      continue
    }
    if ch == '>' {
      in_port = false
      sb.write_char(ch)
      continue
    }
    if ch == '|' && !in_port {
      fields.push(sb.to_string())
      sb = StringBuilder::new()
      continue
    }
    sb.write_char(ch)
  }
  let last = sb.to_string()
  if last != "" || fields.length() == 0 {
    fields.push(last)
  }
  fields
}

///|
fn record_draw_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let node = layout.node
  let pen = match node.get_attr("color") {
    Some(value) => value
    None => "black"
  }
  let color = normalize_color(pen)
  let rect = node_rect(layout)
  ops.push(@render.DrawOp::PenColor(color=color))
  ops.push(@render.DrawOp::Polygon(filled=false, points=outline_rect_points(rect)))
  let label = match node.get_attr("label") {
    Some(value) => value
    None => node.name()
  }
  let fields = split_record_fields(label)
  if fields.length() > 1 {
    let count = fields.length().to_double()
    let height = rect.ury - rect.lly
    let step = height / count
    for i in 1..<fields.length() {
      let y = rect.ury - step * i.to_double()
      ops.push(@render.DrawOp::PenColor(color=color))
      ops.push(@render.DrawOp::Polyline(points=[
        { x: rect.llx, y },
        { x: rect.urx, y },
      ]))
    }
  }
  ops
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
  let normalized_pen = normalize_color(pen)
  let shape = shape_kind(node.get_attr("shape"))
  if shape == "record" {
    return record_draw_ops(layout)
  }
  ops.push(@render.DrawOp::PenColor(color=normalized_pen))
  let filled = has_filled_style(node.get_attr("style"))
  if filled {
    let fill = match node.get_attr("fillcolor") {
      Some(value) => value
      None => match node.get_attr("color") {
        Some(value) => value
        None => "white"
      }
    }
    ops.push(@render.DrawOp::FillColor(color=normalize_color(fill)))
  }
  let rect = node_rect(layout)
  match shape {
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
  ops.push(@render.DrawOp::PenColor(color=normalize_color(color)))
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
  ops.push(@render.DrawOp::PenColor(color=normalize_color(pen)))
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
  ops.push(@render.DrawOp::PenColor(color=normalize_color(color)))
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
  sb.write_string(format_double(value))
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
fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_label_text(graph : @cgraph.Graph) -> String? {
  match graph.get_attr("label") {
    Some(value) => {
      if value == "" {
        None
      } else {
        Some(value)
      }
    }
    None => None
  }
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (String, Double, Double)? {
  match graph_label_text(graph) {
    Some(text) => {
      let size = font_size(graph.get_attr("fontsize"))
      let (width_pt, height_pt) = label_text_dimensions(text, size)
      Some((text, width_pt, height_pt))
    }
    None => None
  }
}

///|
fn graph_label_pos(bbox : @geom.Rect, height_pt : Double) -> @geom.Point {
  let x = (bbox.llx + bbox.urx) / 2.0
  let y = bbox.ury - 4.0 - height_pt / 2.0
  { x, y }
}

///|
fn graph_draw_ops(layout : @layout_dot.DotLayoutGraph) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let graph = layout.graph
  let bbox = layout.bbox
  if graph.is_root() {
    let fill = match graph.get_attr("bgcolor") {
      Some(value) => value
      None => "white"
    }
    ops.push(@render.DrawOp::PenColor(color="#fffffe00"))
    ops.push(@render.DrawOp::FillColor(color=normalize_color(fill)))
    ops.push(@render.DrawOp::Polygon(filled=true, points=outline_rect_points(bbox)))
    return ops
  }
  if is_cluster_graph(graph) {
    match graph.get_attr("style") {
      Some(value) => {
        let style = value.to_lower()
        if style != "" && style != "solid" {
          ops.push(@render.DrawOp::Style(name=style))
        }
      }
      None => ()
    }
    let color = match graph.get_attr("color") {
      Some(value) => value
      None => "black"
    }
    ops.push(@render.DrawOp::PenColor(color=normalize_color(color)))
    ops.push(@render.DrawOp::Polygon(filled=false, points=outline_rect_points(bbox)))
  }
  ops
}

///|
fn format_point(point : @geom.Point) -> String {
  "\{format_double(point.x)},\{format_double(point.y)}"
}

///|
fn graph_label_ops(
  layout : @layout_dot.DotLayoutGraph,
) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let graph = layout.graph
  if !is_cluster_graph(graph) {
    return ops
  }
  match graph_label_metrics(graph) {
    Some((text, width_pt, height_pt)) => {
      let font = @render.Font::{
        name: font_name(graph.get_attr("fontname")),
        size: font_size(graph.get_attr("fontsize")),
      }
      ops.push(@render.DrawOp::Font(font=font))
      let color = match graph.get_attr("fontcolor") {
        Some(value) => value
        None => "black"
      }
      ops.push(@render.DrawOp::PenColor(color=normalize_color(color)))
      let pos = graph_label_pos(layout.bbox, height_pt)
      ops.push(@render.DrawOp::Text(
        pos=pos,
        align=@render.TextAlign::Center,
        width=width_pt,
        text=text,
      ))
    }
    None => ()
  }
  ops
}

///|
fn attach_graph_attrs(layout : @layout_dot.DotLayoutGraph) -> Unit {
  let graph = layout.graph
  let draw_ops = graph_draw_ops(layout)
  if draw_ops.length() > 0 {
    graph.set_attr("_draw_", encode_xdot_ops(draw_ops))
  }
  if is_cluster_graph(graph) {
    match graph_label_metrics(graph) {
      Some((_text, width_pt, height_pt)) => {
        let pos = graph_label_pos(layout.bbox, height_pt)
        graph.set_attr("lwidth", format_double(width_pt / 72.0))
        graph.set_attr("lheight", format_double(height_pt / 72.0))
        graph.set_attr("lp", format_point(pos))
      }
      None => ()
    }
    let label_ops = graph_label_ops(layout)
    if label_ops.length() > 0 {
      graph.set_attr("_ldraw_", encode_xdot_ops(label_ops))
    }
  }
  for subgraph in layout.subgraphs {
    attach_graph_attrs(subgraph)
  }
}

///|
fn encode_gradient(gradient : @render.Gradient) -> String {
  let sb = StringBuilder::new()
  match gradient {
    @render.Gradient::Linear(value) => {
      sb.write_char('[')
      sb.write_string(format_double(value.start.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.start.y))
      sb.write_char(' ')
      sb.write_string(format_double(value.end.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.end.y))
      sb.write_char(' ')
      sb.write_string(value.stops.length().to_string())
      for stop in value.stops {
        sb.write_char(' ')
        sb.write_string(format_double(stop.offset))
        sb.write_char(' ')
        sb.write_string(stop.color.length().to_string())
        sb.write_string(" -")
        sb.write_string(stop.color)
      }
      sb.write_char(']')
    }
    @render.Gradient::Radial(value) => {
      sb.write_char('(')
      sb.write_string(format_double(value.start_center.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.start_center.y))
      sb.write_char(' ')
      sb.write_string(format_double(value.start_radius))
      sb.write_char(' ')
      sb.write_string(format_double(value.end_center.x))
      sb.write_char(' ')
      sb.write_string(format_double(value.end_center.y))
      sb.write_char(' ')
      sb.write_string(format_double(value.end_radius))
      sb.write_char(' ')
      sb.write_string(value.stops.length().to_string())
      for stop in value.stops {
        sb.write_char(' ')
        sb.write_string(format_double(stop.offset))
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
  if graph.is_root() {
    graph.set_attr("xdotversion", version)
    match graph.get_default_attr(@cgraph.AttrKind::Node, "label") {
      Some(_) => ()
      None => graph.set_default_attr(@cgraph.AttrKind::Node, "label", "\\N")
    }
  }
  attach_graph_attrs(layout)
  let kind = graph.kind()
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
    let flags = arrow_flags(edge_layout.edge, kind)
    if flags.head {
      let head_ops = arrow_ops(edge_layout, true)
      if head_ops.length() > 0 {
        edge_layout.edge.set_attr("_hdraw_", encode_xdot_ops(head_ops))
      }
    }
    if flags.tail {
      let tail_ops = arrow_ops(edge_layout, false)
      if tail_ops.length() > 0 {
        edge_layout.edge.set_attr("_tdraw_", encode_xdot_ops(tail_ops))
      }
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
