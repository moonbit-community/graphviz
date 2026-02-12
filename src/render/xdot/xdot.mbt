///|
const PAD_X_PT : Double = 16.0

///|
const PAD_Y_PT : Double = 8.0

///|
const DIAGONAL_RBCONST : Double = 12.0

///|
const RECORD_BORDER_PT : Double = 0.5

const DOUBLE_CIRCLE_GAP_PT : Double = 4.0

///|
const ROUNDED_CORNER_RADIUS_PT : Double = 6.0

///|
const ROUNDED_CORNER_KAPPA : Double = 0.5522847498

///|
const GRAPH_LABEL_WIDTH_SCALE : Double = 0.9965

///|
const MCIRCLE_X : Double = 0.6614

///|
const MCIRCLE_Y : Double = 0.75

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
priv struct LabelLine {
  text : String
  align : @render.TextAlign
  width_pt : Double
  height_pt : Double
  yoffset_centerline : Double
}

///|
priv struct RawLabelLine {
  text : String
  align : @render.TextAlign
}

///|
fn push_label_line(
  lines : Array[RawLabelLine],
  text : String,
  align : @render.TextAlign,
) -> Unit {
  lines.push({ text, align })
}

///|
fn label_lines(label : String) -> Array[RawLabelLine] {
  let lines : Array[RawLabelLine] = []
  let mut sb = StringBuilder::new()
  let mut has_chars = false
  let mut escaping = false
  for ch in label {
    if escaping {
      escaping = false
      match ch {
        'n' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Center,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        'l' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Left,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        'r' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Right,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        _ => {
          sb.write_char(ch)
          has_chars = true
        }
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      push_label_line(
        lines,
        sb.to_string(),
        @render.TextAlign::Center,
      )
      sb = StringBuilder::new()
      has_chars = false
      continue
    }
    sb.write_char(ch)
    has_chars = true
  }
  if escaping {
    sb.write_char('\\')
    has_chars = true
  }
  if has_chars || lines.length() == 0 {
    push_label_line(
      lines,
      sb.to_string(),
      @render.TextAlign::Center,
    )
  }
  lines
}

///|
fn label_metrics(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Array[LabelLine], Double, Double) {
  let raw_lines = label_lines(label)
  let lines : Array[LabelLine] = []
  let mut max_width = 0.0
  let mut total_height = 0.0
  for line in raw_lines {
    let metrics_text = if line.text == "" { " " } else { line.text }
    let (width_pt, height_pt, _yoffset_layout, yoffset_centerline) =
      @layout_dot.label_text_metrics(
        metrics_text,
        font_name,
        font_size_pt,
      )
    let width_pt = if line.text == "" { 0.0 } else { width_pt }
    if width_pt > max_width {
      max_width = width_pt
    }
    total_height = total_height + height_pt
    lines.push({
      text: line.text,
      align: line.align,
      width_pt,
      height_pt,
      yoffset_centerline,
    })
  }
  (lines, max_width, total_height)
}

///|
fn record_label_lines(
  label : String,
 ) -> Array[RawLabelLine] {
  let lines : Array[RawLabelLine] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut has_chars = false
  for ch in label {
    if escaping {
      escaping = false
      match ch {
        'n' | 'l' | 'r' => {
          let align = match ch {
            'l' => @render.TextAlign::Left
            'r' => @render.TextAlign::Right
            _ => @render.TextAlign::Center
          }
          push_label_line(
            lines,
            sb.to_string(),
            align,
          )
          sb = StringBuilder::new()
          has_chars = false
        }
        _ => {
          sb.write_char(ch)
          has_chars = true
        }
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    if ch == '\n' || ch == '\r' {
      push_label_line(
        lines,
        sb.to_string(),
        @render.TextAlign::Center,
      )
      sb = StringBuilder::new()
      has_chars = false
      continue
    }
    sb.write_char(ch)
    has_chars = true
  }
  if escaping {
    sb.write_char('\\')
    has_chars = true
  }
  if has_chars || lines.length() == 0 {
    push_label_line(
      lines,
      sb.to_string(),
      @render.TextAlign::Center,
    )
  }
  lines
}

///|
fn record_label_metrics(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Array[LabelLine], Double, Double) {
  let raw_lines = record_label_lines(label)
  let lines : Array[LabelLine] = []
  let mut max_width = 0.0
  let mut total_height = 0.0
  for line in raw_lines {
    let metrics_text = if line.text == "" { " " } else { line.text }
    let (width_pt, height_pt) =
      @layout_dot.record_label_text_dimensions(
        metrics_text,
        font_name,
        font_size_pt,
      )
    let (_w, _h, _yoffset_layout, yoffset_centerline) =
      @layout_dot.label_text_metrics(
        metrics_text,
        font_name,
        font_size_pt,
      )
    let width_pt = if line.text == "" { 0.0 } else { width_pt }
    if width_pt > max_width {
      max_width = width_pt
    }
    total_height = total_height + height_pt
    lines.push({
      text: line.text,
      align: line.align,
      width_pt,
      height_pt,
      yoffset_centerline,
    })
  }
  (lines, max_width, total_height)
}

///|
fn extract_numbers(value : String) -> Array[Double] {
  let sb = StringBuilder::new()
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
    } else {
      sb.write_char(' ')
    }
  }
  let normalized = sb.to_string()
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    if token.length() == 0 {
      continue
    }
    numbers.push(parse_double(token.to_string(), 0.0))
  }
  numbers
}

///|
fn parse_margin(value : String) -> (Double, Double)? {
  let numbers = extract_numbers(value)
  if numbers.length() == 0 {
    return None
  }
  if numbers.length() == 1 {
    let val = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
    return Some((val, val))
  }
  let x = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
  let y = if numbers[1] < 0.0 { 0.0 } else { numbers[1] }
  Some((x, y))
}

