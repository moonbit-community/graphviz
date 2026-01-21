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

const LINE_SPACING : Double = 1.2

const TEXT_SCALE : Double = 0.9706

const PAD_X_PT : Double = 16.0
const PAD_Y_PT : Double = 8.0

///|
fn font_width_scale(font_name : String) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.02
  } else {
    1.0
  }
}

priv struct LabelLine {
  text : String
  align : @render.TextAlign
  width_pt : Double
}

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
    'm' => 820
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
fn push_label_line(
  lines : Array[LabelLine],
  text : String,
  align : @render.TextAlign,
  width_units : Int,
  font_size_pt : Double,
) -> Unit {
  let width_pt = width_units.to_double() * font_size_pt * TEXT_SCALE / 1000.0
  lines.push({ text, align, width_pt })
}

// Heuristic line heights tuned to Graphviz xdot baselines for common fonts.
fn line_height_scale(font_name : String, font_size_pt : Double) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.125
  } else if lower.contains("times") {
    let min_size = 10.0
    let max_size = 14.0
    if font_size_pt <= min_size {
      1.125
    } else if font_size_pt >= max_size {
      1.1786
    } else {
      let t = (font_size_pt - min_size) / (max_size - min_size)
      1.125 + t * (1.1786 - 1.125)
    }
  } else {
    LINE_SPACING
  }
}

///|
fn line_height(font_name : String, font_size_pt : Double) -> Double {
  font_size_pt * line_height_scale(font_name, font_size_pt)
}

///|
fn centerline_offset(font_size_pt : Double) -> Double {
  font_size_pt * 0.05
}