///|
fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (_, width_pt, height_pt) = label_metrics(label, font_name, font_size_pt)
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
  let with_name = text.replace_all(old="\\N", new=name)
  with_name.replace_all(old="\\n", new="\n")
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
    "plaintext" | "plain" | "none" => "plaintext"
    "diamond" => "diamond"
    "triangle" => "triangle"
    "invtriangle" | "invtri" => "invtriangle"
    "hexagon" => "hexagon"
    "octagon" => "octagon"
    "record" | "mrecord" => "record"
    "point" | "dot" => "point"
    "mdiamond" => "mdiamond"
    "msquare" => "msquare"
    "mcircle" => "mcircle"
    "ellipse" | "oval" | "circle" => "ellipse"
    _ => "ellipse"
  }
}

///|
fn node_padding(node : @cgraph.Node) -> (Double, Double) {
  let mut pad_x_pt = PAD_X_PT
  let mut pad_y_pt = PAD_Y_PT
  match node.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some((margin_x, margin_y)) => {
          pad_x_pt = margin_x * 72.0 * 2.0
          pad_y_pt = margin_y * 72.0 * 2.0
        }
        None => ()
      }
    None => ()
  }
  (pad_x_pt, pad_y_pt)
}

///|
fn dash_style_name(style : @attrs.StyleFlags) -> String? {
  if style.dashed {
    Some("dashed")
  } else if style.dotted {
    Some("dotted")
  } else {
    None
  }
}

///|

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
  @attrs.parse_double(edge.get_attr("arrowsize"), 1.0)
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
    match spline.end {
      Some(point) => point
      None => spline.points[spline.points.length() - 1]
    }
  } else {
    match spline.start {
      Some(point) => point
      None => spline.points[0]
    }
  }
  // Graphviz parity: arrow direction uses the end control point (bz.list[size-1]),
  // not the preceding control point.
  let from = if at_head {
    spline.points[spline.points.length() - 1]
  } else {
    spline.points[0]
  }
  let arrowhead = if at_head {
    layout.edge.get_attr("arrowhead")
  } else {
    layout.edge.get_attr("arrowtail")
  }
  let primitives = @render.arrow_primitives(
    tip,
    from,
    arrow_size(layout.edge),
    arrowhead,
  )
  if primitives.length() == 0 {
    return ops
  }
  let style = "solid"
  let color = @attrs.color(layout.edge.get_attr("color"), default="black")
  let normalized = @attrs.normalize_color(color)
  for primitive in primitives {
    ops.push(@render.DrawOp::Style(name=style))
    ops.push(@render.DrawOp::PenColor(color=normalized))
    match primitive {
      @render.DrawOp::Polygon(filled~, points~) => {
        if filled {
          ops.push(@render.DrawOp::FillColor(color=normalized))
        }
        ops.push(@render.DrawOp::Polygon(filled~, points~))
      }
      @render.DrawOp::Ellipse(filled~, rect~) => {
        if filled {
          ops.push(@render.DrawOp::FillColor(color=normalized))
        }
        ops.push(@render.DrawOp::Ellipse(filled~, rect~))
      }
      @render.DrawOp::Polyline(points~) =>
        ops.push(@render.DrawOp::Polyline(points~))
      @render.DrawOp::Bezier(filled~, points~) => {
        let _ = filled
        ops.push(@render.DrawOp::Bezier(filled=false, points~))
      }
      _ => ()
    }
  }
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
fn inset_rect(rect : @geom.Rect, gap : Double) -> @geom.Rect? {
  let width = rect.urx - rect.llx
  let height = rect.ury - rect.lly
  if width <= gap * 2.0 || height <= gap * 2.0 {
    return None
  }
  Some({
    llx: rect.llx + gap,
    lly: rect.lly + gap,
    urx: rect.urx - gap,
    ury: rect.ury - gap,
  })
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
fn mdiamond_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: rect.ury },
    { x: rect.llx, y: cy },
    { x: cx, y: rect.lly },
    { x: rect.urx, y: cy },
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
fn rounded_rect_bezier_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let width = rect.urx - rect.llx
  let height = rect.ury - rect.lly
  let mut radius = ROUNDED_CORNER_RADIUS_PT
  let max_radius = if width < height { width / 2.0 } else { height / 2.0 }
  if max_radius < radius {
    radius = max_radius
  }
  if radius <= 0.0 {
    return [
      { x: rect.llx, y: rect.lly },
      { x: rect.llx, y: rect.lly },
      { x: rect.urx, y: rect.ury },
      { x: rect.urx, y: rect.ury },
    ]
  }
  let k = radius * ROUNDED_CORNER_KAPPA
  let left = rect.llx
  let right = rect.urx
  let bottom = rect.lly
  let top = rect.ury
  let inner_left = left + radius
  let inner_right = right - radius
  let inner_bottom = bottom + radius
  let inner_top = top - radius
  let top_dx = inner_left - inner_right
  let left_dy = inner_bottom - inner_top
  let bottom_dx = inner_right - inner_left
  let right_dy = inner_top - inner_bottom
  [
    { x: inner_right, y: top },
    { x: inner_right + top_dx / 3.0, y: top },
    { x: inner_right + top_dx * 2.0 / 3.0, y: top },
    { x: inner_left, y: top },
    { x: inner_left - k, y: top },
    { x: left, y: inner_top + k },
    { x: left, y: inner_top },
    { x: left, y: inner_top + left_dy / 3.0 },
    { x: left, y: inner_top + left_dy * 2.0 / 3.0 },
    { x: left, y: inner_bottom },
    { x: left, y: inner_bottom - k },
    { x: inner_left - k, y: bottom },
    { x: inner_left, y: bottom },
    { x: inner_left + bottom_dx / 3.0, y: bottom },
    { x: inner_left + bottom_dx * 2.0 / 3.0, y: bottom },
    { x: inner_right, y: bottom },
    { x: inner_right + k, y: bottom },
    { x: right, y: inner_bottom - k },
    { x: right, y: inner_bottom },
    { x: right, y: inner_bottom + right_dy / 3.0 },
    { x: right, y: inner_bottom + right_dy * 2.0 / 3.0 },
    { x: right, y: inner_top },
    { x: right, y: inner_top + k },
    { x: inner_right + k, y: top },
    { x: inner_right, y: top },
  ]
}

///|
fn diamond_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  [
    { x: cx, y: rect.ury },
    { x: rect.urx, y: cy },
    { x: cx, y: rect.lly },
    { x: rect.llx, y: cy },
  ]
}

///|
fn point_at(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  { x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t }
}

///|
fn diagonal_segments(
  points : Array[@geom.Point],
) -> Array[(@geom.Point, @geom.Point)] {
  let segments : Array[(@geom.Point, @geom.Point)] = []
  let count = points.length()
  if count < 2 {
    return segments
  }
  let mut rbconst = DIAGONAL_RBCONST
  for i in 0..<count {
    let p0 = points[i]
    let p1 = points[(i + 1) % count]
    let dx = p1.x - p0.x
    let dy = p1.y - p0.y
    let d = Double::sqrt(dx * dx + dy * dy)
    if d > 0.0001 {
      let candidate = d / 3.0
      if candidate < rbconst {
        rbconst = candidate
      }
    }
  }
  for i in 0..<count {
    let p0 = points[i]
    let p1 = points[(i + 1) % count]
    let p2 = points[(i + 2) % count]
    let dx0 = p1.x - p0.x
    let dy0 = p1.y - p0.y
    let d0 = Double::sqrt(dx0 * dx0 + dy0 * dy0)
    let dx1 = p2.x - p1.x
    let dy1 = p2.y - p1.y
    let d1 = Double::sqrt(dx1 * dx1 + dy1 * dy1)
    if d0 < 0.0001 || d1 < 0.0001 {
      continue
    }
    let t0 = rbconst / d0
    let t1 = rbconst / d1
    let start = point_at(p0, p1, 1.0 - t0)
    let end = point_at(p1, p2, t1)
    segments.push((start, end))
  }
  segments
}

///|
fn mcircle_segments(rect : @geom.Rect) -> Array[(@geom.Point, @geom.Point)] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  let rx = (rect.urx - rect.llx) / 2.0
  let ry = (rect.ury - rect.lly) / 2.0
  let dx = rx * MCIRCLE_X
  let dy = ry * MCIRCLE_Y
  [
    ({ x: cx + dx, y: cy + dy }, { x: cx - dx, y: cy + dy }),
    ({ x: cx + dx, y: cy - dy }, { x: cx - dx, y: cy - dy }),
  ]
}

///|
fn triangle_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  [
    { x: rect.llx, y: rect.lly },
    { x: rect.urx, y: rect.lly },
    { x: cx, y: rect.ury },
  ]
}

///|
fn invtriangle_points(rect : @geom.Rect) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  [
    { x: rect.llx, y: rect.ury },
    { x: rect.urx, y: rect.ury },
    { x: cx, y: rect.lly },
  ]
}

///|
fn regular_polygon_points(rect : @geom.Rect, sides : Int) -> Array[@geom.Point] {
  let cx = (rect.llx + rect.urx) / 2.0
  let cy = (rect.lly + rect.ury) / 2.0
  let half_w = (rect.urx - rect.llx) / 2.0
  let half_h = (rect.ury - rect.lly) / 2.0
  let radius = if half_w < half_h { half_w } else { half_h }
  let step = 2.0 * @math.PI / sides.to_double()
  let points : Array[@geom.Point] = []
  for i in 0..<sides {
    let angle = step * i.to_double()
    points.push({
      x: cx + radius * @math.cos(angle),
      y: cy + radius * @math.sin(angle),
    })
  }
  points
}

///|
fn shape_polygon_points(
  kind : String,
  rect : @geom.Rect,
) -> Array[@geom.Point]? {
  match kind {
    "diamond" => Some(diamond_points(rect))
    "triangle" => Some(triangle_points(rect))
    "invtriangle" => Some(invtriangle_points(rect))
    "hexagon" => Some(regular_polygon_points(rect, 6))
    "octagon" => Some(regular_polygon_points(rect, 8))
    _ => None
  }
}

///|
priv struct RecordField {
  text : String
}

///|
priv enum RecordOrientation {
  Horizontal
  Vertical
}