///|
fn label_lines(label : String, font_size_pt : Double) -> Array[LabelLine] {
  let lines : Array[LabelLine] = []
  let mut sb = StringBuilder::new()
  let mut current_units = 0
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
            current_units,
            font_size_pt,
          )
          sb = StringBuilder::new()
          current_units = 0
          has_chars = false
        }
        'l' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Left,
            current_units,
            font_size_pt,
          )
          sb = StringBuilder::new()
          current_units = 0
          has_chars = false
        }
        'r' => {
          push_label_line(
            lines,
            sb.to_string(),
            @render.TextAlign::Right,
            current_units,
            font_size_pt,
          )
          sb = StringBuilder::new()
          current_units = 0
          has_chars = false
        }
        _ => {
          sb.write_char(ch)
          current_units = current_units + char_width_units(ch)
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
        current_units,
        font_size_pt,
      )
      sb = StringBuilder::new()
      current_units = 0
      has_chars = false
      continue
    }
    sb.write_char(ch)
    current_units = current_units + char_width_units(ch)
    has_chars = true
  }
  if escaping {
    sb.write_char('\\')
    current_units = current_units + char_width_units('\\')
    has_chars = true
  }
  if has_chars || lines.length() == 0 {
    push_label_line(
      lines,
      sb.to_string(),
      @render.TextAlign::Center,
      current_units,
      font_size_pt,
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
  let raw_lines = label_lines(label, font_size_pt)
  let width_scale = font_width_scale(font_name)
  let lines : Array[LabelLine] = []
  let mut max_width = 0.0
  for line in raw_lines {
    let width_pt = line.width_pt * width_scale
    if width_pt > max_width {
      max_width = width_pt
    }
    lines.push({ text: line.text, align: line.align, width_pt })
  }
  let height_pt = line_height(font_name, font_size_pt) * lines.length().to_double()
  (lines, max_width, height_pt)
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
fn stroke_dash_attr(style : @attrs.StyleFlags) -> String {
  if style.dashed {
    " stroke-dasharray=\"5,5\""
  } else if style.dotted {
    " stroke-dasharray=\"2,4\""
  } else {
    ""
  }
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
        Some(resolve_label(value, ""))
      }
    }
    None => None
  }
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (String, Double, Double)? {
  match graph_label_text(graph) {
    Some(text) => {
      let size = @attrs.font_size(graph.get_attr("fontsize"))
      let name = @attrs.font_name(graph.get_attr("fontname"))
      let (_, width_pt, height_pt) = label_metrics(text, name, size)
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
    "record" => "record"
    "point" | "dot" => "point"
    "ellipse" | "oval" | "circle" => "ellipse"
    _ => "ellipse"
  }
}

///|
fn cluster_fill_color(graph : @cgraph.Graph) -> String? {
  let style = @attrs.parse_style(graph.get_attr("style"))
  if style.filled {
    let fill = @attrs.color(
      graph.get_attr("fillcolor"),
      default=@attrs.color(graph.get_attr("color"), default="black"),
    )
    Some(fill)
  } else {
    graph.get_attr("bgcolor")
  }
}

///|
fn node_padding(node : @cgraph.Node) -> (Double, Double) {
  let mut pad_x_pt = PAD_X_PT
  let mut pad_y_pt = PAD_Y_PT
  match node.get_attr("margin") {
    Some(value) => {
      match parse_margin(value) {
        Some((margin_x, margin_y)) => {
          pad_x_pt = margin_x * 72.0 * 2.0
          pad_y_pt = margin_y * 72.0 * 2.0
        }
        None => ()
      }
    }
    None => ()
  }
  (pad_x_pt, pad_y_pt)
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
  @attrs.parse_double(edge.get_attr("arrowsize"), 1.0)
}

///|
fn arrow_primitives(
  layout : @layout_dot.DotLayoutEdge,
  at_head : Bool,
) -> Array[@render.DrawOp] {
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
  let arrowhead = if at_head {
    layout.edge.get_attr("arrowhead")
  } else {
    layout.edge.get_attr("arrowtail")
  }
  @render.arrow_primitives(tip, from, arrow_size(layout.edge), arrowhead)
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
fn shape_polygon_points(kind : String, rect : @geom.Rect) -> Array[@geom.Point]? {
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
priv enum RecordNode {
  Field(RecordField)
  Group(Array[RecordNode])
}

///|
fn toggle_record_orientation(orientation : RecordOrientation) -> RecordOrientation {
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
      if text != "" {
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
  if field.has_prefix("<") {
    match field.find(">") {
      Some(pos) => {
        let len = field.length()
        let text = if pos + 1 < len {
          field.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
        { text: text }
      }
      None => { text: field }
    }
  } else {
    { text: field }
  }
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
        let (_, text_width_pt, text_height_pt) =
          label_metrics(text, font_name, font_size_pt)
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
    nodes,
    orientation,
    name,
    font_name,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
  )
  if sizes.length() == 0 {
    return { width_pt: 0.0, height_pt: 0.0 }
  }
  let mut width = 0.0
  let mut height = 0.0
  match orientation {
    RecordOrientation::Vertical => {
      for size in sizes {
        if size.width_pt > width {
          width = size.width_pt
        }
        height = height + size.height_pt
      }
    }
    RecordOrientation::Horizontal => {
      for size in sizes {
        if size.height_pt > height {
          height = size.height_pt
        }
        width = width + size.width_pt
      }
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
    nodes,
    orientation,
    name,
    font_name,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
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
    if axis_sum <= 0.0 {
      let equal = axis_total / axis_sizes.length().to_double()
      for i in 0..<axis_sizes.length() {
        axis_sizes[i] = equal
      }
    } else {
      let scale = axis_total / axis_sum
      for i in 0..<axis_sizes.length() {
        axis_sizes[i] = axis_sizes[i] * scale
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
    let child_rect = match orientation {
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
      RecordNode::Field(_) => layouts.push({ rect: child_rect, node: nodes[i], children: [] })
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
        layouts.push({ rect: child_rect, node: nodes[i], children: child_layouts })
      }
    }
  }
  layouts
}

///|
fn write_record_separators(
  sb : StringBuilder,
  layouts : Array[RecordLayout],
  orientation : RecordOrientation,
  rect : @geom.Rect,
  stroke : String,
  stroke_dash : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  if layouts.length() > 1 {
    match orientation {
      RecordOrientation::Vertical => {
        let x1 = rect.llx - bbox.llx
        let x2 = rect.urx - bbox.llx
        for i in 1..<layouts.length() {
          let line_y = layouts[i].rect.ury - bbox.lly
          write_line(
            sb,
            "<line x1=\"\{x1}\" y1=\"\{line_y}\" x2=\"\{x2}\" y2=\"\{line_y}\" stroke=\"\{stroke}\"\{stroke_dash}/>",
            indent,
            pretty,
          )
        }
      }
      RecordOrientation::Horizontal => {
        let y1 = rect.lly - bbox.lly
        let y2 = rect.ury - bbox.lly
        for i in 1..<layouts.length() {
          let line_x = layouts[i].rect.llx - bbox.llx
          write_line(
            sb,
            "<line x1=\"\{line_x}\" y1=\"\{y1}\" x2=\"\{line_x}\" y2=\"\{y2}\" stroke=\"\{stroke}\"\{stroke_dash}/>",
            indent,
            pretty,
          )
        }
      }
    }
  }
  for layout in layouts {
    match layout.node {
      RecordNode::Group(_) => write_record_separators(
        sb,
        layout.children,
        toggle_record_orientation(orientation),
        layout.rect,
        stroke,
        stroke_dash,
        bbox,
        indent,
        pretty,
      )
      _ => ()
    }
  }
}

///|
fn write_record_labels(
  sb : StringBuilder,
  layouts : Array[RecordLayout],
  name : String,
  font : String,
  size : Double,
  color : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  for layout in layouts {
    match layout.node {
      RecordNode::Field(field) => {
        let text = resolve_label(field.text, name)
        if text != "" {
          let center = @geom.Point::{
            x: (layout.rect.llx + layout.rect.urx) / 2.0,
            y: (layout.rect.lly + layout.rect.ury) / 2.0,
          }
          write_label_lines(
            sb,
            text,
            font,
            size,
            color,
            center,
            bbox,
            indent,
            pretty,
          )
        }
      }
      RecordNode::Group(_) => write_record_labels(
        sb,
        layout.children,
        name,
        font,
        size,
        color,
        bbox,
        indent,
        pretty,
      )
    }
  }
}

///|
fn write_record_node(
  sb : StringBuilder,
  layout : @layout_dot.DotLayoutNode,
  rect : @geom.Rect,
  stroke : String,
  fill : String,
  stroke_dash : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  let node = layout.node
  let label = label_text(node.get_attr("label"), node.name())
  let nodes = record_nodes(label)
  let x = rect.llx - bbox.llx
  let y = rect.lly - bbox.lly
  let w = rect.urx - rect.llx
  let h = rect.ury - rect.lly
  write_line(
    sb,
    "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{fill}\" stroke=\"\{stroke}\"\{stroke_dash}/>",
    indent,
    pretty,
  )
  let font = @attrs.font_name(node.get_attr("fontname"))
  let size = @attrs.font_size(node.get_attr("fontsize"))
  let color = @attrs.color(node.get_attr("fontcolor"), default="black")
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let layouts = record_layout_nodes(
    nodes,
    rect,
    RecordOrientation::Horizontal,
    node.name(),
    font,
    size,
    pad_x_pt,
    pad_y_pt,
  )
  write_record_separators(
    sb,
    layouts,
    RecordOrientation::Horizontal,
    rect,
    stroke,
    stroke_dash,
    bbox,
    indent,
    pretty,
  )
  write_record_labels(
    sb,
    layouts,
    node.name(),
    font,
    size,
    color,
    bbox,
    indent,
    pretty,
  )
}

///|
priv enum HtmlAlign {
  Left
  Center
  Right
}

///|
priv enum HtmlVAlign {
  Top
  Middle
  Bottom
}

///|
priv enum HtmlCellContent {
  Text(String)
  Table(HtmlTable)
}

///|
priv struct HtmlCell {
  content : HtmlCellContent
  col_span : Int
  row_span : Int
  align : HtmlAlign
  valign : HtmlVAlign
  bg_color : String?
  min_width_pt : Double?
  min_height_pt : Double?
}

///|
priv struct HtmlRow {
  cells : Array[HtmlCell]
}

///|
priv struct HtmlTable {
  rows : Array[HtmlRow]
  border_pt : Double
  cell_border_pt : Double
  cell_spacing_pt : Double
  cell_padding_pt : Double
  bg_color : String?
}

///|
priv enum HtmlLabel {
  Text(String)
  Table(HtmlTable)
}

///|
priv struct HtmlCellPlacement {
  cell : HtmlCell
  row : Int
  col : Int
}

///|
priv struct HtmlTableMetrics {
  placements : Array[HtmlCellPlacement]
  col_widths : Array[Double]
  row_heights : Array[Double]
  total_width : Double
  total_height : Double
}

///|
priv struct HtmlCellLayout {
  rect : @geom.Rect
  cell : HtmlCell
}

///|
priv struct HtmlTableLayout {
  cells : Array[HtmlCellLayout]
  scale_x : Double
  scale_y : Double
}

///|
priv struct HtmlParser {
  chars : Array[Char]
  mut index : Int
}

///|
priv enum HtmlTag {
  Start(String, Map[String, String], Bool)
  End(String)
}

///|
fn is_html_label_text(label : String) -> Bool {
  label.length() >= 4 && label.has_prefix("<<") && label.has_suffix(">>")
}

///|
fn strip_html_wrappers(label : String) -> String? {
  if !is_html_label_text(label) {
    return None
  }
  let len = label.length()
  let inner = label.unsafe_substring(start=1, end=len - 1)
  let unescaped = inner.replace_all(old="\\\"", new="\"").replace_all(old="\\'", new="'")
  Some(unescaped)
}

///|
fn html_parser_peek(parser : HtmlParser) -> Char? {
  if parser.index < parser.chars.length() {
    Some(parser.chars[parser.index])
  } else {
    None
  }
}

///|
fn html_parser_advance(parser : HtmlParser) -> Char? {
  if parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    parser.index = parser.index + 1
    Some(ch)
  } else {
    None
  }
}

///|
fn html_parser_skip_whitespace(parser : HtmlParser) -> Unit {
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if ch.is_whitespace() {
      parser.index = parser.index + 1
    } else {
      break
    }
  }
}

///|
fn html_read_name(parser : HtmlParser) -> String {
  let sb = StringBuilder::new()
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if (ch.is_ascii_alphabetic() || ch.is_ascii_digit()) || ch == '_' || ch == '-' || ch == ':' {
      sb.write_char(ch)
      parser.index = parser.index + 1
    } else {
      break
    }
  }
  sb.to_string().to_lower()
}

///|
fn html_read_attr_value(parser : HtmlParser) -> String {
  match html_parser_peek(parser) {
    Some('"') => {
      let _ = html_parser_advance(parser)
      let sb = StringBuilder::new()
      while parser.index < parser.chars.length() {
        let ch = parser.chars[parser.index]
        parser.index = parser.index + 1
        if ch == '"' {
          break
        }
        sb.write_char(ch)
      }
      sb.to_string()
    }
    Some('\'') => {
      let _ = html_parser_advance(parser)
      let sb = StringBuilder::new()
      while parser.index < parser.chars.length() {
        let ch = parser.chars[parser.index]
        parser.index = parser.index + 1
        if ch == '\'' {
          break
        }
        sb.write_char(ch)
      }
      sb.to_string()
    }
    _ => {
      let sb = StringBuilder::new()
      while parser.index < parser.chars.length() {
        let ch = parser.chars[parser.index]
        if ch.is_whitespace() || ch == '>' || ch == '/' {
          break
        }
        sb.write_char(ch)
        parser.index = parser.index + 1
      }
      sb.to_string()
    }
  }
}

///|
fn html_parse_tag(parser : HtmlParser) -> HtmlTag? {
  match html_parser_peek(parser) {
    Some('<') => ()
    _ => return None
  }
  let _ = html_parser_advance(parser)
  match html_parser_peek(parser) {
    Some('/') => {
      let _ = html_parser_advance(parser)
      html_parser_skip_whitespace(parser)
      let name = html_read_name(parser)
      while parser.index < parser.chars.length() {
        if parser.chars[parser.index] == '>' {
          parser.index = parser.index + 1
          break
        }
        parser.index = parser.index + 1
      }
      Some(HtmlTag::End(name))
    }
    _ => {
      let name = html_read_name(parser)
      let attrs : Map[String, String] = Map::new()
      let mut self_closing = false
      while parser.index < parser.chars.length() {
        html_parser_skip_whitespace(parser)
        match html_parser_peek(parser) {
          Some('/') => {
            self_closing = true
            let _ = html_parser_advance(parser)
            html_parser_skip_whitespace(parser)
            match html_parser_peek(parser) {
              Some('>') => {
                parser.index = parser.index + 1
                break
              }
              _ => ()
            }
          }
          Some('>') => {
            parser.index = parser.index + 1
            break
          }
          None => break
          _ => {
            let key = html_read_name(parser)
            if key == "" {
              let _ = html_parser_advance(parser)
              continue
            }
            html_parser_skip_whitespace(parser)
            match html_parser_peek(parser) {
              Some('=') => {
                let _ = html_parser_advance(parser)
                html_parser_skip_whitespace(parser)
                let value = html_read_attr_value(parser)
                attrs[key] = value
              }
              _ => attrs[key] = ""
            }
          }
        }
      }
      Some(HtmlTag::Start(name, attrs, self_closing))
    }
  }
}

///|
fn html_parse_text(parser : HtmlParser) -> String {
  let sb = StringBuilder::new()
  while parser.index < parser.chars.length() {
    let ch = parser.chars[parser.index]
    if ch == '<' {
      break
    }
    sb.write_char(ch)
    parser.index = parser.index + 1
  }
  sb.to_string()
}

///|
fn html_is_whitespace_only(text : String) -> Bool {
  for ch in text {
    if !ch.is_whitespace() {
      return false
    }
  }
  true
}

///|
fn html_collapse_whitespace(text : String) -> String {
  let sb = StringBuilder::new()
  let mut in_space = false
  for ch in text {
    if ch.is_whitespace() {
      if !in_space {
        sb.write_char(' ')
        in_space = true
      }
    } else {
      sb.write_char(ch)
      in_space = false
    }
  }
  let collapsed = sb.to_string()
  if html_is_whitespace_only(collapsed) {
    ""
  } else {
    let mut start = 0
    let mut end = collapsed.length()
    while start < end && collapsed[start] == ' ' {
      start = start + 1
    }
    while end > start && collapsed[end - 1] == ' ' {
      end = end - 1
    }
    if start == 0 && end == collapsed.length() {
      collapsed
    } else {
      collapsed.unsafe_substring(start=start, end=end)
    }
  }
}

///|
fn html_align_from(value : String?) -> HtmlAlign {
  match value {
    Some(text) => {
      match text.to_lower() {
        "left" => HtmlAlign::Left
        "right" => HtmlAlign::Right
        _ => HtmlAlign::Center
      }
    }
    None => HtmlAlign::Center
  }
}

///|
fn html_valign_from(value : String?) -> HtmlVAlign {
  match value {
    Some(text) => {
      match text.to_lower() {
        "top" => HtmlVAlign::Top
        "bottom" => HtmlVAlign::Bottom
        _ => HtmlVAlign::Middle
      }
    }
    None => HtmlVAlign::Middle
  }
}

///|
fn html_parse_int(value : String?, fallback : Int) -> Int {
  match value {
    Some(text) => {
      let parsed = parse_double(text, fallback.to_double()).round().to_int()
      if parsed <= 0 { fallback } else { parsed }
    }
    None => fallback
  }
}

///|
fn html_parse_double(value : String?, fallback : Double) -> Double {
  match value {
    Some(text) => parse_double(text, fallback)
    None => fallback
  }
}

///|
fn parse_html_cell_content(parser : HtmlParser) -> HtmlCellContent {
  let mut nested : HtmlTable? = None
  let sb = StringBuilder::new()
  while parser.index < parser.chars.length() {
    html_parser_skip_whitespace(parser)
    match html_parser_peek(parser) {
      Some('<') => {
        match html_parse_tag(parser) {
          Some(HtmlTag::End(name)) => {
            if name == "td" {
              break
            }
          }
          Some(HtmlTag::Start(name, attrs, _self_closing)) => {
            if name == "br" {
              sb.write_char('\n')
            } else if name == "table" {
              nested = Some(parse_html_table_from_attrs(parser, attrs))
            } else {
              // Ignore other tags.
            }
          }
          None => {
            let text = html_parse_text(parser)
            if !html_is_whitespace_only(text) {
              sb.write_string(html_collapse_whitespace(text))
            }
          }
        }
      }
      None => break
      _ => {
        let text = html_parse_text(parser)
        if !html_is_whitespace_only(text) {
          sb.write_string(html_collapse_whitespace(text))
        }
      }
    }
  }
  match nested {
    Some(table) => HtmlCellContent::Table(table)
    None => HtmlCellContent::Text(sb.to_string())
  }
}

///|
fn parse_html_cell_from_attrs(parser : HtmlParser, attrs : Map[String, String]) -> HtmlCell {
  let col_span = html_parse_int(attrs.get("colspan"), 1)
  let row_span = html_parse_int(attrs.get("rowspan"), 1)
  let align = html_align_from(attrs.get("align"))
  let valign = html_valign_from(attrs.get("valign"))
  let bg_color = attrs.get("bgcolor")
  let min_width_pt = match attrs.get("width") {
    Some(value) => Some(parse_double(value, 0.0))
    None => None
  }
  let min_height_pt = match attrs.get("height") {
    Some(value) => Some(parse_double(value, 0.0))
    None => None
  }
  let content = parse_html_cell_content(parser)
  { content, col_span, row_span, align, valign, bg_color, min_width_pt, min_height_pt }
}

///|
fn parse_html_row(parser : HtmlParser) -> HtmlRow {
  let cells : Array[HtmlCell] = []
  while parser.index < parser.chars.length() {
    html_parser_skip_whitespace(parser)
    match html_parser_peek(parser) {
      Some('<') => {
        match html_parse_tag(parser) {
          Some(HtmlTag::End(name)) => {
            if name == "tr" {
              break
            }
          }
          Some(HtmlTag::Start(name, attrs, _self_closing)) => {
            if name == "td" || name == "th" {
              cells.push(parse_html_cell_from_attrs(parser, attrs))
            } else if name == "tr" {
              break
            } else {
              // Ignore other tags.
            }
          }
          None => {
            let _ = html_parse_text(parser)
          }
        }
      }
      None => break
      _ => {
        let _ = html_parse_text(parser)
      }
    }
  }
  HtmlRow::{ cells }
}

///|
fn parse_html_table_from_attrs(parser : HtmlParser, attrs : Map[String, String]) -> HtmlTable {
  let border_pt = html_parse_double(attrs.get("border"), 0.0)
  let cell_border_pt = html_parse_double(attrs.get("cellborder"), 0.0)
  let cell_spacing_pt = html_parse_double(attrs.get("cellspacing"), 2.0)
  let cell_padding_pt = html_parse_double(attrs.get("cellpadding"), 2.0)
  let bg_color = attrs.get("bgcolor")
  let rows : Array[HtmlRow] = []
  while parser.index < parser.chars.length() {
    html_parser_skip_whitespace(parser)
    match html_parser_peek(parser) {
      Some('<') => {
        match html_parse_tag(parser) {
          Some(HtmlTag::End(name)) => {
            if name == "table" {
              break
            }
          }
          Some(HtmlTag::Start(name, attrs, _self_closing)) => {
            if name == "tr" {
              rows.push(parse_html_row(parser))
            } else if name == "table" {
              let _ = parse_html_table_from_attrs(parser, attrs)
            } else {
              // Ignore other tags.
            }
          }
          None => {
            let _ = html_parse_text(parser)
          }
        }
      }
      None => break
      _ => {
        let _ = html_parse_text(parser)
      }
    }
  }
  { rows, border_pt, cell_border_pt, cell_spacing_pt, cell_padding_pt, bg_color }
}

///|
fn parse_html_label(label : String) -> HtmlLabel? {
  match strip_html_wrappers(label) {
    Some(value) => {
      let chars : Array[Char] = []
      for ch in value {
        chars.push(ch)
      }
      let parser = HtmlParser::{ chars, index: 0 }
      html_parser_skip_whitespace(parser)
      match html_parse_tag(parser) {
        Some(HtmlTag::Start(name, attrs, _self_closing)) => {
          if name == "table" {
            Some(HtmlLabel::Table(parse_html_table_from_attrs(parser, attrs)))
          } else if name == "br" {
            Some(HtmlLabel::Text("\n"))
          } else {
            let mut text = html_parse_text(parser)
            if html_is_whitespace_only(text) {
              text = ""
            } else {
              text = html_collapse_whitespace(text)
            }
            Some(HtmlLabel::Text(text))
          }
        }
        _ => {
          let text = html_parse_text(parser)
          if html_is_whitespace_only(text) {
            Some(HtmlLabel::Text(""))
          } else {
            Some(HtmlLabel::Text(html_collapse_whitespace(text)))
          }
        }
      }
    }
    None => None
  }
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
  content : HtmlCellContent,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match content {
    HtmlCellContent::Text(text) => {
      let (_lines, width_pt, height_pt) =
        html_text_metrics(text, name, font_name, font_size_pt)
      (width_pt, height_pt)
    }
    HtmlCellContent::Table(table) => html_table_size(table, name, font_name, font_size_pt)
  }
}

///|
fn html_cell_size(
  table : HtmlTable,
  cell : HtmlCell,
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
    Some(value) => {
      if value > width {
        width = value
      }
    }
    None => ()
  }
  match cell.min_height_pt {
    Some(value) => {
      if value > height {
        height = value
      }
    }
    None => ()
  }
  width = width + table.cell_padding_pt * 2.0 + table.cell_border_pt * 2.0
  height = height + table.cell_padding_pt * 2.0 + table.cell_border_pt * 2.0
  (width, height)
}

///|
fn html_table_placements(table : HtmlTable) -> (Array[HtmlCellPlacement], Int, Int) {
  let placements : Array[HtmlCellPlacement] = []
  let mut col_count = 0
  let mut row_index = 0
  let row_spans : Array[Int] = []
  for row in table.rows {
    let mut col_index = 0
    for cell in row.cells {
      while col_index < row_spans.length() && row_spans[col_index] > 0 {
        col_index = col_index + 1
      }
      let needed = col_index + cell.col_span
      while row_spans.length() < needed {
        row_spans.push(0)
      }
      placements.push({ cell, row: row_index, col: col_index })
      if cell.row_span > 1 {
        for i in col_index..<needed {
          row_spans[i] = cell.row_span - 1
        }
      }
      let end_col = col_index + cell.col_span
      if end_col > col_count {
        col_count = end_col
      }
      col_index = col_index + cell.col_span
    }
    for i in 0..<row_spans.length() {
      if row_spans[i] > 0 {
        row_spans[i] = row_spans[i] - 1
      }
    }
    row_index = row_index + 1
  }
  (placements, table.rows.length(), col_count)
}

///|
fn html_table_metrics(
  table : HtmlTable,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> HtmlTableMetrics {
  let (placements, row_count, col_count) = html_table_placements(table)
  let col_widths : Array[Double] = []
  for _ in 0..<col_count {
    col_widths.push(0.0)
  }
  let row_heights : Array[Double] = []
  for _ in 0..<row_count {
    row_heights.push(0.0)
  }
  for placement in placements {
    let cell = placement.cell
    let (cell_width, cell_height) = html_cell_size(
      table,
      cell,
      name,
      font_name,
      font_size_pt,
    )
    if cell.col_span <= 1 {
      let col = placement.col
      if col < col_widths.length() && cell_width > col_widths[col] {
        col_widths[col] = cell_width
      }
    } else {
      let start = placement.col
      let end = placement.col + cell.col_span
      let mut current = 0.0
      for i in start..<end {
        if i < col_widths.length() {
          current = current + col_widths[i]
        }
      }
      if current < cell_width && cell.col_span > 0 {
        let extra = (cell_width - current) / cell.col_span.to_double()
        for i in start..<end {
          if i < col_widths.length() {
            col_widths[i] = col_widths[i] + extra
          }
        }
      }
    }
    if cell.row_span <= 1 {
      let row = placement.row
      if row < row_heights.length() && cell_height > row_heights[row] {
        row_heights[row] = cell_height
      }
    } else {
      let start = placement.row
      let end = placement.row + cell.row_span
      let mut current = 0.0
      for i in start..<end {
        if i < row_heights.length() {
          current = current + row_heights[i]
        }
      }
      if current < cell_height && cell.row_span > 0 {
        let extra = (cell_height - current) / cell.row_span.to_double()
        for i in start..<end {
          if i < row_heights.length() {
            row_heights[i] = row_heights[i] + extra
          }
        }
      }
    }
  }
  let mut total_width = table.border_pt * 2.0
  if col_widths.length() > 0 {
    for width in col_widths {
      total_width = total_width + width
    }
    total_width = total_width + table.cell_spacing_pt * (col_widths.length() - 1).to_double()
  }
  let mut total_height = table.border_pt * 2.0
  if row_heights.length() > 0 {
    for height in row_heights {
      total_height = total_height + height
    }
    total_height = total_height + table.cell_spacing_pt * (row_heights.length() - 1).to_double()
  }
  {
    placements,
    col_widths,
    row_heights,
    total_width,
    total_height,
  }
}

///|
fn html_table_size(
  table : HtmlTable,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let metrics = html_table_metrics(table, name, font_name, font_size_pt)
  (metrics.total_width, metrics.total_height)
}

///|
fn html_table_layout(
  table : HtmlTable,
  rect : @geom.Rect,
  name : String,
  font_name : String,
  font_size_pt : Double,
) -> HtmlTableLayout {
  let metrics = html_table_metrics(table, name, font_name, font_size_pt)
  if metrics.total_width <= 0.0 || metrics.total_height <= 0.0 {
    return {
      cells: [],
      scale_x: 1.0,
      scale_y: 1.0,
    }
  }
  let scale_x = (rect.urx - rect.llx) / metrics.total_width
  let scale_y = (rect.ury - rect.lly) / metrics.total_height
  let border_x = table.border_pt * scale_x
  let border_y = table.border_pt * scale_y
  let spacing_x = table.cell_spacing_pt * scale_x
  let spacing_y = table.cell_spacing_pt * scale_y
  let col_positions : Array[(Double, Double)] = []
  let mut cursor_x = rect.llx + border_x
  for width in metrics.col_widths {
    let scaled = width * scale_x
    let start = cursor_x
    let end = start + scaled
    col_positions.push((start, end))
    cursor_x = end + spacing_x
  }
  let row_positions : Array[(Double, Double)] = []
  let mut cursor_y = rect.ury - border_y
  for height in metrics.row_heights {
    let scaled = height * scale_y
    let top = cursor_y
    let bottom = top - scaled
    row_positions.push((top, bottom))
    cursor_y = bottom - spacing_y
  }
  let cells : Array[HtmlCellLayout] = []
  for placement in metrics.placements {
    let start_col = placement.col
    let end_col = placement.col + placement.cell.col_span - 1
    let start_row = placement.row
    let end_row = placement.row + placement.cell.row_span - 1
    if start_col >= col_positions.length() || end_col >= col_positions.length() {
      continue
    }
    if start_row >= row_positions.length() || end_row >= row_positions.length() {
      continue
    }
    let llx = col_positions[start_col].0
    let urx = col_positions[end_col].1
    let ury = row_positions[start_row].0
    let lly = row_positions[end_row].1
    cells.push({
      rect: { llx, lly, urx, ury },
      cell: placement.cell,
    })
  }
  { cells, scale_x, scale_y }
}

///|
fn write_html_text_lines(
  sb : StringBuilder,
  text : String,
  align : HtmlAlign,
  valign : HtmlVAlign,
  rect : @geom.Rect,
  name : String,
  font : String,
  size : Double,
  color : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  let (lines, _max_width, total_height) = html_text_metrics(text, name, font, size)
  if lines.length() == 0 {
    return ()
  }
  let line_step = line_height(font, size)
  let center_y = match valign {
    HtmlVAlign::Top => rect.ury - total_height / 2.0
    HtmlVAlign::Bottom => rect.lly + total_height / 2.0
    HtmlVAlign::Middle => (rect.lly + rect.ury) / 2.0
  }
  let start_y = center_y + total_height / 2.0 - size + centerline_offset(size)
  let line_x = match align {
    HtmlAlign::Left => rect.llx
    HtmlAlign::Right => rect.urx
    HtmlAlign::Center => (rect.llx + rect.urx) / 2.0
  }
  let anchor = match align {
    HtmlAlign::Left => "start"
    HtmlAlign::Right => "end"
    HtmlAlign::Center => "middle"
  }
  for i in 0..<lines.length() {
    let line = lines[i]
    if line.text == "" {
      continue
    }
    let line_y = start_y - line_step * i.to_double()
    let x = line_x - bbox.llx
    let y = bbox.lly - line_y
    let escaped = escape_xml(line.text)
    write_line(
      sb,
      "<text x=\"\{x}\" y=\"\{y}\" transform=\"scale(1 -1)\" text-anchor=\"\{anchor}\" font-family=\"\{font}\" font-size=\"\{size}\" fill=\"\{color}\">\{escaped}</text>",
      indent,
      pretty,
    )
  }
}

///|
fn write_html_table(
  sb : StringBuilder,
  table : HtmlTable,
  rect : @geom.Rect,
  name : String,
  font : String,
  size : Double,
  text_color : String,
  stroke : String,
  stroke_dash : String,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  let layout = html_table_layout(table, rect, name, font, size)
  match table.bg_color {
    Some(color) => {
      let x = rect.llx - bbox.llx
      let y = rect.lly - bbox.lly
      let w = rect.urx - rect.llx
      let h = rect.ury - rect.lly
      write_line(
        sb,
        "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{color}\" stroke=\"none\"/>",
        indent,
        pretty,
      )
    }
    None => ()
  }
  if table.border_pt > 0.0 {
    let x = rect.llx - bbox.llx
    let y = rect.lly - bbox.lly
    let w = rect.urx - rect.llx
    let h = rect.ury - rect.lly
    write_line(
      sb,
      "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"none\" stroke=\"\{stroke}\"\{stroke_dash}/>",
      indent,
      pretty,
    )
  }
  let pad_x = table.cell_padding_pt * layout.scale_x + table.cell_border_pt * layout.scale_x
  let pad_y = table.cell_padding_pt * layout.scale_y + table.cell_border_pt * layout.scale_y
  for cell_layout in layout.cells {
    let cell_rect = cell_layout.rect
    match cell_layout.cell.bg_color {
      Some(color) => {
        let x = cell_rect.llx - bbox.llx
        let y = cell_rect.lly - bbox.lly
        let w = cell_rect.urx - cell_rect.llx
        let h = cell_rect.ury - cell_rect.lly
        write_line(
          sb,
          "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{color}\" stroke=\"none\"/>",
          indent,
          pretty,
        )
      }
      None => ()
    }
    if table.cell_border_pt > 0.0 {
      let x = cell_rect.llx - bbox.llx
      let y = cell_rect.lly - bbox.lly
      let w = cell_rect.urx - cell_rect.llx
      let h = cell_rect.ury - cell_rect.lly
      write_line(
        sb,
        "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"none\" stroke=\"\{stroke}\"\{stroke_dash}/>",
        indent,
        pretty,
      )
    }
    let content_rect : @geom.Rect = {
      llx: cell_rect.llx + pad_x,
      lly: cell_rect.lly + pad_y,
      urx: cell_rect.urx - pad_x,
      ury: cell_rect.ury - pad_y,
    }
    match cell_layout.cell.content {
      HtmlCellContent::Table(nested) => write_html_table(
        sb,
        nested,
        content_rect,
        name,
        font,
        size,
        text_color,
        stroke,
        stroke_dash,
        bbox,
        indent,
        pretty,
      )
      HtmlCellContent::Text(text) => {
        if text != "" {
          write_html_text_lines(
            sb,
            text,
            cell_layout.cell.align,
            cell_layout.cell.valign,
            content_rect,
            name,
            font,
            size,
            text_color,
            bbox,
            indent,
            pretty,
          )
        }
      }
    }
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
fn write_arrow_ops(
  sb : StringBuilder,
  ops : Array[@render.DrawOp],
  color : String,
  stroke_dash : String,
  llx : Double,
  lly : Double,
  indent : String,
  pretty : Bool,
) -> Unit {
  for op in ops {
    match op {
      @render.DrawOp::Polygon(filled~, points~) => {
        let attrs = polygon_points(points, llx, lly)
        let fill = if filled { color } else { "none" }
        write_line(
          sb,
          "<polygon points=\"\{attrs}\" fill=\"\{fill}\" stroke=\"\{color}\"\{stroke_dash}/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Ellipse(filled~, rect~) => {
        let center_x = (rect.llx + rect.urx) / 2.0 - llx
        let center_y = (rect.lly + rect.ury) / 2.0 - lly
        let radius_x = (rect.urx - rect.llx) / 2.0
        let radius_y = (rect.ury - rect.lly) / 2.0
        let fill = if filled { color } else { "none" }
        write_line(
          sb,
          "<ellipse cx=\"\{center_x}\" cy=\"\{center_y}\" rx=\"\{radius_x}\" ry=\"\{radius_y}\" fill=\"\{fill}\" stroke=\"\{color}\"\{stroke_dash}/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Polyline(points~) => {
        let attrs = polygon_points(points, llx, lly)
        write_line(
          sb,
          "<polyline points=\"\{attrs}\" fill=\"none\" stroke=\"\{color}\"\{stroke_dash}/>",
          indent,
          pretty,
        )
      }
      @render.DrawOp::Bezier(filled~, points~) => {
        let _ = filled
        let path = spline_path(@geom.Spline::{ start: None, end: None, points }, llx, lly)
        if path != "" {
          write_line(
            sb,
            "<path d=\"\{path}\" fill=\"none\" stroke=\"\{color}\"\{stroke_dash}/>",
            indent,
            pretty,
          )
        }
      }
      _ => ()
    }
  }
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
  sb.write_char('\n')
}

///|
fn write_label_lines(
  sb : StringBuilder,
  text : String,
  font : String,
  size : Double,
  color : String,
  pos : @geom.Point,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  if text == "" {
    return ()
  }
  let (lines, max_width, total_height) = label_metrics(text, font, size)
  let line_step = line_height(font, size)
  let start_y = pos.y + total_height / 2.0 - size + centerline_offset(size)
  for i in 0..<lines.length() {
    let line = lines[i]
    if line.text == "" {
      continue
    }
    let line_x = match line.align {
      @render.TextAlign::Left => pos.x - max_width / 2.0
      @render.TextAlign::Right => pos.x + max_width / 2.0
      @render.TextAlign::Center => pos.x
    }
    let line_y = start_y - line_step * i.to_double()
    let anchor = match line.align {
      @render.TextAlign::Left => "start"
      @render.TextAlign::Right => "end"
      @render.TextAlign::Center => "middle"
    }
    let x = line_x - bbox.llx
    let y = bbox.lly - line_y
    let escaped = escape_xml(line.text)
    write_line(
      sb,
      "<text x=\"\{x}\" y=\"\{y}\" transform=\"scale(1 -1)\" text-anchor=\"\{anchor}\" font-family=\"\{font}\" font-size=\"\{size}\" fill=\"\{color}\">\{escaped}</text>",
      indent,
      pretty,
    )
  }
}

///|
fn write_cluster_graphs(
  sb : StringBuilder,
  layout : @layout_dot.DotLayoutGraph,
  bbox : @geom.Rect,
  indent : String,
  pretty : Bool,
) -> Unit {
  for subgraph in layout.subgraphs {
    let graph = subgraph.graph
    if is_cluster_graph(graph) {
      let rect = subgraph.bbox
      let x = rect.llx - bbox.llx
      let y = rect.lly - bbox.lly
      let w = rect.urx - rect.llx
      let h = rect.ury - rect.lly
      let stroke = @attrs.color(graph.get_attr("color"), default="black")
      let fill = match cluster_fill_color(graph) {
        Some(value) => value
        None => "none"
      }
      let style = @attrs.parse_style(graph.get_attr("style"))
      let dash = stroke_dash_attr(style)
      write_line(
        sb,
        "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash}/>",
        indent,
        pretty,
      )
      match graph_label_metrics(graph) {
        Some((text, _width_pt, height_pt)) => {
          let font = @attrs.font_name(graph.get_attr("fontname"))
          let size = @attrs.font_size(graph.get_attr("fontsize"))
          let color = @attrs.color(graph.get_attr("fontcolor"), default="black")
          let pos = match subgraph.label_pos {
            Some(value) => value
            None => graph_label_pos(rect, height_pt)
          }
          write_label_lines(
            sb,
            text,
            font,
            size,
            color,
            pos,
            bbox,
            indent,
            pretty,
          )
        }
        None => ()
      }
    }
    write_cluster_graphs(sb, subgraph, bbox, indent, pretty)
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
  if layout.graph.is_root() {
    let fill = match layout.graph.get_attr("bgcolor") {
      Some(value) => value
      None => "white"
    }
    let rect_indent = if pretty { "  " } else { "" }
    write_line(
      sb,
      "<rect x=\"0\" y=\"0\" width=\"\{width}\" height=\"\{height}\" fill=\"\{fill}\"/>",
      rect_indent,
      pretty,
    )
  }
  write_line(
    sb,
    "<g transform=\"translate(0 \{height}) scale(1 -1)\">",
    "  ",
    pretty,
  )
  let cluster_indent = if pretty { "    " } else { "" }
  write_cluster_graphs(sb, layout, bbox, cluster_indent, pretty)
  let edge_indent = if pretty { "    " } else { "" }
  let kind = layout.graph.kind()
  for edge_layout in layout.edges {
    let edge = edge_layout.edge
    let color = @attrs.color(edge.get_attr("color"), default="black")
    let style = @attrs.parse_style(edge.get_attr("style"))
    let dash = stroke_dash_attr(style)
    for spline in edge_layout.splines {
      let path = spline_path(spline, bbox.llx, bbox.lly)
      if path != "" {
        write_line(
          sb,
          "<path d=\"\{path}\" fill=\"none\" stroke=\"\{color}\"\{dash}/>",
          edge_indent,
          pretty,
        )
      }
    }
    let flags = arrow_flags(edge, kind)
    if flags.head {
      let ops = arrow_primitives(edge_layout, true)
      write_arrow_ops(sb, ops, color, dash, bbox.llx, bbox.lly, edge_indent, pretty)
    }
    if flags.tail {
      let ops = arrow_primitives(edge_layout, false)
      write_arrow_ops(sb, ops, color, dash, bbox.llx, bbox.lly, edge_indent, pretty)
    }
    let label_text = match edge.get_attr("label") {
      Some(value) => resolve_label(value, "")
      None => ""
    }
    match edge_layout.label_pos {
      Some(pos) => {
        let font = @attrs.font_name(edge.get_attr("fontname"))
        let size = @attrs.font_size(edge.get_attr("fontsize"))
        let font_color = @attrs.color(edge.get_attr("fontcolor"), default="black")
        write_label_lines(
          sb,
          label_text,
          font,
          size,
          font_color,
          pos,
          bbox,
          edge_indent,
          pretty,
        )
      }
      None => ()
    }
    let head_label_text = match edge.get_attr("headlabel") {
      Some(value) => resolve_label(value, "")
      None => ""
    }
    match edge_layout.head_label_pos {
      Some(pos) => {
        let font = @attrs.font_name(edge.get_attr("fontname"))
        let size = @attrs.font_size(edge.get_attr("fontsize"))
        let font_color = @attrs.color(edge.get_attr("fontcolor"), default="black")
        write_label_lines(
          sb,
          head_label_text,
          font,
          size,
          font_color,
          pos,
          bbox,
          edge_indent,
          pretty,
        )
      }
      None => ()
    }
    let tail_label_text = match edge.get_attr("taillabel") {
      Some(value) => resolve_label(value, "")
      None => ""
    }
    match edge_layout.tail_label_pos {
      Some(pos) => {
        let font = @attrs.font_name(edge.get_attr("fontname"))
        let size = @attrs.font_size(edge.get_attr("fontsize"))
        let font_color = @attrs.color(edge.get_attr("fontcolor"), default="black")
        write_label_lines(
          sb,
          tail_label_text,
          font,
          size,
          font_color,
          pos,
          bbox,
          edge_indent,
          pretty,
        )
      }
      None => ()
    }
  }
  let node_indent = if pretty { "    " } else { "" }
  for node_layout in layout.nodes {
    let node = node_layout.node
    let rect = node_rect(node_layout)
    let kind = shape_kind(node.get_attr("shape"))
    let stroke = @attrs.color(node.get_attr("color"), default="black")
    let style = @attrs.parse_style(node.get_attr("style"))
    let filled = if kind == "point" {
      true
    } else {
      style.filled
    }
    let dash = stroke_dash_attr(style)
    let fill = if filled {
      match node.get_attr("fillcolor") {
        Some(value) => value
        None => {
          if kind == "point" {
            stroke
          } else {
            "white"
          }
        }
      }
    } else {
      "none"
    }
    if kind == "record" {
      write_record_node(
        sb,
        node_layout,
        rect,
        stroke,
        fill,
        dash,
        bbox,
        node_indent,
        pretty,
      )
      continue
    }
    if kind == "plaintext" {
      // No outline for plaintext/none nodes.
    } else {
      match shape_polygon_points(kind, rect) {
        Some(points) => {
          let attrs = polygon_points(points, bbox.llx, bbox.lly)
          write_line(
            sb,
            "<polygon points=\"\{attrs}\" fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash}/>",
            node_indent,
            pretty,
          )
        }
        None => {
          if kind == "box" {
            let x = rect.llx - bbox.llx
            let y = rect.lly - bbox.lly
            let w = rect.urx - rect.llx
            let h = rect.ury - rect.lly
            write_line(
              sb,
              "<rect x=\"\{x}\" y=\"\{y}\" width=\"\{w}\" height=\"\{h}\" fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash}/>",
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
              "<ellipse cx=\"\{cx}\" cy=\"\{cy}\" rx=\"\{rx}\" ry=\"\{ry}\" fill=\"\{fill}\" stroke=\"\{stroke}\"\{dash}/>",
              node_indent,
              pretty,
            )
          }
        }
      }
    }
    let text = label_text(node.get_attr("label"), node.name())
    let font = @attrs.font_name(node.get_attr("fontname"))
    let size = @attrs.font_size(node.get_attr("fontsize"))
    let color = @attrs.color(node.get_attr("fontcolor"), default="black")
    match parse_html_label(text) {
      Some(HtmlLabel::Table(table)) => write_html_table(
        sb,
        table,
        rect,
        node.name(),
        font,
        size,
        color,
        stroke,
        dash,
        bbox,
        node_indent,
        pretty,
      )
      Some(HtmlLabel::Text(html_text)) => {
        if html_text != "" {
          write_html_text_lines(
            sb,
            html_text,
            HtmlAlign::Center,
            HtmlVAlign::Middle,
            rect,
            node.name(),
            font,
            size,
            color,
            bbox,
            node_indent,
            pretty,
          )
        }
      }
      None => {
        if text != "" {
          let pos = match node_layout.label_pos {
            Some(value) => value
            None => node_layout.pos
          }
          write_label_lines(
            sb,
            text,
            font,
            size,
            color,
            pos,
            bbox,
            node_indent,
            pretty,
          )
        }
      }
    }
  }
  match graph_label_metrics(layout.graph) {
    Some((text, _width_pt, _height_pt)) => {
      match layout.label_pos {
        Some(pos) => {
          let graph = layout.graph
          let font = @attrs.font_name(graph.get_attr("fontname"))
          let size = @attrs.font_size(graph.get_attr("fontsize"))
          let color = @attrs.color(graph.get_attr("fontcolor"), default="black")
          write_label_lines(
            sb,
            text,
            font,
            size,
            color,
            pos,
            bbox,
            node_indent,
            pretty,
          )
        }
        None => ()
      }
    }
    None => ()
  }
  write_line(sb, "</g>", "  ", pretty)
  write_line(sb, "</svg>", "", pretty)
  sb.to_string()
}