///|
fn record_layout_orientation(graph : @cgraph.Graph) -> RecordOrientation {
  let mut current = graph
  while true {
    match current.get_attr("rankdir") {
      Some(value) =>
        match value.to_lower() {
          "lr" | "rl" => return RecordOrientation::Vertical
          "tb" | "bt" => return RecordOrientation::Horizontal
          _ => ()
        }
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  RecordOrientation::Horizontal
}

///|
priv enum RecordNode {
  Field(RecordField)
  Group(Array[RecordNode])
}

///|
fn toggle_record_orientation(
  orientation : RecordOrientation,
) -> RecordOrientation {
  match orientation {
    RecordOrientation::Horizontal => RecordOrientation::Vertical
    RecordOrientation::Vertical => RecordOrientation::Horizontal
  }
}

///|
priv struct RecordParser {
  chars : Array[Char]
  mut index : Int
}

///|
fn parse_record_nodes(parser : RecordParser) -> Array[RecordNode] {
  let nodes : Array[RecordNode] = []
  let mut sb = StringBuilder::new()
  let mut escaping = false
  let mut in_port = false
  let mut segment_has_node = false
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if escaping {
      escaping = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '\\' {
      escaping = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '<' {
      in_port = true
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if ch == '>' {
      in_port = false
      sb.write_char(ch)
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '{' {
      let text = sb.to_string()
      if text.trim(chars=" \n\r\t") != "" {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
        segment_has_node = true
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      let children = parse_record_nodes(parser)
      nodes.push(RecordNode::Group(children))
      segment_has_node = true
      continue
    }
    if !in_port && ch == '|' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      segment_has_node = false
      parser.index = parser.index + 1
      continue
    }
    if !in_port && ch == '}' {
      let text = sb.to_string()
      if !segment_has_node {
        nodes.push(RecordNode::Field(record_field_from_text(text)))
      }
      sb = StringBuilder::new()
      parser.index = parser.index + 1
      return nodes
    }
    sb.write_char(ch)
    parser.index = parser.index + 1
  }
  let text = sb.to_string()
  if !segment_has_node {
    nodes.push(RecordNode::Field(record_field_from_text(text)))
  }
  nodes
}

///|
fn record_field_from_text(field : String) -> RecordField {
  let trimmed = field.trim(chars=" \n\r\t").to_string()
  let raw_text = if trimmed.has_prefix("<") {
    match trimmed.find(">") {
      Some(pos) => {
        let len = trimmed.length()
        if pos + 1 < len {
          trimmed.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
      }
      None => trimmed
    }
  } else {
    trimmed
  }
  let normalized = raw_text.trim(chars=" \n\r\t").to_string()
  let text = if normalized == "" { " " } else { normalized }
  { text, }
}

///|
fn record_nodes(label : String) -> Array[RecordNode] {
  let chars : Array[Char] = []
  for ch in label {
    chars.push(ch)
  }
  let parser = RecordParser::{ chars, index: 0 }
  let nodes = parse_record_nodes(parser)
  if nodes.length() == 1 {
    match nodes[0] {
      RecordNode::Group(children) => children
      _ => nodes
    }
  } else {
    nodes
  }
}

///|
priv struct RecordNodeSize {
  width_pt : Double
  height_pt : Double
}

///|
fn record_nodes_sizes(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  name : String,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[RecordNodeSize] {
  let sizes : Array[RecordNodeSize] = []
  for node in nodes {
    match node {
      RecordNode::Field(field) => {
        let text = resolve_label(field.text, name)
        let (_, text_width_pt, text_height_pt) = record_label_metrics(
          text, font_name, font_size_pt,
        )
        sizes.push({
          width_pt: text_width_pt + pad_x_pt,
          height_pt: text_height_pt + pad_y_pt,
        })
      }
      RecordNode::Group(children) => {
        let size = record_group_size(
          children,
          toggle_record_orientation(orientation),
          name,
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
        )
        sizes.push(size)
      }
    }
  }
  sizes
}

///|
fn record_group_size(
  nodes : Array[RecordNode],
  orientation : RecordOrientation,
  name : String,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> RecordNodeSize {
  let sizes = record_nodes_sizes(
    nodes, orientation, name, font_name, font_size_pt, pad_x_pt, pad_y_pt,
  )
  if sizes.length() == 0 {
    return { width_pt: 0.0, height_pt: 0.0 }
  }
  let mut width = 0.0
  let mut height = 0.0
  match orientation {
    RecordOrientation::Vertical =>
      for size in sizes {
        if size.width_pt > width {
          width = size.width_pt
        }
        height = height + size.height_pt
      }
    RecordOrientation::Horizontal =>
      for size in sizes {
        if size.height_pt > height {
          height = size.height_pt
        }
        width = width + size.width_pt
      }
  }
  { width_pt: width, height_pt: height }
}

///|
priv struct RecordLayout {
  rect : @geom.Rect
  node : RecordNode
  children : Array[RecordLayout]
}

///|
fn record_layout_nodes(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  name : String,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[RecordLayout] {
  if nodes.length() == 0 {
    return []
  }
  let sizes = record_nodes_sizes(
    nodes, orientation, name, font_name, font_size_pt, pad_x_pt, pad_y_pt,
  )
  let axis_sizes : Array[Double] = []
  let mut axis_sum = 0.0
  for size in sizes {
    let axis = match orientation {
      RecordOrientation::Vertical => size.height_pt
      RecordOrientation::Horizontal => size.width_pt
    }
    axis_sizes.push(axis)
    axis_sum = axis_sum + axis
  }
  let axis_total = match orientation {
    RecordOrientation::Vertical => rect.ury - rect.lly
    RecordOrientation::Horizontal => rect.urx - rect.llx
  }
  if axis_sizes.length() > 0 {
    // Match Graphviz resize_reclbl: distribute extra size evenly with int rounding.
    let delta = axis_total - axis_sum
    if delta != 0.0 {
      let inc = delta / axis_sizes.length().to_double()
      for i in 0..<axis_sizes.length() {
        let before = (i.to_double() * inc).trunc().to_int()
        let after = ((i + 1).to_double() * inc).trunc().to_int()
        let amt = after - before
        axis_sizes[i] = axis_sizes[i] + Double::from_int(amt)
      }
    }
  }
  let layouts : Array[RecordLayout] = []
  let mut cursor = match orientation {
    RecordOrientation::Vertical => rect.ury
    RecordOrientation::Horizontal => rect.llx
  }
  for i in 0..<nodes.length() {
    let axis = axis_sizes[i]
    let child_rect : @geom.Rect = match orientation {
      RecordOrientation::Vertical => {
        let bottom = cursor - axis
        let child : @geom.Rect = {
          llx: rect.llx,
          lly: bottom,
          urx: rect.urx,
          ury: cursor,
        }
        cursor = bottom
        child
      }
      RecordOrientation::Horizontal => {
        let right = cursor + axis
        let child : @geom.Rect = {
          llx: cursor,
          lly: rect.lly,
          urx: right,
          ury: rect.ury,
        }
        cursor = right
        child
      }
    }
    match nodes[i] {
      RecordNode::Field(_) =>
        layouts.push({ rect: child_rect, node: nodes[i], children: [] })
      RecordNode::Group(children) => {
        let child_layouts = record_layout_nodes(
          children,
          child_rect,
          toggle_record_orientation(orientation),
          name,
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
        )
        layouts.push({
          rect: child_rect,
          node: nodes[i],
          children: child_layouts,
        })
      }
    }
  }
  layouts
}

///|
fn record_separator_ops(
  ops : Array[@render.DrawOp],
  layouts : Array[RecordLayout],
  orientation : RecordOrientation,
  rect : @geom.Rect,
  color : String,
) -> Unit {
  if layouts.length() > 1 {
    match orientation {
      RecordOrientation::Vertical => {
        let x1 = rect.llx
        let x2 = rect.urx
        for i in 1..<layouts.length() {
          let y = layouts[i].rect.ury
          ops.push(@render.DrawOp::PenColor(color~))
          ops.push(
            @render.DrawOp::Polyline(points=[{ x: x1, y }, { x: x2, y }]),
          )
        }
      }
      RecordOrientation::Horizontal => {
        let y1 = rect.lly
        let y2 = rect.ury
        for i in 1..<layouts.length() {
          let x = layouts[i].rect.llx
          ops.push(@render.DrawOp::PenColor(color~))
          ops.push(
            @render.DrawOp::Polyline(points=[{ x, y: y1 }, { x, y: y2 }]),
          )
        }
      }
    }
  }
  for layout in layouts {
    match layout.node {
      RecordNode::Group(_) =>
        record_separator_ops(
          ops,
          layout.children,
          toggle_record_orientation(orientation),
          layout.rect,
          color,
        )
      _ => ()
    }
  }
}

///|
fn record_label_ops_from_layout(
  ops : Array[@render.DrawOp],
  layouts : Array[RecordLayout],
  name : String,
  font : @render.Font,
  color : String,
) -> Unit {
  for layout in layouts {
    match layout.node {
      RecordNode::Field(field) => {
        let text = resolve_label(field.text, name)
        if text == "" {
          continue
        }
        let (lines, max_width, total_height) = record_label_metrics(
          text,
          font.name,
          font.size,
        )
        let center_x = (layout.rect.llx + layout.rect.urx) / 2.0
        let center_y = (layout.rect.lly + layout.rect.ury) / 2.0
        let mut baseline = center_y + total_height / 2.0 - font.size
        for line in lines {
          let line_x = match line.align {
            @render.TextAlign::Left => center_x - max_width / 2.0
            @render.TextAlign::Right => center_x + max_width / 2.0
            @render.TextAlign::Center => center_x
          }
          let line_y = baseline + line.yoffset_centerline
          if line.text != "" {
            ops.push(@render.DrawOp::Font(font~))
            ops.push(@render.DrawOp::PenColor(color~))
            ops.push(
              @render.DrawOp::Text(
                pos={ x: line_x, y: line_y },
                align=line.align,
                width=line.width_pt,
                text=line.text,
              ),
            )
          }
          baseline = baseline - line.height_pt
        }
      }
      RecordNode::Group(_) =>
        record_label_ops_from_layout(ops, layout.children, name, font, color)
    }
  }
}

///|
fn record_draw_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let node = layout.node
  let pen = match node.get_attr("color") {
    Some(value) => value
    None => "black"
  }
  let style = @attrs.parse_style(node.get_attr("style"))
  let mut style_name = ""
  let is_mrecord = match node.get_attr("shape") {
    Some(value) => value.to_lower() == "mrecord"
    None => false
  }
  match dash_style_name(style) {
    Some(name) =>
      style_name = if style_name == "" { name } else { "\{style_name},\{name}" }
    None => ()
  }
  if style_name != "" {
    ops.push(@render.DrawOp::Style(name=style_name))
  }
  let color = @attrs.normalize_color(pen)
  let rect = node_rect(layout)
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  // Graphviz parity: record outline uses field bbox (height without +1 kluge).
  let draw_rect = inner_rect
  ops.push(@render.DrawOp::PenColor(color~))
  if is_mrecord {
    ops.push(
      @render.DrawOp::Bezier(
        filled=false,
        points=rounded_rect_bezier_points(draw_rect),
      ),
    )
  } else {
    ops.push(
      @render.DrawOp::Polygon(filled=false, points=outline_rect_points(draw_rect)),
    )
  }
  let label = label_text(node.get_attr("label"), node.name())
  let nodes = record_nodes(label)
  let font = @attrs.font_name(node.get_attr("fontname"))
  let size = @attrs.font_size(node.get_attr("fontsize"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let orientation = record_layout_orientation(node.graph())
  let layouts = record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    node.name(),
    font,
    size,
    pad_x_pt,
    pad_y_pt,
  )
  record_separator_ops(
    ops,
    layouts,
    orientation,
    inner_rect,
    color,
  )
  ops
}

///|
fn record_label_ops(
  layout : @layout_dot.DotLayoutNode,
) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let node = layout.node
  let label = label_text(node.get_attr("label"), node.name())
  let nodes = record_nodes(label)
  let font = @render.Font::{
    name: @attrs.font_name(node.get_attr("fontname")),
    size: @attrs.font_size(node.get_attr("fontsize")),
  }
  let color = @attrs.color(node.get_attr("fontcolor"), default="black")
  let pen_color = @attrs.normalize_color(color)
  let rect = node_rect(layout)
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let orientation = record_layout_orientation(node.graph())
  let layouts = record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    node.name(),
    font.name,
    font.size,
    pad_x_pt,
    pad_y_pt,
  )
  record_label_ops_from_layout(ops, layouts, node.name(), font, pen_color)
  ops
}

///|
fn html_text_metrics(
  text : String,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Array[LabelLine], Double, Double) {
  let resolved = resolve_label(text, name)
  label_metrics(resolved, font_name, font_size_pt)
}

///|
fn html_cell_content_size(
  content : @html_label.HtmlCellContent,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match content {
    @html_label.HtmlCellContent::Text(text) => {
      let (_lines, width_pt, height_pt) = html_text_metrics(
        text, name, font_name, font_size_pt,
      )
      (width_pt, height_pt)
    }
    @html_label.HtmlCellContent::Table(table) =>
      html_table_size(table, name, font_name, font_size_pt)
  }
}

///|
fn html_cell_size(
  table : @html_label.HtmlTable,
  cell : @html_label.HtmlCell,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (content_width, content_height) = html_cell_content_size(
    cell.content,
    name,
    font_name,
    font_size_pt,
  )
  let mut width = content_width
  let mut height = content_height
  match cell.min_width_pt {
    Some(value) => if value > width { width = value }
    None => ()
  }
  match cell.min_height_pt {
    Some(value) => if value > height { height = value }
    None => ()
  }
  width = width + table.cell_padding_pt * 2.0 + table.cell_border_pt * 2.0
  height = height + table.cell_padding_pt * 2.0 + table.cell_border_pt * 2.0
  (width, height)
}

///|
fn html_table_size(
  table : @html_label.HtmlTable,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  @html_label.html_table_size(table, cell => html_cell_size(
    table, cell, name, font_name, font_size_pt,
  ))
}

///|
fn html_table_layout(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> @html_label.HtmlTableLayout {
  @html_label.html_table_layout(table, rect, cell => html_cell_size(
    table, cell, name, font_name, font_size_pt,
  ))
}

///|
fn html_text_ops(
  ops : Array[@render.DrawOp],
  text : String,
  align : @html_label.HtmlAlign,
  valign : @html_label.HtmlVAlign,
  rect : @geom.Rect,
  name : String,
  font : @render.Font,
  color : String,
) -> Unit {
  let (lines, max_width, total_height) = html_text_metrics(
    text,
    name,
    font.name,
    font.size,
  )
  if lines.length() == 0 {
    return ()
  }
  let center_y = match valign {
    @html_label.HtmlVAlign::Top => rect.ury - total_height / 2.0
    @html_label.HtmlVAlign::Bottom => rect.lly + total_height / 2.0
    @html_label.HtmlVAlign::Middle => (rect.lly + rect.ury) / 2.0
  }
  let mut baseline = center_y + total_height / 2.0 - font.size
  let line_x = match align {
    @html_label.HtmlAlign::Left => rect.llx
    @html_label.HtmlAlign::Right => rect.urx
    @html_label.HtmlAlign::Center => (rect.llx + rect.urx) / 2.0
  }
  let line_align = match align {
    @html_label.HtmlAlign::Left => @render.TextAlign::Left
    @html_label.HtmlAlign::Right => @render.TextAlign::Right
    @html_label.HtmlAlign::Center => @render.TextAlign::Center
  }
  for line in lines {
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      ops.push(@render.DrawOp::Font(font~))
      ops.push(@render.DrawOp::PenColor(color~))
      ops.push(
        @render.DrawOp::Text(
          pos={ x: line_x, y: line_y },
          align=line_align,
          width=if line.width_pt > max_width { line.width_pt } else { max_width },
          text=line.text,
        ),
      )
    }
    baseline = baseline - line.height_pt
  }
}

///|
fn html_table_ops(
  ops : Array[@render.DrawOp],
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  name : String,
  font : @render.Font,
  text_color : String,
  stroke : String,
) -> Unit {
  let layout = html_table_layout(table, rect, name, font.name, font.size)
  match table.bg_color {
    Some(color) => {
      ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(color)))
      ops.push(@render.DrawOp::Polygon(filled=true, points=rect_points(rect)))
    }
    None => ()
  }
  if table.border_pt > 0.0 {
    ops.push(@render.DrawOp::PenColor(color=stroke))
    ops.push(
      @render.DrawOp::Polygon(filled=false, points=outline_rect_points(rect)),
    )
  }
  let pad_x = table.cell_padding_pt * layout.scale_x +
    table.cell_border_pt * layout.scale_x
  let pad_y = table.cell_padding_pt * layout.scale_y +
    table.cell_border_pt * layout.scale_y
  for cell_layout in layout.cells {
    let cell_rect = cell_layout.rect
    match cell_layout.cell.bg_color {
      Some(color) => {
        ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(color)))
        ops.push(
          @render.DrawOp::Polygon(filled=true, points=rect_points(cell_rect)),
        )
      }
      None => ()
    }
    if table.cell_border_pt > 0.0 {
      ops.push(@render.DrawOp::PenColor(color=stroke))
      ops.push(
        @render.DrawOp::Polygon(
          filled=false,
          points=outline_rect_points(cell_rect),
        ),
      )
    }
    let content_rect : @geom.Rect = {
      llx: cell_rect.llx + pad_x,
      lly: cell_rect.lly + pad_y,
      urx: cell_rect.urx - pad_x,
      ury: cell_rect.ury - pad_y,
    }
    match cell_layout.cell.content {
      @html_label.HtmlCellContent::Table(nested) =>
        html_table_ops(
          ops, nested, content_rect, name, font, text_color, stroke,
        )
      @html_label.HtmlCellContent::Text(text) =>
        if text != "" {
          html_text_ops(
            ops,
            text,
            cell_layout.cell.align,
            cell_layout.cell.valign,
            content_rect,
            name,
            font,
            text_color,
          )
        }
    }
  }
}

///|
fn html_label_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let ops : Array[@render.DrawOp] = []
  let node = layout.node
  let label = label_text(node.get_attr("label"), node.name())
  let rect = node_rect(layout)
  let font = @render.Font::{
    name: @attrs.font_name(node.get_attr("fontname")),
    size: @attrs.font_size(node.get_attr("fontsize")),
  }
  let color = @attrs.color(node.get_attr("fontcolor"), default="black")
  let pen_color = @attrs.normalize_color(color)
  let stroke = @attrs.normalize_color(
    @attrs.color(node.get_attr("color"), default="black"),
  )
  match @html_label.parse_html_label(label) {
    Some(@html_label.HtmlLabel::Table(table)) =>
      html_table_ops(ops, table, rect, node.name(), font, pen_color, stroke)
    Some(@html_label.HtmlLabel::Text(text)) =>
      if text != "" {
        html_text_ops(
          ops,
          text,
          @html_label.HtmlAlign::Center,
          @html_label.HtmlVAlign::Middle,
          rect,
          node.name(),
          font,
          pen_color,
        )
      }
    None => ()
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
  let pen = @attrs.color(node.get_attr("color"), default="black")
  let normalized_pen = @attrs.normalize_color(pen)
  let raw_shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let shape = shape_kind(node.get_attr("shape"))
  let is_doublecircle = raw_shape == "doublecircle"
  if shape == "record" {
    return record_draw_ops(layout)
  }
  if shape == "plaintext" {
    return ops
  }
  let style = @attrs.parse_style(node.get_attr("style"))
  match dash_style_name(style) {
    Some(name) => ops.push(@render.DrawOp::Style(name~))
    None => ()
  }
  ops.push(@render.DrawOp::PenColor(color=normalized_pen))
  let filled = if shape == "point" { true } else { style.filled }
  if filled {
    let fill = match node.get_attr("fillcolor") {
      Some(value) => value
      None =>
        if shape == "point" {
          pen
        } else {
          @attrs.color(node.get_attr("color"), default="lightgrey")
        }
    }
    ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(fill)))
  }
  let rect = node_rect(layout)
  match shape {
    _ if is_doublecircle =>
      match inset_rect(rect, DOUBLE_CIRCLE_GAP_PT) {
        Some(inner) => {
          ops.push(@render.DrawOp::Ellipse(filled=false, rect=inner))
          ops.push(@render.DrawOp::PenColor(color=normalized_pen))
          ops.push(@render.DrawOp::Ellipse(filled~, rect~))
        }
        None => ops.push(@render.DrawOp::Ellipse(filled~, rect~))
      }
    "msquare" => {
      let points = rect_points(rect)
      ops.push(@render.DrawOp::Polygon(filled~, points~))
      for segment in diagonal_segments(points) {
        let (start, end) = segment
        ops.push(@render.DrawOp::PenColor(color=normalized_pen))
        ops.push(@render.DrawOp::Polyline(points=[start, end]))
      }
    }
    "mdiamond" => {
      let points = mdiamond_points(rect)
      ops.push(@render.DrawOp::Polygon(filled~, points~))
      for segment in diagonal_segments(points) {
        let (start, end) = segment
        ops.push(@render.DrawOp::PenColor(color=normalized_pen))
        ops.push(@render.DrawOp::Polyline(points=[start, end]))
      }
    }
    "mcircle" => {
      ops.push(@render.DrawOp::Ellipse(filled~, rect~))
      for segment in mcircle_segments(rect) {
        let (start, end) = segment
        ops.push(@render.DrawOp::PenColor(color=normalized_pen))
        ops.push(@render.DrawOp::Polyline(points=[start, end]))
      }
    }
    "box" =>
      ops.push(@render.DrawOp::Polygon(filled~, points=rect_points(rect)))
    _ =>
      match shape_polygon_points(shape, rect) {
        Some(points) => ops.push(@render.DrawOp::Polygon(filled~, points~))
        None => ops.push(@render.DrawOp::Ellipse(filled~, rect~))
      }
  }
  ops
}

///|
fn node_label_ops(layout : @layout_dot.DotLayoutNode) -> Array[@render.DrawOp] {
  let node = layout.node
  let shape = shape_kind(node.get_attr("shape"))
  if shape == "point" {
    return []
  }
  if shape == "record" {
    return record_label_ops(layout)
  }
  let ops : Array[@render.DrawOp] = []
  let text = label_text(node.get_attr("label"), node.name())
  match @html_label.parse_html_label(text) {
    Some(_) => return html_label_ops(layout)
    None => ()
  }
  if text == "" {
    return ops
  }
  let font = @render.Font::{
    name: @attrs.font_name(node.get_attr("fontname")),
    size: @attrs.font_size(node.get_attr("fontsize")),
  }
  let color = @attrs.color(node.get_attr("fontcolor"), default="black")
  let pen_color = @attrs.normalize_color(color)
  let (lines, max_width, total_height) = label_metrics(
    text,
    font.name,
    font.size,
  )
  let pos = match layout.label_pos {
    Some(value) => value
    None => layout.pos
  }
  let mut baseline = pos.y + total_height / 2.0 - font.size
  for line in lines {
    let line_x = match line.align {
      @render.TextAlign::Left => pos.x - max_width / 2.0
      @render.TextAlign::Right => pos.x + max_width / 2.0
      @render.TextAlign::Center => pos.x
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      ops.push(@render.DrawOp::Font(font~))
      ops.push(@render.DrawOp::PenColor(color=pen_color))
      ops.push(
        @render.DrawOp::Text(
          pos={ x: line_x, y: line_y },
          align=line.align,
          width=line.width_pt,
          text=line.text,
        ),
      )
    }
    baseline = baseline - line.height_pt
  }
  ops
}

///|
fn edge_draw_ops(layout : @layout_dot.DotLayoutEdge) -> Array[@render.DrawOp] {
  let edge = layout.edge
  let ops : Array[@render.DrawOp] = []
  let pen = @attrs.color(edge.get_attr("color"), default="black")
  let style = @attrs.parse_style(edge.get_attr("style"))
  match dash_style_name(style) {
    Some(name) => ops.push(@render.DrawOp::Style(name~))
    None => ()
  }
  ops.push(@render.DrawOp::PenColor(color=@attrs.normalize_color(pen)))
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
    name: @attrs.font_name(edge.get_attr("fontname")),
    size: @attrs.font_size(edge.get_attr("fontsize")),
  }
  let color = @attrs.color(edge.get_attr("fontcolor"), default="black")
  let pen_color = @attrs.normalize_color(color)
  let (lines, max_width, total_height) = label_metrics(
    text,
    font.name,
    font.size,
  )
  let pos = match layout.label_pos {
    Some(value) => value
    None =>
      match layout.splines.get(0) {
        Some(spline) => spline_midpoint(spline)
        None => { x: 0.0, y: 0.0 }
      }
  }
  let mut baseline = pos.y + total_height / 2.0 - font.size
  for line in lines {
    let line_x = match line.align {
      @render.TextAlign::Left => pos.x - max_width / 2.0
      @render.TextAlign::Right => pos.x + max_width / 2.0
      @render.TextAlign::Center => pos.x
    }
    let line_y = baseline + line.yoffset_centerline
    if line.text != "" {
      ops.push(@render.DrawOp::Font(font~))
      ops.push(@render.DrawOp::PenColor(color=pen_color))
      ops.push(
        @render.DrawOp::Text(
          pos={ x: line_x, y: line_y },
          align=line.align,
          width=line.width_pt,
          text=line.text,
        ),
      )
    }
    baseline = baseline - line.height_pt
  }
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
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (String, Double, Double)? {
  match graph_label_text(graph) {
    Some(text) => {
      let size = @attrs.font_size(graph.get_attr("fontsize"))
      let name = @attrs.font_name(graph.get_attr("fontname"))
      let (width_pt, height_pt) = label_text_dimensions(text, name, size)
      Some((text, width_pt * GRAPH_LABEL_WIDTH_SCALE, height_pt))
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
    let fill = @attrs.color(graph.get_attr("bgcolor"), default="white")
    ops.push(@render.DrawOp::PenColor(color="#fffffe00"))
    ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(fill)))
    ops.push(
      @render.DrawOp::Polygon(filled=true, points=outline_rect_points(bbox)),
    )
    return ops
  }
  if is_cluster_graph(graph) {
    let style = @attrs.parse_style(graph.get_attr("style"))
    match dash_style_name(style) {
      Some(name) => ops.push(@render.DrawOp::Style(name~))
      None => ()
    }
    let color = @attrs.color(graph.get_attr("color"), default="black")
    ops.push(@render.DrawOp::PenColor(color=@attrs.normalize_color(color)))
    let fill = if style.filled {
      Some(@attrs.color(graph.get_attr("fillcolor"), default=color))
    } else {
      graph.get_attr("bgcolor")
    }
    match fill {
      Some(value) => {
        ops.push(@render.DrawOp::FillColor(color=@attrs.normalize_color(value)))
        ops.push(
          @render.DrawOp::Polygon(filled=true, points=outline_rect_points(bbox)),
        )
      }
      None =>
        ops.push(
          @render.DrawOp::Polygon(
            filled=false,
            points=outline_rect_points(bbox),
          ),
        )
    }
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
  if !graph.is_root() && !is_cluster_graph(graph) {
    return ops
  }
  match graph_label_metrics(graph) {
    Some((text, width_pt, height_pt)) => {
      let font = @render.Font::{
        name: @attrs.font_name(graph.get_attr("fontname")),
        size: @attrs.font_size(graph.get_attr("fontsize")),
      }
      let color = @attrs.color(graph.get_attr("fontcolor"), default="black")
      let pen_color = @attrs.normalize_color(color)
      let pos = match layout.label_pos {
        Some(value) => value
        None => graph_label_pos(layout.bbox, height_pt)
      }
      let (lines, _max_width, total_height) = label_metrics(
        text,
        font.name,
        font.size,
      )
      let mut baseline = pos.y + total_height / 2.0 - font.size
      for line in lines {
        let line_x = match line.align {
          @render.TextAlign::Left => pos.x - width_pt / 2.0
          @render.TextAlign::Right => pos.x + width_pt / 2.0
          @render.TextAlign::Center => pos.x
        }
        let line_y = baseline + line.yoffset_centerline
        if line.text != "" {
          ops.push(@render.DrawOp::Font(font~))
          ops.push(@render.DrawOp::PenColor(color=pen_color))
          ops.push(
            @render.DrawOp::Text(
              pos={ x: line_x, y: line_y },
              align=line.align,
              width=line.width_pt,
              text=line.text,
            ),
          )
        }
        baseline = baseline - line.height_pt
      }
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
  if graph.is_root() || is_cluster_graph(graph) {
    match graph_label_metrics(graph) {
      Some((_text, width_pt, height_pt)) => {
        let pos = match layout.label_pos {
          Some(value) => value
          None => graph_label_pos(layout.bbox, height_pt)
        }
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
  attach_xdot_attrs(layout, options~)
  @dot.write_dot(layout.graph)
}
