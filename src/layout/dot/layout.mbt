///|
priv struct NodeSize {
  width_in : Double
  height_in : Double
  width_pt : Double
  height_pt : Double
  left_pt : Double
  right_pt : Double
}

///|
priv struct EdgeVnodeInfo {
  vnode_ranks : Map[String, Int]
  vnode_sizes : Map[String, NodeSize]
  vnodes_by_rank : Map[Int, Array[String]]
  edge_vnodes : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
}

///|
fn default_nodesep_in() -> Double {
  0.25
}

///|
fn default_ranksep_in() -> Double {
  0.5
}

///|
fn default_node_width_in() -> Double {
  0.75
}

///|
fn default_node_height_in() -> Double {
  0.5
}

///|
fn default_point_size_in() -> Double {
  0.05
}

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
fn parse_first_double(value : String, fallback : Double) -> Double {
  let sb = StringBuilder::new()
  let mut seen = false
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
      seen = true
    } else if seen {
      break
    }
  }
  if !seen {
    fallback
  } else {
    parse_double(sb.to_string(), fallback)
  }
}

///|
fn parse_rankdir(value : String) -> RankDir? {
  match value.to_lower() {
    "tb" => Some(RankDir::TB)
    "bt" => Some(RankDir::BT)
    "lr" => Some(RankDir::LR)
    "rl" => Some(RankDir::RL)
    _ => None
  }
}

///|
fn graph_rankdir(graph : @cgraph.Graph) -> RankDir {
  let mut current = graph
  while true {
    match current.get_attr("rankdir") {
      Some(value) =>
        match parse_rankdir(value) {
          Some(parsed) => return parsed
          None => ()
        }
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  RankDir::TB
}

///|
fn parse_splines(value : String) -> SplinesMode? {
  match value.to_lower() {
    "true" | "spline" | "splines" => Some(SplinesMode::Spline)
    "false" | "none" | "" => Some(SplinesMode::None)
    "polyline" => Some(SplinesMode::Polyline)
    "ortho" => Some(SplinesMode::Ortho)
    "curved" => Some(SplinesMode::Curved)
    _ => None
  }
}

///|
priv enum EdgeDir {
  Forward
  Back
  Both
  None
}

///|
fn parse_edge_dir(value : String) -> EdgeDir? {
  match value.to_lower() {
    "forward" | "f" => Some(EdgeDir::Forward)
    "back" | "b" => Some(EdgeDir::Back)
    "both" => Some(EdgeDir::Both)
    "none" => Some(EdgeDir::None)
    _ => None
  }
}

///|
fn edge_dir_for(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> EdgeDir {
  if kind == @cgraph.GraphKind::Undirected {
    return EdgeDir::None
  }
  match edge.get_attr("dir") {
    Some(value) =>
      match parse_edge_dir(value) {
        Some(dir) => dir
        None => EdgeDir::Forward
      }
    None => EdgeDir::Forward
  }
}

///|
const LINE_SPACING : Double = 1.2

///|
const TEXT_SCALE : Double = 0.9706

///|
const PAD_X_PT : Double = 16.0

///|
const PAD_Y_PT : Double = 8.0

///|
const RECORD_BORDER_PT : Double = 0.5

const PERIPHERY_GAP_PT : Double = 4.0

///|
// Graphviz keeps edge-label ranks tight; use a fraction of nodesep on label ranks.
const EDGE_LABEL_NODESEP_SCALE : Double = 0.0

///|
const EDGE_LABEL_PAD_WIDTH_PT : Double = 100.0

///|
const DEFAULT_GRAPH_MARGIN_IN : Double = 0.11

///|
const ELLIPSE_LABEL_SCALE : Double = 1.0


///|
const EDGE_VNODE_PREFIX : String = "_mbt_edge_vn_"

///|
fn font_width_scale(font_name : String) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.02
  } else {
    1.0
  }
}

///|
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
fn char_width_units_base(ch : Char) -> Int {
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
fn char_width_units(ch : Char, uppercase_boost : Bool) -> Int {
  let base = char_width_units_base(ch)
  if uppercase_boost && ch.is_ascii_uppercase() {
    base + 22
  } else if ch.is_ascii_lowercase() {
    base - 2
  } else {
    base
  }
}

///|
fn record_char_width_units(ch : Char) -> Int {
  let base = char_width_units_base(ch)
  if ch.is_ascii_lowercase() {
    base - 2
  } else {
    base
  }
}

///|
fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  if label == "" {
    return (0.0, 0.0)
  }
  let mut has_lowercase = false
  let mut scan_escape = false
  for ch in label {
    if scan_escape {
      scan_escape = false
      if ch != 'n' && ch != 'l' && ch != 'r' && ch.is_ascii_lowercase() {
        has_lowercase = true
        break
      }
      continue
    }
    if ch == '\\' {
      scan_escape = true
      continue
    }
    if ch.is_ascii_lowercase() {
      has_lowercase = true
      break
    }
  }
  let uppercase_boost = !has_lowercase
  let line_height = font_size_pt * line_height_scale(font_name, font_size_pt)
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
        current_units = current_units + char_width_units(ch, uppercase_boost)
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
      current_units = current_units + char_width_units(ch, uppercase_boost)
    }
  }
  if escaping {
    current_units = current_units + char_width_units('\\', uppercase_boost)
  }
  if current_units > max_units {
    max_units = current_units
  }
  let width_scale = font_width_scale(font_name)
  let width_pt = max_units.to_double() *
    font_size_pt *
    TEXT_SCALE *
    width_scale /
    1000.0
  let height_pt = lines.to_double() * line_height
  (width_pt, height_pt)
}

///|
fn record_label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  if label == "" {
    return (0.0, 0.0)
  }
  let line_height = font_size_pt * line_height_scale(font_name, font_size_pt)
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
        current_units = current_units + record_char_width_units(ch)
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
      current_units = current_units + record_char_width_units(ch)
    }
  }
  if escaping {
    current_units = current_units + record_char_width_units('\\')
  }
  if current_units > max_units {
    max_units = current_units
  }
  let width_scale = font_width_scale(font_name)
  let width_pt = max_units.to_double() *
    font_size_pt *
    TEXT_SCALE *
    width_scale /
    1000.0
  let height_pt = lines.to_double() * line_height
  (width_pt, height_pt)
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
fn graph_margin_x_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some((margin_x, _margin_y)) => margin_x * 72.0
        None => DEFAULT_GRAPH_MARGIN_IN * 72.0
      }
    None => DEFAULT_GRAPH_MARGIN_IN * 72.0
  }
}

///|
fn label_text(node : @cgraph.Node) -> String {
  match node.get_attr("label") {
    Some(value) => if value == "\\N" { node.name() } else { value }
    None => node.name()
  }
}

///|
fn is_record_shape(node : @cgraph.Node) -> Bool {
  match node.get_attr("shape") {
    Some(value) =>
      match value.to_lower() {
        "record" | "mrecord" => true
        _ => false
      }
    None => false
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
priv struct RecordField {
  name : String?
  text : String
}

///|
priv struct RecordPort {
  center : @geom.Point
  size : NodeSize
}

///|
priv enum RecordOrientation {
  Horizontal
  Vertical
}

///|
fn record_layout_orientation(_rankdir : RankDir) -> RecordOrientation {
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
  let (port_name, raw_text) : (String?, String) = if trimmed.has_prefix("<") {
    match trimmed.find(">") {
      Some(pos) => {
        let name = if pos > 1 {
          trimmed.unsafe_substring(start=1, end=pos)
        } else {
          ""
        }
        let len = trimmed.length()
        let text = if pos + 1 < len {
          trimmed.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
        let port_name : String? = if name == "" { None } else { Some(name) }
        (port_name, text)
      }
      None => (None, trimmed)
    }
  } else {
    (None, trimmed)
  }
  let normalized = raw_text.trim(chars=" \n\r\t").to_string()
  let text = if normalized == "" { " " } else { normalized }
  { name: port_name, text }
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
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[RecordNodeSize] {
  let sizes : Array[RecordNodeSize] = []
  for node in nodes {
    match node {
      RecordNode::Field(field) => {
        let (text_width_pt, text_height_pt) = record_label_text_dimensions(
          field.text,
          font_name,
          font_size_pt,
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
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> RecordNodeSize {
  let sizes = record_nodes_sizes(
    nodes, orientation, font_name, font_size_pt, pad_x_pt, pad_y_pt,
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
fn node_size_from_points(width_pt : Double, height_pt : Double) -> NodeSize {
  let width_in = width_pt / 72.0
  let height_in = height_pt / 72.0
  let half = width_pt / 2.0
  { width_in, height_in, width_pt, height_pt, left_pt: half, right_pt: half }
}

///|
fn vnode_size_from_widths(left_pt : Double, right_pt : Double) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  {
    width_in,
    height_in: 0.0,
    width_pt,
    height_pt: 0.0,
    left_pt,
    right_pt,
  }
}

///|
fn record_layout_nodes(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
  rects : Array[@geom.Rect],
  ports : Map[String, RecordPort],
) -> Unit {
  if nodes.length() == 0 {
    return ()
  }
  let sizes = record_nodes_sizes(
    nodes, orientation, font_name, font_size_pt, pad_x_pt, pad_y_pt,
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
      RecordNode::Field(field) => {
        rects.push(child_rect)
        match field.name {
          Some(name) => {
            let center = @geom.Point::{
              x: (child_rect.llx + child_rect.urx) / 2.0,
              y: (child_rect.lly + child_rect.ury) / 2.0,
            }
            let field_size = node_size_from_points(
              child_rect.urx - child_rect.llx,
              child_rect.ury - child_rect.lly,
            )
            ports[name] = { center, size: field_size }
          }
          None => ()
        }
      }
      RecordNode::Group(children) =>
        record_layout_nodes(
          children,
          child_rect,
          toggle_record_orientation(orientation),
          font_name,
          font_size_pt,
          pad_x_pt,
          pad_y_pt,
          rects,
          ports,
        )
    }
  }
}

///|
fn record_rects(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
  orientation : RecordOrientation,
) -> Array[@geom.Rect] {
  let label = label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let rects : Array[@geom.Rect] = []
  let ports : Map[String, RecordPort] = Map::new()
  let rect : @geom.Rect = {
    llx: pos.x - size.width_pt / 2.0,
    lly: pos.y - size.height_pt / 2.0,
    urx: pos.x + size.width_pt / 2.0,
    ury: pos.y + size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
    rects,
    ports,
  )
  rects
}

///|
fn record_ports(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
  orientation : RecordOrientation,
) -> Map[String, RecordPort] {
  let label = label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let ports : Map[String, RecordPort] = Map::new()
  let rects : Array[@geom.Rect] = []
  let rect : @geom.Rect = {
    llx: pos.x - size.width_pt / 2.0,
    lly: pos.y - size.height_pt / 2.0,
    urx: pos.x + size.width_pt / 2.0,
    ury: pos.y + size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    pad_x_pt,
    pad_y_pt,
    rects,
    ports,
  )
  ports
}

///|
fn record_port_padding_y(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> (Double, Double) {
  let mut extra_below = 0.0
  let mut extra_above = 0.0
  let update_padding = (node_name : String, port : @cgraph.Port?) => {
    match port {
      Some(value) =>
        match value.name {
          Some(port_name) =>
            match label_ports_map.get(node_name) {
              Some(ports) =>
                match ports.get(port_name) {
                  Some(port_info) =>
                    match positions.get(node_name) {
                      Some(node_pos) => {
                        let dy = port_info.center.y - node_pos.y
                        let half_height =
                          port_info.size.height_pt / 2.0 -
                          RECORD_BORDER_PT / 2.0 -
                          0.01
                        let adjusted =
                          if half_height < 0.0 { 0.0 } else { half_height }
                        if dy < 0.0 && adjusted > extra_below {
                          extra_below = adjusted
                        } else if dy > 0.0 && adjusted > extra_above {
                          extra_above = adjusted
                        }
                      }
                      None => ()
                    }
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  for edge in edges {
    if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
      update_padding(edge.tail().name(), edge.tail_port())
    }
    if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
      update_padding(edge.head().name(), edge.head_port())
    }
  }
  (extra_below, extra_above)
}

///|
///|
fn html_cell_content_size(
  content : @html_label.HtmlCellContent,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match content {
    @html_label.HtmlCellContent::Text(text) =>
      label_text_dimensions(text, font_name, font_size_pt)
    @html_label.HtmlCellContent::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn html_cell_size(
  table : @html_label.HtmlTable,
  cell : @html_label.HtmlCell,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let (content_width, content_height) = html_cell_content_size(
    cell.content,
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
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  @html_label.html_table_size(table, cell => html_cell_size(
    table, cell, font_name, font_size_pt,
  ))
}

///|
fn html_table_layout(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
) -> @html_label.HtmlTableLayout {
  @html_label.html_table_layout(table, rect, cell => html_cell_size(
    table, cell, font_name, font_size_pt,
  ))
}

///|
fn html_label_size(
  label : @html_label.HtmlLabel,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match label {
    @html_label.HtmlLabel::Text(text) =>
      label_text_dimensions(text, font_name, font_size_pt)
    @html_label.HtmlLabel::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn collect_html_ports(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
  ports : Map[String, RecordPort],
) -> Unit {
  let layout = html_table_layout(table, rect, font_name, font_size_pt)
  for cell_layout in layout.cells {
    match cell_layout.cell.port {
      Some(name) => {
        let center = @geom.Point::{
          x: (cell_layout.rect.llx + cell_layout.rect.urx) / 2.0,
          y: (cell_layout.rect.lly + cell_layout.rect.ury) / 2.0,
        }
        let size = node_size_from_points(
          cell_layout.rect.urx - cell_layout.rect.llx,
          cell_layout.rect.ury - cell_layout.rect.lly,
        )
        ports[name] = { center, size }
      }
      None => ()
    }
    match cell_layout.cell.content {
      @html_label.HtmlCellContent::Table(nested) =>
        collect_html_ports(
          nested,
          cell_layout.rect,
          font_name,
          font_size_pt,
          ports,
        )
      _ => ()
    }
  }
}

///|
fn html_ports(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
) -> Map[String, RecordPort] {
  let label = label_text(node)
  let ports : Map[String, RecordPort] = Map::new()
  match @html_label.parse_html_label(label) {
    Some(@html_label.HtmlLabel::Table(table)) => {
      let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
      let font = @attrs.font_name(node.get_attr("fontname"))
      let rect : @geom.Rect = {
        llx: pos.x - size.width_pt / 2.0,
        lly: pos.y - size.height_pt / 2.0,
        urx: pos.x + size.width_pt / 2.0,
        ury: pos.y + size.height_pt / 2.0,
      }
      collect_html_ports(table, rect, font, font_size_pt, ports)
    }
    _ => ()
  }
  ports
}

///|
fn port_geometry(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_map : Map[String, Map[String, RecordPort]],
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> (@geom.Point, NodeSize) {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match label_ports_map.get(node_name) {
            Some(ports) =>
              match ports.get(name) {
                Some(port_info) => (port_info.center, port_info.size)
                None => (node_pos, node_size)
              }
            None => (node_pos, node_size)
          }
        None => (node_pos, node_size)
      }
    None => (node_pos, node_size)
  }
}

///|
fn record_port_boundary_anchor(
  center : @geom.Point,
  size : NodeSize,
  node_pos : @geom.Point,
  node_size : NodeSize,
  target : @geom.Point,
) -> (@geom.Point, NodeSize) {
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  let port_rect : @geom.Rect = {
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  }
  let node_half_w = node_size.width_pt / 2.0
  let node_half_h = node_size.height_pt / 2.0
  let node_rect : @geom.Rect = {
    llx: node_pos.x - node_half_w,
    lly: node_pos.y - node_half_h,
    urx: node_pos.x + node_half_w,
    ury: node_pos.y + node_half_h,
  }
  let eps = 0.01
  let left_outer = Double::abs(port_rect.llx - node_rect.llx) <= eps
  let right_outer = Double::abs(port_rect.urx - node_rect.urx) <= eps
  let bottom_outer = Double::abs(port_rect.lly - node_rect.lly) <= eps
  let top_outer = Double::abs(port_rect.ury - node_rect.ury) <= eps
  let dx = target.x - center.x
  let dy = target.y - center.y
  let prefer_horizontal = Double::abs(dx) >= Double::abs(dy)
  let mut anchor = center
  if prefer_horizontal {
    if dx < 0.0 && left_outer {
      anchor = { x: port_rect.llx, y: center.y }
    } else if dx > 0.0 && right_outer {
      anchor = { x: port_rect.urx, y: center.y }
    }
  }
  if anchor == center {
    if dy > 0.0 && top_outer {
      anchor = { x: center.x, y: port_rect.ury }
    } else if dy < 0.0 && bottom_outer {
      anchor = { x: center.x, y: port_rect.lly }
    } else if left_outer {
      anchor = { x: port_rect.llx, y: center.y }
    } else if right_outer {
      anchor = { x: port_rect.urx, y: center.y }
    } else if top_outer {
      anchor = { x: center.x, y: port_rect.ury }
    } else if bottom_outer {
      anchor = { x: center.x, y: port_rect.lly }
    }
  }
  let size_out = if anchor == center {
    size
  } else {
    node_size_from_points(0.0, 0.0)
  }
  (anchor, size_out)
}

///|
fn node_size(
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let regular_shape =
    shape == "msquare" ||
    shape == "mcircle" ||
    shape == "circle" ||
    shape == "doublecircle"
  let scale_ellipse = match shape {
    "box"
    | "rect"
    | "rectangle"
    | "record"
    | "mrecord"
    | "msquare"
    | "mdiamond"
    | "point"
    | "dot"
    | "plaintext"
    | "plain"
    | "none" => false
    _ => true
  }
  let (fallback_width, fallback_height) = if shape == "point" || shape == "dot" {
    (default_point_size_in(), default_point_size_in())
  } else if regular_shape {
    let height = default_node_height_in()
    (height, height)
  } else {
    (default_node_width_in(), default_node_height_in())
  }
  let base_width_in = match node.get_attr("width") {
    Some(value) => parse_double(value, fallback_width)
    None => fallback_width
  }
  let base_height_in = match node.get_attr("height") {
    Some(value) => parse_double(value, fallback_height)
    None => fallback_height
  }
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let (pad_x_pt, pad_y_pt) = node_padding(node)
  let base_width_pt = base_width_in * 72.0
  let base_height_pt = base_height_in * 72.0
  if shape == "point" || shape == "dot" {
    return node_size_from_points(base_width_pt, base_height_pt)
  }
  if is_record_shape(node) {
    let label = label_text(node)
    let nodes = record_nodes(label)
    let record_size = record_group_size(
      nodes,
      record_orientation,
      font,
      font_size_pt,
      pad_x_pt,
      pad_y_pt,
    )
    let width_pt = if record_size.width_pt > base_width_pt {
      record_size.width_pt
    } else {
      base_width_pt
    }
    let height_pt = if record_size.height_pt > base_height_pt {
      record_size.height_pt
    } else {
      base_height_pt
    }
    let bordered_height = height_pt + RECORD_BORDER_PT * 2.0
    return node_size_from_points(width_pt, bordered_height)
  }
  let label = label_text(node)
  if @html_label.is_html_label_text(label) {
    match @html_label.parse_html_label(label) {
      Some(html_label) => {
        let (html_width_pt, html_height_pt) = html_label_size(
          html_label, font, font_size_pt,
        )
        let width_pt = if html_width_pt > base_width_pt {
          html_width_pt
        } else {
          base_width_pt
        }
        let height_pt = if html_height_pt > base_height_pt {
          html_height_pt
        } else {
          base_height_pt
        }
        return node_size_from_points(width_pt, height_pt)
      }
      None => ()
    }
  }
  let (text_width_pt, text_height_pt) = label_text_dimensions(
    label, font, font_size_pt,
  )
  let has_label = text_width_pt > 0.0 || text_height_pt > 0.0
  let label_width_pt = if has_label { text_width_pt + pad_x_pt } else { 0.0 }
  let label_height_pt = if has_label { text_height_pt + pad_y_pt } else { 0.0 }
  let mut scaled_label_width_pt = label_width_pt
  let mut scaled_label_height_pt = label_height_pt
  if shape == "mdiamond" && has_label {
    let sqrt2 = Double::sqrt(2.0)
    let temp = label_height_pt * sqrt2
    if base_height_pt > temp {
      let ratio = label_height_pt / base_height_pt
      let denom = 1.0 - ratio * ratio
      if denom > 0.0 {
        let scale = Double::sqrt(1.0 / denom)
        scaled_label_width_pt = label_width_pt * scale
      } else {
        scaled_label_width_pt = label_width_pt * sqrt2
        scaled_label_height_pt = temp
      }
    } else {
      scaled_label_width_pt = label_width_pt * sqrt2
      scaled_label_height_pt = temp
    }
    let cos_val = sqrt2 / 2.0
    scaled_label_width_pt = scaled_label_width_pt / cos_val
    scaled_label_height_pt = scaled_label_height_pt / cos_val
  } else if scale_ellipse && has_label {
    let sqrt2 = Double::sqrt(2.0)
    let temp = label_height_pt * sqrt2
    if base_height_pt > temp {
      let ratio = label_height_pt / base_height_pt
      let denom = 1.0 - ratio * ratio
      if denom > 0.0 {
        let scale = Double::sqrt(1.0 / denom)
        scaled_label_width_pt = label_width_pt * scale
      } else {
        scaled_label_width_pt = label_width_pt * sqrt2
        scaled_label_height_pt = temp
      }
    } else {
      scaled_label_width_pt = label_width_pt * sqrt2
      scaled_label_height_pt = temp
    }
    scaled_label_width_pt = scaled_label_width_pt * ELLIPSE_LABEL_SCALE
  }
  let scaled_label_width_in = scaled_label_width_pt / 72.0
  let scaled_label_height_in = scaled_label_height_pt / 72.0
  let mut width_in = if scaled_label_width_in > base_width_in {
    scaled_label_width_in
  } else {
    base_width_in
  }
  let mut height_in = if scaled_label_height_in > base_height_in {
    scaled_label_height_in
  } else {
    base_height_in
  }
  if regular_shape {
    let size_in = if width_in > height_in { width_in } else { height_in }
    width_in = size_in
    height_in = size_in
  }
  if shape == "doublecircle" {
    let gap_in = PERIPHERY_GAP_PT * 2.0 / 72.0
    width_in = width_in + gap_in
    height_in = height_in + gap_in
  }
  let width_pt = width_in * 72.0
  let half = width_pt / 2.0
  {
    width_in,
    height_in,
    width_pt,
    height_pt: height_in * 72.0,
    left_pt: half,
    right_pt: half,
  }
}

///|
fn clip_to_rect(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  let tx = if dx == 0.0 { 1000000000.0 } else { half_w / Double::abs(dx) }
  let ty = if dy == 0.0 { 1000000000.0 } else { half_h / Double::abs(dy) }
  let t = if tx < ty { tx } else { ty }
  { x: center.x + dx * t, y: center.y + dy * t }
}

///|
fn clip_polyline_ends(
  points : Array[@geom.Point],
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> Array[@geom.Point] {
  if points.length() < 2 {
    return points
  }
  let out = points.copy()
  let tail_target = out[1]
  let head_target = out[out.length() - 2]
  out[0] = clip_to_rect(tail_anchor, tail_size, tail_target)
  out[out.length() - 1] = clip_to_rect(head_anchor, head_size, head_target)
  out
}

///|
fn point_line_distance(
  point : @geom.Point,
  a : @geom.Point,
  b : @geom.Point,
) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  if dx == 0.0 && dy == 0.0 {
    return @math.hypot(point.x - a.x, point.y - a.y)
  }
  let t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)
  let proj = @geom.Point::{ x: a.x + t * dx, y: a.y + t * dy }
  @math.hypot(point.x - proj.x, point.y - proj.y)
}

///|
fn slice_points(
  points : Array[@geom.Point],
  start : Int,
  end : Int,
) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  for i in start..<end {
    out.push(points[i])
  }
  out
}

///|
fn simplify_polyline(
  points : Array[@geom.Point],
  tol : Double,
) -> Array[@geom.Point] {
  if tol <= 0.0 || points.length() <= 2 {
    return points
  }
  let last = points.length() - 1
  let mut max_dist = -1.0
  let mut max_idx = 0
  for i in 1..<last {
    let dist = point_line_distance(points[i], points[0], points[last])
    if dist > max_dist {
      max_dist = dist
      max_idx = i
    }
  }
  if max_dist <= tol {
    return [points[0], points[last]]
  }
  let left = simplify_polyline(slice_points(points, 0, max_idx + 1), tol)
  let right = simplify_polyline(slice_points(points, max_idx, points.length()), tol)
  let out = left.copy()
  for i in 1..<right.length() {
    out.push(right[i])
  }
  out
}

///|
///|
fn edge_polyline_points(
  edge : @cgraph.Edge,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  label_width_pt : Double,
  dotted_weight : Double,
  use_cluster_tuning : Bool,
  split_label : Bool,
) -> Array[@geom.Point] {
  let points : Array[@geom.Point] = [tail_anchor]
  let vnodes = match edge_vnodes.get(edge_key(edge)) {
    Some(list) => list
    None => []
  }
  if vnodes.length() > 0 {
    let tail_rank = match ranks.get(edge.tail().name()) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(edge.head().name()) {
      Some(value) => value
      None => 0
    }
    let span = head_rank - tail_rank
    if span != 0 {
      let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
      let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
      let label_rank = if label_width_pt > 0.0 {
        (min_rank + max_rank) / 2
      } else {
        -1
      }
      let y_dir = if head_anchor.y < tail_anchor.y { 1.0 } else { -1.0 }
      let style_value = match edge.get_attr("style") {
        Some(value) => value.to_lower()
        None => ""
      }
      let is_dotted = style_value.contains("dotted")
      let has_explicit_port =
        port_is_explicit(edge.tail_port()) || port_is_explicit(edge.head_port())
      let same_local_cluster =
        node_local_cluster_key(edge.tail()) == node_local_cluster_key(edge.head())
      let vnode_weight =
        if use_cluster_tuning {
          if is_dotted {
            dotted_weight
          } else if split_label {
            0.3
          } else if label_width_pt > 0.0 && !has_explicit_port {
            if same_local_cluster {
              1.0
            } else {
              0.4
            }
          } else {
            0.0
          }
        } else {
          1.0
        }
      let span_f = Double::from_int(span)
      let push_point = (name : String) => {
        match vnode_positions.get(name) {
          Some(pos) =>
            match vnode_ranks.get(name) {
              Some(rank) => {
                let t_raw = Double::from_int(rank - tail_rank) / span_f
                let t =
                  if use_cluster_tuning && !is_dotted && head_anchor.x >= tail_anchor.x {
                    if split_label && rank == label_rank {
                      t_raw
                    } else {
                      t_raw * t_raw
                    }
                  } else {
                    t_raw
                  }
                let interp_x = tail_anchor.x + (head_anchor.x - tail_anchor.x) * t
                let x = pos.x * vnode_weight + interp_x * (1.0 - vnode_weight)
                if split_label && rank == label_rank {
                  let split_width = label_width_pt * 1.5
                  let split_x = x - nodesep_pt * 1.25
                  points.push({
                    x: split_x - nodesep_pt,
                    y: pos.y + nodesep_pt * y_dir,
                  })
                  points.push({
                    x: split_x + split_width * 0.5,
                    y: pos.y - nodesep_pt * y_dir,
                  })
                } else {
                  points.push({ x, y: pos.y })
                }
              }
              None => ()
            }
          None => ()
        }
      }
      if tail_rank <= head_rank {
        for name in vnodes {
          push_point(name)
        }
      } else {
        let mut idx = vnodes.length()
        while idx > 0 {
          idx = idx - 1
          let name = vnodes[idx]
          push_point(name)
        }
      }
    }
  }
  if points.length() == 1 && tail_anchor != head_anchor {
    let dx = head_anchor.x - tail_anchor.x
    let dy = head_anchor.y - tail_anchor.y
    let horizontal_first = Double::abs(dx) >= Double::abs(dy)
    if horizontal_first {
      let mid_x = (tail_anchor.x + head_anchor.x) / 2.0
      points.push({ x: mid_x, y: tail_anchor.y })
      points.push({ x: mid_x, y: head_anchor.y })
    } else {
      let mid_y = (tail_anchor.y + head_anchor.y) / 2.0
      points.push({ x: tail_anchor.x, y: mid_y })
      points.push({ x: head_anchor.x, y: mid_y })
    }
  }
  points.push(head_anchor)
  points
}

///|
fn adjust_intercluster_dotted_points(
  points : Array[@geom.Point],
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  head_size : NodeSize,
  nodesep_pt : Double,
) -> Array[@geom.Point] {
  if points.length() <= 2 {
    return points
  }
  let last_idx = points.length() - 2
  let head_left = head_anchor.x - head_size.width_pt / 2.0
  let head_right = head_anchor.x + head_size.width_pt / 2.0
  let offset = nodesep_pt * 0.5
  let x = if head_anchor.x >= tail_anchor.x {
    head_left - offset
  } else {
    head_right + offset
  }
  let y = tail_anchor.y + (head_anchor.y - tail_anchor.y) * 0.4
  let adjusted = points.copy()
  adjusted[last_idx] = { x, y }
  adjusted
}

///|
fn adjust_intracluster_dotted_points(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  if points.length() <= 3 {
    return points
  }
  let adjusted = points.copy()
  let last = points.length() - 1
  let mid = points.length() / 2
  let mid_y = (points[0].y + points[last].y) / 2.0
  let left_weight = 0.2
  let right_weight = 0.8
  if points.length() % 2 == 0 {
    let left = mid - 1
    if left > 0 && left < last {
      let avg_y = (points[left - 1].y + points[left + 1].y) / 2.0
      adjusted[left] = {
        x: points[left].x,
        y: points[left].y * (1.0 - left_weight) + avg_y * left_weight,
      }
    }
    if mid > 0 && mid < last {
      adjusted[mid] = {
        x: points[mid].x,
        y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
      }
    }
  } else if mid > 0 && mid < last {
    adjusted[mid] = {
      x: points[mid].x,
      y: points[mid].y * (1.0 - right_weight) + mid_y * right_weight,
    }
  }
  adjusted
}

///|
fn ordered_nodes(graph : @cgraph.Graph) -> Array[@cgraph.Node] {
  graph.nodes()
}

///|
fn node_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  let mut key = ""
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  key
}

///|
fn node_local_cluster_key(node : @cgraph.Node) -> String {
  let mut graph = node.graph()
  while !graph.is_root() {
    if is_cluster_graph(graph) {
      match graph.name() {
        Some(name) => return name
        None => return ""
      }
    }
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  ""
}

///|
fn graph_cluster_key(graph : @cgraph.Graph) -> String {
  let mut current = graph
  let mut key = ""
  while !current.is_root() {
    if is_cluster_graph(current) {
      match current.name() {
        Some(name) => key = name
        None => key = ""
      }
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  key
}

///|
fn collect_edge_cluster_keys(
  graph : @cgraph.Graph,
  edge_cluster_keys : Map[String, String],
) -> Unit {
  for child in graph.subgraphs() {
    collect_edge_cluster_keys(child, edge_cluster_keys)
  }
  if !is_cluster_graph(graph) {
    return ()
  }
  let cluster_key = graph_cluster_key(graph)
  if cluster_key == "" {
    return ()
  }
  let child_edges : Map[String, Bool] = Map::new()
  for child in graph.subgraphs() {
    for edge in child.edges() {
      child_edges[edge_key(edge)] = true
    }
  }
  for edge in graph.edges() {
    let key = edge_key(edge)
    if child_edges.get(key) is None {
      edge_cluster_keys[key] = cluster_key
    }
  }
}

///|
fn intercluster_edge_key(
  tail_cluster : String,
  head_cluster : String,
  tail_rank : Int,
  head_rank : Int,
) -> String {
  "\{tail_cluster}@\{tail_rank}->\{head_cluster}@\{head_rank}"
}

///|
fn cluster_rank_key(cluster : String, rank : Int) -> String {
  "\{cluster}@\{rank}"
}

///|
fn edge_is_constraint(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("constraint") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "false" && lower != "0" && lower != "no"
    }
    None => true
  }
}

///|
fn port_is_explicit(port : @cgraph.Port?) -> Bool {
  match port {
    Some(value) => value.name is Some(_) || value.compass is Some(_)
    None => false
  }
}

///|
fn edge_weight(edge : @cgraph.Edge) -> Int {
  let weight_value = match edge.get_attr("weight") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let weight = weight_value.round().to_int()
  if weight < 0 {
    0
  } else {
    weight
  }
}

///|
fn edge_minlen(edge : @cgraph.Edge) -> Int {
  let minlen_value = match edge.get_attr("minlen") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let minlen = minlen_value.round().to_int()
  if minlen < 1 {
    1
  } else {
    minlen
  }
}

///|
fn edge_mid_label_text(edge : @cgraph.Edge) -> String? {
  match edge.get_attr("label") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
}

///|
fn edge_mid_label_width_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, _height) = label_text_dimensions(text, font, font_size_pt)
      width
    }
    None => 0.0
  }
}

///|
fn edge_mid_label_metrics(edge : @cgraph.Edge) -> (Double, Double)? {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  match edge_mid_label_text(edge) {
    Some(text) => {
      let (width, height) = label_text_dimensions(text, font, font_size_pt)
      Some((width, height))
    }
    None => None
  }
}

///|
fn edge_label_height_pt(edge : @cgraph.Edge) -> Double {
  let font_size_pt = @attrs.font_size(edge.get_attr("fontsize"))
  let font = @attrs.font_name(edge.get_attr("fontname"))
  let mut max_height = 0.0
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(text) =>
        if text != "" {
          let (_width, height) = label_text_dimensions(text, font, font_size_pt)
          if height > max_height {
            max_height = height
          }
        }
      None => ()
    }
  }
  max_height
}

///|
fn edge_has_label(edge : @cgraph.Edge) -> Bool {
  let labels = ["label", "headlabel", "taillabel"]
  for name in labels {
    match edge.get_attr(name) {
      Some(value) => if value != "" { return true }
      None => ()
    }
  }
  false
}

///|
fn graph_has_edge_labels(edges : Array[@cgraph.Edge]) -> Bool {
  for edge in edges {
    if edge_has_label(edge) {
      return true
    }
  }
  false
}

///|
fn self_edge_label_half_heights(
  edges : Array[@cgraph.Edge],
) -> Map[String, Double] {
  let heights : Map[String, Double] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail != head {
      continue
    }
    let half_height = edge_label_height_pt(edge) / 2.0
    let current = match heights.get(tail) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current {
      heights[tail] = half_height
    }
  }
  heights
}

///|
fn node_half_height_pt(
  name : String,
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Double {
  let base_height = match sizes.get(name) {
    Some(value) => value.height_pt / 2.0
    None => 0.0
  }
  let label_height = match self_edge_labels.get(name) {
    Some(value) => value
    None => 0.0
  }
  if label_height > base_height {
    label_height
  } else {
    base_height
  }
}

///|
fn cluster_label_padding_pt(graph : @cgraph.Graph) -> (Double, Double) {
  match graph_label_metrics(graph) {
    Some((_width_pt, height_pt)) => {
      let loc = graph_label_loc(graph)
      let pad = CLUSTER_LABEL_PAD_PT
      match loc {
        LabelLoc::Top => (height_pt + pad, 0.0)
        LabelLoc::Bottom => (0.0, height_pt + pad)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
priv struct ClusterHeights {
  min_rank : Int
  max_rank : Int
  ht1 : Double
  ht2 : Double
}

///|
fn collect_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  seen : Map[String, Bool],
  rank_heights : Map[Int, Double],
  min_rank : Int?,
  max_rank : Int?,
) -> (Int?, Int?) {
  let mut next_min = min_rank
  let mut next_max = max_rank
  for node in graph.nodes() {
    let name = node.name()
    if seen.get(name) is Some(_) {
      continue
    }
    seen[name] = true
    match ranks.get(name) {
      Some(rank) => {
        let half_height = node_half_height_pt(name, sizes, self_edge_labels)
        let current = match rank_heights.get(rank) {
          Some(value) => value
          None => 0.0
        }
        if half_height > current {
          rank_heights[rank] = half_height
        }
        match next_min {
          Some(value) => if rank < value { next_min = Some(rank) }
          None => next_min = Some(rank)
        }
        match next_max {
          Some(value) => if rank > value { next_max = Some(rank) }
          None => next_max = Some(rank)
        }
      }
      None => ()
    }
  }
  for child in graph.subgraphs() {
    let (child_min, child_max) = collect_cluster_rank_heights(
      child, ranks, sizes, self_edge_labels, seen, rank_heights, next_min, next_max,
    )
    next_min = child_min
    next_max = child_max
  }
  (next_min, next_max)
}

///|
fn apply_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> ClusterHeights? {
  let is_cluster = is_cluster_graph(graph)
  let children = graph.subgraphs()
  if !is_cluster {
    for child in children {
      let _ = apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      )

    }
    return None
  }
  let seen : Map[String, Bool] = Map::new()
  let rank_heights : Map[Int, Double] = Map::new()
  let (min_rank, max_rank) = collect_cluster_rank_heights(
    graph,
    ranks,
    sizes,
    self_edge_labels,
    seen,
    rank_heights,
    None,
    None,
  )
  let min_rank_value = match min_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let max_rank_value = match max_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let margin = cluster_margin_pt(graph)
  let base_top = match rank_heights.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let base_bottom = match rank_heights.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let mut ht1 = base_top + margin
  let mut ht2 = base_bottom + margin
  for child in children {
    match
      apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      ) {
      Some(info) => {
        if info.max_rank == max_rank_value {
          let candidate = info.ht1 + margin
          if candidate > ht1 {
            ht1 = candidate
          }
        }
        if info.min_rank == min_rank_value {
          let candidate = info.ht2 + margin
          if candidate > ht2 {
            ht2 = candidate
          }
        }
      }
      None => ()
    }
  }
  let (label_top, label_bottom) = cluster_label_padding_pt(graph)
  ht1 = ht1 + label_bottom
  ht2 = ht2 + label_top
  let current_top = match rank_ht1.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht1 > current_top {
    rank_ht1[max_rank_value] = ht1
  }
  let current_bottom = match rank_ht2.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht2 > current_bottom {
    rank_ht2[min_rank_value] = ht2
  }
  Some({ min_rank: min_rank_value, max_rank: max_rank_value, ht1, ht2 })
}

///|
fn collect_rank_extremes(
  subgraph : @cgraph.Graph,
  min_nodes : Map[String, Bool],
  max_nodes : Map[String, Bool],
) -> Unit {
  match subgraph.get_attr("rank") {
    Some(value) => {
      let lower = value.to_lower()
      if lower == "min" || lower == "source" {
        for node in subgraph.nodes() {
          min_nodes[node.name()] = true
        }
      } else if lower == "max" || lower == "sink" {
        for node in subgraph.nodes() {
          max_nodes[node.name()] = true
        }
      }
    }
    None => ()
  }
  for child in subgraph.subgraphs() {
    collect_rank_extremes(child, min_nodes, max_nodes)
  }
}

///|
fn apply_rank_extremes(
  ranks : Map[String, Int],
  min_nodes : Map[String, Bool],
  max_nodes : Map[String, Bool],
) -> Unit {
  if ranks.length() == 0 {
    return ()
  }
  let mut max_rank = 0
  let mut seen = false
  for _name, rank in ranks {
    if !seen {
      max_rank = rank
      seen = true
    } else if rank > max_rank {
      max_rank = rank
    }
  }
  if min_nodes.length() > 0 {
    for name, _ in min_nodes {
      match ranks.get(name) {
        Some(_) => ranks[name] = 0
        None => ()
      }
    }
  }
  if max_nodes.length() > 0 {
    for name, _ in max_nodes {
      match ranks.get(name) {
        Some(_) => ranks[name] = max_rank
        None => ()
      }
    }
  }
}

///|
fn add_rank_same_constraints(
  rank_graph : NsGraph,
  index : Map[String, Int],
  subgraph : @cgraph.Graph,
) -> Unit {
  match subgraph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let nodes = subgraph.nodes()
        if nodes.length() > 1 {
          let mut i = 0
          while i < nodes.length() {
            let name_i = nodes[i].name()
            let idx_i = match index.get(name_i) {
              Some(value) => value
              None => -1
            }
            if idx_i >= 0 {
              let mut j = i + 1
              while j < nodes.length() {
                let name_j = nodes[j].name()
                let idx_j = match index.get(name_j) {
                  Some(value) => value
                  None => -1
                }
                if idx_j >= 0 {
                  let _ = add_edge(rank_graph, idx_i, idx_j, 0, 1000)
                  let _ = add_edge(rank_graph, idx_j, idx_i, 0, 1000)

                }
                j = j + 1
              }
            }
            i = i + 1
          }
        }
      }
    None => ()
  }
  for child in subgraph.subgraphs() {
    add_rank_same_constraints(rank_graph, index, child)
  }
}

///|
fn collect_rank_same_order(
  graph : @cgraph.Graph,
  group_ids : Map[String, Int],
  order_ids : Map[String, Int],
  next_group : Int,
) -> Int {
  let mut current_group = next_group
  match graph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let group_id = current_group
        current_group = current_group + 1
        let mut idx = 0
        for node in graph.nodes() {
          if group_ids.get(node.name()) is None {
            group_ids[node.name()] = group_id
            order_ids[node.name()] = idx
          }
          idx = idx + 1
        }
      }
    None => ()
  }
  for child in graph.subgraphs() {
    current_group = collect_rank_same_order(
      child, group_ids, order_ids, current_group,
    )
  }
  current_group
}

///|
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  let graph = new_graph()
  let index : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    index[name] = add_node(graph, name)
  }
  for edge in edges {
    if !edge_is_constraint(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_idx = match index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_idx = match index.get(head) {
      Some(value) => value
      None => 0
    }
    let minlen_value = edge_minlen(edge)
    let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
    let weight = edge_weight(edge)
    let _ = add_edge(graph, tail_idx, head_idx, minlen, weight)

  }
  add_rank_same_constraints(graph, index, source)
  network_simplex(graph, 0x7fffffff, BalanceMode::TB)
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = graph.nodes[idx].rank
    if !seen {
      min_rank = rank
      seen = true
    } else if rank < min_rank {
      min_rank = rank
    }
  }
  for node in nodes {
    let name = node.name()
    let idx = match index.get(name) {
      Some(value) => value
      None => 0
    }
    let rank = graph.nodes[idx].rank - min_rank
    ranks[name] = rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(source, min_nodes, max_nodes)
  apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}

///|
fn build_edge_index(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let parents : Map[String, Array[String]] = Map::new()
  let children : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    parents[name] = []
    children[name] = []
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    match parents.get(head) {
      Some(list) => list.push(tail)
      None => parents[head] = [tail]
    }
    match children.get(tail) {
      Some(list) => list.push(head)
      None => children[tail] = [head]
    }
  }
  (parents, children)
}

///|
fn median_positions(
  names : Array[String],
  x_positions : Map[String, Double],
) -> Double? {
  let values : Array[Double] = []
  for name in names {
    match x_positions.get(name) {
      Some(value) => values.push(value)
      None => ()
    }
  }
  if values.length() == 0 {
    None
  } else {
    values.sort()
    let mid = values.length() / 2
    if values.length() % 2 == 0 {
      Some((values[mid - 1] + values[mid]) / 2.0)
    } else {
      Some(values[mid])
    }
  }
}

///|
fn position_key(
  name : String,
  desired : Map[String, Double],
  x_positions : Map[String, Double],
) -> Double {
  match desired.get(name) {
    Some(value) => value
    None =>
      match x_positions.get(name) {
        Some(value) => value
        None => 0.0
      }
  }
}

///|
fn sort_by_positions(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  parents_map : Map[String, Array[String]],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let _ = edge_order
  let mut i = 1
  while i < sorted.length() {
    let current = sorted[i]
    let current_key = position_key(current, desired, x_positions)
    let mut j = i
    let current_degree = match primary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    let current_secondary = match secondary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    while j > 0 {
      let prev = sorted[j - 1]
      let prev_key = position_key(prev, desired, x_positions)
      let diff = prev_key - current_key
      if diff < -0.000001 {
        break
      }
      if Double::abs(diff) <= 0.000001 {
        let prev_degree = match primary.get(prev) {
          Some(list) => list.length()
          None => 0
        }
        if prev_degree < current_degree {
          // move current left
        } else if prev_degree > current_degree {
          break
        } else {
          let prev_ported = port_edge_nodes.get(prev) is Some(_)
          let current_ported = port_edge_nodes.get(current) is Some(_)
          if prev_ported != current_ported {
            if !current_ported {
              break
            }
          } else {
            let prev_secondary = match secondary.get(prev) {
              Some(list) => list.length()
              None => 0
            }
            if prev_secondary < current_secondary {
              // move current left
            } else if prev_secondary > current_secondary {
              break
            } else {
              let mut decided = false
              if prev_ported && current_ported {
                let prev_idx = match node_order.get(prev) {
                  Some(value) => value
                  None => 0
                }
                let current_idx = match node_order.get(current) {
                  Some(value) => value
                  None => 0
                }
                decided = true
                if prev_idx <= current_idx {
                  break
                }
              }
              if !decided {
                match rank_same_groups.get(prev) {
                  Some(prev_group) =>
                    match rank_same_groups.get(current) {
                      Some(current_group) =>
                        if prev_group == current_group {
                          let prev_idx = match rank_same_order.get(prev) {
                            Some(value) => value
                            None => 0
                          }
                          let current_idx = match rank_same_order.get(current) {
                            Some(value) => value
                            None => 0
                          }
                          decided = true
                          if prev_idx <= current_idx {
                            break
                          }
                        }
                      None => ()
                    }
                  None => ()
                }
              }
              if !decided {
                let prev_parents = match parents_map.get(prev) {
                  Some(list) => list
                  None => []
                }
                let current_parents = match parents_map.get(current) {
                  Some(list) => list
                  None => []
                }
                for parent in prev_parents {
                  let mut shared = false
                  for candidate in current_parents {
                    if candidate == parent {
                      shared = true
                      break
                    }
                  }
                  if !shared {
                    continue
                  }
                  let prev_key = "\{parent}|\{prev}"
                  let current_key = "\{parent}|\{current}"
                  match edge_pair_order.get(prev_key) {
                    Some(prev_idx) =>
                      match edge_pair_order.get(current_key) {
                        Some(current_idx) => {
                          decided = true
                          if prev_idx <= current_idx {
                            break
                          }
                        }
                        None => ()
                      }
                    None => ()
                  }
                  if decided {
                    break
                  }
                }
              }
              if !decided {
                break
              }
            }
          }
        }
      }
      sorted[j] = prev
      j = j - 1
    }
    sorted[j] = current
    i = i + 1
  }
  sorted
}

///|
fn median_value(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let sorted = values.copy()
  sorted.sort()
  let mid = sorted.length() / 2
  if sorted.length() % 2 == 0 {
    Some((sorted[mid - 1] + sorted[mid]) / 2.0)
  } else {
    Some(sorted[mid])
  }
}

///|
fn collect_edge_order(edges : Array[@cgraph.Edge]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  let mut idx = 0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if order.get(tail) is None {
      order[tail] = idx
    }
    if order.get(head) is None {
      order[head] = idx
    }
    idx = idx + 1
  }
  order
}

///|
fn order_rank_by_cluster(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  parents_map : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
) -> Array[String] {
  if names.length() < 2 {
    return names.copy()
  }
  let group_keys : Array[String] = []
  let group_nodes : Array[Array[String]] = []
  let group_order : Array[Int] = []
  let group_index : Map[String, Int] = Map::new()
  let mut next_index = 0
  for name in names {
    let cluster_key = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    let group_key = if cluster_key == "" { name } else { cluster_key }
    let idx = match group_index.get(group_key) {
      Some(value) => value
      None => {
        let index = next_index
        next_index = next_index + 1
        group_index[group_key] = index
        group_keys.push(group_key)
        group_nodes.push([])
        group_order.push(index)
        index
      }
    }
    group_nodes[idx].push(name)
  }
  let group_values : Array[Double] = []
  let group_secondary : Array[Int] = []
  for i in 0..<group_nodes.length() {
    let values : Array[Double] = []
    let mut secondary_total = 0
    for name in group_nodes[i] {
      match desired.get(name) {
        Some(value) => values.push(value)
        None =>
          match x_positions.get(name) {
            Some(value) => values.push(value)
            None => ()
          }
      }
      match secondary.get(name) {
        Some(list) => secondary_total = secondary_total + list.length()
        None => ()
      }
    }
    let value = match median_value(values) {
      Some(val) => val
      None => 0.0
    }
    group_values.push(value)
    group_secondary.push(secondary_total)
  }
  let order : Array[Int] = []
  for i in 0..<group_nodes.length() {
    order.push(i)
  }
  let mut i = 1
  while i < order.length() {
    let current = order[i]
    let current_val = group_values[current]
    let mut j = i
    while j > 0 {
      let prev = order[j - 1]
      let prev_val = group_values[prev]
      if prev_val < current_val {
        break
      }
      if prev_val == current_val {
        let prev_secondary = group_secondary[prev]
        let current_secondary = group_secondary[current]
        if prev_secondary < current_secondary {
          // move current left
        } else if prev_secondary > current_secondary {
          break
        } else if group_order[prev] <= group_order[current] {
          break
        }
      }
      order[j] = prev
      j = j - 1
    }
    order[j] = current
    i = i + 1
  }
  let result : Array[String] = []
  for idx in order {
    let group = group_nodes[idx]
    let ordered_group = sort_by_positions(
      group, desired, x_positions, primary, secondary, parents_map, rank_same_groups,
      rank_same_order, edge_order, node_order, port_edge_nodes, edge_pair_order,
    )
    for name in ordered_group {
      result.push(name)
    }
  }
  result
}

///|
fn compute_desired_positions(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  x_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    match median_positions(list, x_positions) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|

///|
fn compute_desired_positions_with_rank_fallback(
  names : Array[String],
  children : Map[String, Array[String]],
  parents : Map[String, Array[String]],
  x_positions : Map[String, Double],
  ranks : Map[String, Int],
  rank_sizes : Map[Int, Int],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    let child_list = match children.get(name) {
      Some(value) => value
      None => []
    }
    let mut use_children = false
    for child in child_list {
      match ranks.get(child) {
        Some(rank) =>
          match rank_sizes.get(rank) {
            Some(size) =>
              if size > 1 {
                use_children = true
                break
              }
            None => ()
          }
        None => ()
      }
    }
    let primary = if use_children { children } else { parents }
    let fallback = if use_children { parents } else { children }
    let list = match primary.get(name) {
      Some(value) => value
      None => []
    }
    match median_positions(list, x_positions) {
      Some(value) => desired[name] = value
      None => ()
    }
    if desired.get(name) is None {
      let fallback_list = match fallback.get(name) {
        Some(value) => value
        None => []
      }
      match median_positions(fallback_list, x_positions) {
        Some(value) => desired[name] = value
        None => ()
      }
    }
  }
  desired
}

///|

///|
fn node_width_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.width_pt
    None => default_node_width_in() * 72.0
  }
}

///|
fn node_left_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.left_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn node_right_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.right_pt
    None => default_node_width_in() * 72.0 / 2.0
  }
}

///|
fn adjust_rank_positions(
  names : Array[String],
  x_positions : Map[String, Double],
  sizes : Map[String, NodeSize],
  desired : Map[String, Double],
  nodesep_pt : Double,
) -> Unit {
  let len = names.length()
  if len == 0 {
    return ()
  }
  let lefts : Array[Double] = []
  let rights : Array[Double] = []
  let targets : Array[Double] = []
  let cumulative : Array[Double] = []
  let mut cum = 0.0
  for i in 0..<len {
    let name = names[i]
    let left = node_left_pt(name, sizes)
    let right = node_right_pt(name, sizes)
    lefts.push(left)
    rights.push(right)
    let fallback = match x_positions.get(name) {
      Some(value) => value
      None => left
    }
    let target = match desired.get(name) {
      Some(value) => (value + fallback) / 2.0
      None => fallback
    }
    targets.push(target)
    if i == 0 {
      cum = 0.0
    } else {
      let prev_right = rights[i - 1]
      let sep = prev_right + left + nodesep_pt
      cum = cum + sep
    }
    cumulative.push(cum)
  }
  let block_values : Array[Double] = []
  let block_weights : Array[Int] = []
  let block_counts : Array[Int] = []
  for i in 0..<len {
    let t = targets[i] - cumulative[i]
    block_values.push(t)
    block_weights.push(1)
    block_counts.push(1)
    while block_values.length() >= 2 {
      let last = block_values.length() - 1
      let prev = last - 1
      if block_values[prev] <= block_values[last] {
        break
      }
      let weight = block_weights[prev] + block_weights[last]
      let left = block_values[prev] * block_weights[prev].to_double()
      let right = block_values[last] * block_weights[last].to_double()
      let value = (left + right) / weight.to_double()
      let count = block_counts[prev] + block_counts[last]
      block_values[prev] = value
      block_weights[prev] = weight
      block_counts[prev] = count
      let _ = block_values.pop()
      let _ = block_weights.pop()
      let _ = block_counts.pop()

    }
  }
  let y_values : Array[Double] = []
  for i in 0..<block_values.length() {
    let value = block_values[i]
    let count = block_counts[i]
    for _j in 0..<count {
      y_values.push(value)
    }
  }
  for i in 0..<len {
    let name = names[i]
    let x = y_values[i] + cumulative[i]
    x_positions[name] = x
  }
}

///|
fn normalize_x_positions(
  nodes : Array[@cgraph.Node],
  extra_names : Array[String],
  x_positions : Map[String, Double],
  sizes : Map[String, NodeSize],
) -> Unit {
  let mut min_x = 0.0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let left_width = node_left_pt(name, sizes)
    let pos = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let left = pos - left_width
    if !seen {
      min_x = left
      seen = true
    } else if left < min_x {
      min_x = left
    }
  }
  for name in extra_names {
    let left_width = node_left_pt(name, sizes)
    let pos = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let left = pos - left_width
    if !seen {
      min_x = left
      seen = true
    } else if left < min_x {
      min_x = left
    }
  }
  if seen && min_x != 0.0 {
    for node in nodes {
      let name = node.name()
      match x_positions.get(name) {
        Some(value) => x_positions[name] = value - min_x
        None => ()
      }
    }
    for name in extra_names {
      match x_positions.get(name) {
        Some(value) => x_positions[name] = value - min_x
        None => ()
      }
    }
  }
}

///|
fn adjust_intercluster_alignment(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  x_positions : Map[String, Double],
  cluster_keys : Map[String, String],
  intercluster_keys : Map[String, String],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Unit {
  let cluster_rank_nodes : Map[String, Array[String]] = Map::new()
  let cluster_rank_value : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(cluster, rank)
    cluster_rank_value[key] = rank
    match cluster_rank_nodes.get(key) {
      Some(list) => list.push(name)
      None => cluster_rank_nodes[key] = [name]
    }
  }
  let cluster_rank_targets : Map[String, Map[String, Bool]] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = match intercluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match intercluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster == "" || tail_cluster == head_cluster {
      continue
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let key = cluster_rank_key(tail_cluster, tail_rank)
    match cluster_rank_targets.get(key) {
      Some(targets) => targets[head] = true
      None => {
        let targets : Map[String, Bool] = Map::new()
        targets[head] = true
        cluster_rank_targets[key] = targets
      }
    }
  }
  let eps = 0.01
  for key, names in cluster_rank_nodes {
    if names.length() < 2 {
      continue
    }
    let targets = match cluster_rank_targets.get(key) {
      Some(value) => value
      None => continue
    }
    if targets.length() != 1 {
      continue
    }
    let mut target_name = ""
    for name, _ in targets {
      target_name = name
      break
    }
    let target_x = match x_positions.get(target_name) {
      Some(value) => value
      None => continue
    }
    let mut aligned = false
    for name in names {
      match x_positions.get(name) {
        Some(value) =>
          if Double::abs(value - target_x) <= eps {
            aligned = true
            break
          }
        None => ()
      }
    }
    if !aligned {
      continue
    }
    let rank = match cluster_rank_value.get(key) {
      Some(value) => value
      None => continue
    }
    let shift = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    for name in names {
      match x_positions.get(name) {
        Some(value) => x_positions[name] = value - shift
        None => ()
      }
    }
  }
}

///|
fn rank_nodesep_pt(
  rank : Int,
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Double {
  if has_edge_labels && rank % 2 != 0 {
    nodesep_pt * EDGE_LABEL_NODESEP_SCALE
  } else {
    nodesep_pt
  }
}

///|
fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() == 0 {
      continue
    }
    let first = names[0]
    positions[first] = 0.0
    let mut current = 0
    let mut prev = first
    let mut i = 1
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    while i < names.length() {
      let name = names[i]
      let tail_right = node_right_pt(prev, sizes)
      let head_left = node_left_pt(name, sizes)
      let width = tail_right + head_left + rank_nodesep
      current = trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
}

///|
fn unique_virtual_node_name(
  prefix : String,
  edge_index : Int,
  rank : Int,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = "\{prefix}\{edge_index}_\{rank}"
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{prefix}\{edge_index}_\{rank}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}
///|
fn build_vnode_order_keys(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  let keys : Map[String, Double] = Map::new()
  for edge in edges {
    let vnodes = match edge_vnodes.get(edge_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_order = match order_index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_order = match order_index.get(head) {
      Some(value) => value
      None => 0
    }
    let (low_rank, high_rank, low_order, high_order) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_order, head_order)
    } else {
      (head_rank, tail_rank, head_order, tail_order)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    let low_order_f = Double::from_int(low_order)
    let high_order_f = Double::from_int(high_order)
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let key = low_order_f + (high_order_f - low_order_f) * t
      keys[vnode] = key
    }
  }
  keys
}
///|
///|
fn build_edge_vnodes(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  nodesep_pt : Double,
  existing_names : Map[String, Bool],
  edge_cluster_keys : Map[String, String],
) -> EdgeVnodeInfo {
  let vnode_ranks : Map[String, Int] = Map::new()
  let vnode_sizes : Map[String, NodeSize] = Map::new()
  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  let vnode_clusters : Map[String, String] = Map::new()
  let mut edge_index = 0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_cluster = node_cluster_key(edge.tail())
    let head_cluster = node_cluster_key(edge.head())
    let edge_cluster = match edge_cluster_keys.get(edge_key(edge)) {
      Some(value) => value
      None => ""
    }
    let vnode_cluster = if edge_cluster != "" &&
      tail_cluster == edge_cluster &&
      head_cluster == edge_cluster {
      edge_cluster
    } else if tail_cluster != "" && tail_cluster == head_cluster {
      tail_cluster
    } else {
      ""
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => {
        edge_index = edge_index + 1
        continue
      }
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => {
        edge_index = edge_index + 1
        continue
      }
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      edge_index = edge_index + 1
      continue
    }
    let label_width = edge_mid_label_width_pt(edge)
    let label_rank = if label_width > 0.0 {
      (min_rank + max_rank) / 2
    } else {
      -1
    }
    let names : Array[String] = []
    let mut rank = min_rank + 1
    while rank < max_rank {
      let (left_pt, right_pt) =
        if rank == label_rank && label_width > 0.0 {
          (nodesep_pt, label_width)
        } else {
          let half = nodesep_pt / 2.0
          (half, half)
        }
      let name = unique_virtual_node_name(
        EDGE_VNODE_PREFIX,
        edge_index,
        rank,
        existing_names,
      )
      vnode_ranks[name] = rank
      vnode_sizes[name] = vnode_size_from_widths(left_pt, right_pt)
      vnode_clusters[name] = vnode_cluster
      match vnodes_by_rank.get(rank) {
        Some(list) => list.push(name)
        None => vnodes_by_rank[rank] = [name]
      }
      names.push(name)
      rank = rank + 1
    }
    if names.length() > 0 {
      let key = edge_key(edge)
      match edge_vnodes.get(key) {
        Some(list) =>
          for name in names {
            list.push(name)
          }
        None => edge_vnodes[key] = names
      }
    }
    edge_index = edge_index + 1
  }
  { vnode_ranks, vnode_sizes, vnodes_by_rank, edge_vnodes, vnode_clusters }
}

///|
fn build_node_singletons(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> Map[String, Bool] {
  let counts : Map[String, Int] = Map::new()
  for node in nodes {
    counts[node.name()] = 0
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_count = match counts.get(tail) {
      Some(value) => value
      None => 0
    }
    counts[tail] = tail_count + 1
    let head_count = match counts.get(head) {
      Some(value) => value
      None => 0
    }
    counts[head] = head_count + 1
  }
  let singletons : Map[String, Bool] = Map::new()
  for name, count in counts {
    if count <= 1 {
      singletons[name] = true
    }
  }
  singletons
}

///|
fn virtual_endpoint_class(
  name : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  if vnode_ranks.get(name) is Some(_) {
    2
  } else if node_singletons.get(name) is Some(_) {
    1
  } else {
    0
  }
}

///|
fn virtual_weight_scale(
  tail : String,
  head : String,
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
) -> Int {
  let tail_class = virtual_endpoint_class(tail, vnode_ranks, node_singletons)
  let head_class = virtual_endpoint_class(head, vnode_ranks, node_singletons)
  if tail_class == 0 {
    1
  } else if tail_class == 1 {
    if head_class == 0 { 1 } else { 2 }
  } else {
    if head_class == 2 {
      4
    } else if head_class == 1 {
      2
    } else {
      1
    }
  }
}

///|
fn edge_port_name(port : @cgraph.Port?) -> String? {
  match port {
    Some(value) => value.name
    None => None
  }
}

///|
fn endpoint_port_name(
  node_name : String,
  tail_name : String,
  head_name : String,
  tail_port : String?,
  head_port : String?,
) -> String? {
  if node_name == tail_name {
    tail_port
  } else if node_name == head_name {
    head_port
  } else {
    None
  }
}

///|
fn build_virtual_slack_edges(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  node_singletons : Map[String, Bool],
  cluster_keys : Map[String, String],
) -> Array[ConstraintEdge] {
  let extra : Array[ConstraintEdge] = []
  let intercluster_seen : Map[String, Bool] = Map::new()
  for edge in edges {
    let key = edge_key(edge)
    let vnodes = match edge_vnodes.get(key) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_port_name = edge_port_name(edge.tail_port())
    let head_port_name = edge_port_name(edge.head_port())
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    if tail_cluster != head_cluster && (tail_cluster != "" || head_cluster != "") {
      let cluster_key = intercluster_edge_key(
        tail_cluster,
        head_cluster,
        tail_rank,
        head_rank,
      )
      if intercluster_seen.get(cluster_key) is Some(_) {
        continue
      }
      intercluster_seen[cluster_key] = true
    }
    let low = if tail_rank <= head_rank { tail } else { head }
    let high = if tail_rank <= head_rank { head } else { tail }
    let base_weight = edge_weight(edge)
    let mut prev = low
    for vnode in vnodes {
      let scale = virtual_weight_scale(prev, vnode, vnode_ranks, node_singletons)
      let tail_port = endpoint_port_name(
        prev,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      let head_port = endpoint_port_name(
        vnode,
        tail,
        head,
        tail_port_name,
        head_port_name,
      )
      extra.push({
        tail: prev,
        head: vnode,
        minlen: 1,
        weight: base_weight * scale,
        tail_port,
        head_port,
      })
      prev = vnode
    }
    let scale = virtual_weight_scale(prev, high, vnode_ranks, node_singletons)
    let tail_port = endpoint_port_name(
      prev,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    let head_port = endpoint_port_name(
      high,
      tail,
      head,
      tail_port_name,
      head_port_name,
    )
    extra.push({
      tail: prev,
      head: high,
      minlen: 1,
      weight: base_weight * scale,
      tail_port,
      head_port,
    })
  }
  extra
}

///|


///|
fn merge_sizes_with_vnodes(
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  let merged : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    merged[name] = size
  }
  for name, size in vnode_sizes {
    merged[name] = size
  }
  merged
}

///|
fn sort_rank_items(items : Array[(Double, Int, String)]) -> Array[String] {
  let sorted = items.copy()
  let mut i = 1
  while i < sorted.length() {
    let current = sorted[i]
    let (current_key, current_tie, _current_name) = current
    let mut j = i
    while j > 0 {
      let prev = sorted[j - 1]
      let (prev_key, prev_tie, _prev_name) = prev
      let same_key = Double::abs(prev_key - current_key) <= 0.000001
      if prev_key < current_key || (same_key && prev_tie <= current_tie) {
        break
      }
      sorted[j] = prev
      j = j - 1
    }
    sorted[j] = current
    i = i + 1
  }
  let names : Array[String] = []
  for item in sorted {
    let (_key, _tie, name) = item
    names.push(name)
  }
  names
}

///|
fn build_x_groups_with_vnodes(
  ordered_groups : Map[Int, Array[String]],
  order_index : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys : Map[String, Double],
) -> Map[Int, Array[String]] {
  let result : Map[Int, Array[String]] = Map::new()
  let rank_set : Map[Int, Bool] = Map::new()
  for rank, _names in ordered_groups {
    rank_set[rank] = true
  }
  for rank, _names in vnodes_by_rank {
    rank_set[rank] = true
  }
  let ranks : Array[Int] = []
  for rank, _ in rank_set {
    ranks.push(rank)
  }
  ranks.sort()
  for rank in ranks {
    let names = match ordered_groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    let vnodes = match vnodes_by_rank.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    if vnodes.length() == 0 {
      if names.length() > 0 {
        result[rank] = names
      }
      continue
    }
    let items : Array[(Double, Int, String)] = []
    let mut idx = 0
    for name in names {
      let key = match order_index.get(name) {
        Some(value) => value.to_double()
        None => idx.to_double()
      }
      items.push((key, idx, name))
      idx = idx + 1
    }
    let tie_offset = names.length() + 1
    let mut v_idx = 0
    for name in vnodes {
      let key = match vnode_order_keys.get(name) {
        Some(value) => value
        None => 0.0
      }
      items.push((key, tie_offset + v_idx, name))
      v_idx = v_idx + 1
    }
    result[rank] = sort_rank_items(items)
  }
  result
}

///|
fn collect_rank_keys(groups : Map[Int, Array[String]]) -> Array[Int] {
  let keys : Array[Int] = []
  for rank, _ in groups {
    keys.push(rank)
  }
  keys.sort()
  keys
}

///|
fn build_vnode_extra_nodes(
  vnode_ranks : Map[String, Int],
) -> Array[(String, Int)] {
  let extra : Array[(String, Int)] = []
  for name, rank in vnode_ranks {
    extra.push((name, rank))
  }
  extra
}

///|
fn clone_rank_groups(
  groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let cloned : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    cloned[rank] = names.copy()
  }
  cloned
}

///|
fn build_node_ranks(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map::new()
  for rank, names in groups {
    for name in names {
      ranks[name] = rank
    }
  }
  ranks
}

///|
fn build_order_index(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      order[names[i]] = i
    }
  }
  order
}

///|
fn count_crossings(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
) -> Int {
  let order = build_order_index(groups)
  let edge_groups : Map[String, Array[(Int, Int)]] = Map::new()
  for edge in edges {
    if !edge_is_constraint(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    if tail_rank == head_rank {
      continue
    }
    let low_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let high_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    let low_node = if tail_rank < head_rank { tail } else { head }
    let high_node = if tail_rank < head_rank { head } else { tail }
    let low_order = match order.get(low_node) {
      Some(value) => value
      None => continue
    }
    let high_order = match order.get(high_node) {
      Some(value) => value
      None => continue
    }
    let key = "\{low_rank}:\{high_rank}"
    match edge_groups.get(key) {
      Some(list) => list.push((low_order, high_order))
      None => edge_groups[key] = [(low_order, high_order)]
    }
  }
  let mut crossings = 0
  for _key, list in edge_groups {
    for i in 0..<list.length() {
      let (t1, h1) = list[i]
      let mut j = i + 1
      while j < list.length() {
        let (t2, h2) = list[j]
        let dt = t1 - t2
        let dh = h1 - h2
        if dt * dh < 0 {
          crossings = crossings + 1
        }
        j = j + 1
      }
    }
  }
  crossings
}

///|
fn crossing_for_pair(
  left : String,
  right : String,
  rank : Int,
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
) -> Int {
  let mut count = 0
  let left_parents = match parents.get(left) {
    Some(value) => value
    None => []
  }
  let right_parents = match parents.get(right) {
    Some(value) => value
    None => []
  }
  for lp in left_parents {
    if ranks.get(lp) != Some(rank - 1) {
      continue
    }
    let lp_order = match order.get(lp) {
      Some(value) => value
      None => continue
    }
    for rp in right_parents {
      if ranks.get(rp) != Some(rank - 1) {
        continue
      }
      let rp_order = match order.get(rp) {
        Some(value) => value
        None => continue
      }
      if lp_order > rp_order {
        count = count + 1
      }
    }
  }
  let left_children = match children.get(left) {
    Some(value) => value
    None => []
  }
  let right_children = match children.get(right) {
    Some(value) => value
    None => []
  }
  for lc in left_children {
    if ranks.get(lc) != Some(rank + 1) {
      continue
    }
    let lc_order = match order.get(lc) {
      Some(value) => value
      None => continue
    }
    for rc in right_children {
      if ranks.get(rc) != Some(rank + 1) {
        continue
      }
      let rc_order = match order.get(rc) {
        Some(value) => value
        None => continue
      }
      if lc_order > rc_order {
        count = count + 1
      }
    }
  }
  count
}

///|
fn transpose_rank(
  rank : Int,
  names : Array[String],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
  reverse : Bool,
) -> Bool {
  let mut changed = false
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    let c0 = crossing_for_pair(
      left, right, rank, parents, children, ranks, order,
    )
    let c1 = crossing_for_pair(
      right, left, rank, parents, children, ranks, order,
    )
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      names[i] = right
      names[i + 1] = left
      order[left] = i + 1
      order[right] = i
      changed = true
    }
    i = i + 1
  }
  changed
}

///|
fn transpose_rank_groups_limited(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  reverse : Bool,
  max_passes : Int,
) -> Bool {
  let mut changed_any = false
  let mut changed = true
  let mut passes = 0
  while changed {
    if passes >= max_passes {
      break
    }
    passes = passes + 1
    changed = false
    let order = build_order_index(ordered)
    for rank in rank_keys {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() < 2 {
        continue
      }
      if transpose_rank(rank, names, parents, children, ranks, order, reverse) {
        ordered[rank] = names
        changed = true
        changed_any = true
      }
    }
  }
  changed_any
}

///|
fn reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edges : Array[@cgraph.Edge],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Map[Int, Array[String]] {
  let ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    ordered[rank] = names
  }
  let rank_sizes : Map[Int, Int] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    rank_sizes[rank] = names.length()
  }
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge in edges {
    let ported = port_is_explicit(edge.tail_port()) ||
      port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge.tail().name()] = true
      port_edge_nodes[edge.head().name()] = true
    }
  }
  let edge_pair_order : Map[String, Int] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    edge_pair_order["\{tail}|\{head}"] = edge_idx
    edge_idx = edge_idx + 1
  }
  let node_ranks = build_node_ranks(ordered)
  let mut best_ordered = clone_rank_groups(ordered)
  let mut best_cross = count_crossings(ordered, node_ranks, edges)
  let mut x_positions = compute_rank_positions(
    rank_keys, ordered, sizes, nodesep_pt, has_edge_labels,
  )
  if rank_keys.length() > 1 {
    let iterations = 1
    let mut iter = 0
    while iter < iterations {
      let mut idx = rank_keys.length() - 1
      while idx > 0 {
        let rank = rank_keys[idx - 1]
        let names = match ordered.get(rank) {
          Some(list) => list
          None => []
        }
        if names.length() > 1 {
          let desired = compute_desired_positions(names, children, x_positions)
          ordered[rank] = order_rank_by_cluster(
            names, desired, x_positions, children, parents, parents, cluster_keys,
            rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
            edge_pair_order,
          )
          x_positions = compute_rank_positions(
            rank_keys, ordered, sizes, nodesep_pt, has_edge_labels,
          )
        }
        idx = idx - 1
      }
      let _ = transpose_rank_groups_limited(
        rank_keys, ordered, parents, children, node_ranks, true, 2,
      )
      for rank in rank_keys {
        let names = match ordered.get(rank) {
          Some(list) => list
          None => []
        }
        if names.length() > 1 {
          let desired = compute_desired_positions(names, children, x_positions)
          ordered[rank] = order_rank_by_cluster(
            names, desired, x_positions, children, parents, parents, cluster_keys,
            rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
            edge_pair_order,
          )
        }
      }
      let down_cross = count_crossings(ordered, node_ranks, edges)
      if down_cross <= best_cross {
        best_cross = down_cross
        best_ordered = clone_rank_groups(ordered)
      }
      let mut j = 1
      while j < rank_keys.length() {
        let rank = rank_keys[j]
        let names = match ordered.get(rank) {
          Some(list) => list
          None => []
        }
        if names.length() > 1 {
          let desired = compute_desired_positions(names, parents, x_positions)
          ordered[rank] = order_rank_by_cluster(
            names, desired, x_positions, parents, children, parents, cluster_keys,
            rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
            edge_pair_order,
          )
          x_positions = compute_rank_positions(
            rank_keys, ordered, sizes, nodesep_pt, has_edge_labels,
          )
        }
        j = j + 1
      }
      let _ = transpose_rank_groups_limited(
        rank_keys, ordered, parents, children, node_ranks, false, 2,
      )
      for rank in rank_keys {
        let names = match ordered.get(rank) {
          Some(list) => list
          None => []
        }
        if names.length() > 1 {
          let desired = compute_desired_positions(names, parents, x_positions)
          ordered[rank] = order_rank_by_cluster(
            names, desired, x_positions, parents, children, parents, cluster_keys,
            rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
            edge_pair_order,
          )
        }
      }
      let up_cross = count_crossings(ordered, node_ranks, edges)
      if up_cross < best_cross {
        best_cross = up_cross
        best_ordered = clone_rank_groups(ordered)
      }
      iter = iter + 1
    }
  }
  let final_ordered = clone_rank_groups(best_ordered)
  let final_positions = compute_rank_positions(
    rank_keys, final_ordered, sizes, nodesep_pt, has_edge_labels,
  )
  for rank in rank_keys {
    let names = match final_ordered.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() > 1 {
      let desired = compute_desired_positions_with_rank_fallback(
        names, children, parents, final_positions, node_ranks, rank_sizes,
      )
      final_ordered[rank] = order_rank_by_cluster(
        names, desired, final_positions, children, parents, parents, cluster_keys,
        rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
        edge_pair_order,
      )
    }
  }
  final_ordered
}

///|
fn build_rank_groups(
  nodes : Array[@cgraph.Node],
  ranks : Map[String, Int],
) -> Map[Int, Array[String]] {
  let groups : Map[Int, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match groups.get(rank) {
      Some(list) => list.push(name)
      None => groups[rank] = [name]
    }
  }
  groups
}

///|
fn format_float(value : Double) -> String {
  let mut scaled = (value * 100.0).round().to_int()
  if scaled == 0 {
    return "0"
  }
  let mut sign = ""
  if scaled < 0 {
    sign = "-"
    scaled = -scaled
  }
  let int_part = scaled / 100
  let frac = scaled % 100
  if frac == 0 {
    return "\{sign}\{int_part}"
  }
  let frac_str = if frac < 10 { "0\{frac}" } else { "\{frac}" }
  "\{sign}\{int_part}.\{frac_str}"
}

///|
fn format_dim(value : Double) -> String {
  let rounded = (value * 100000.0).round() / 100000.0
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
fn format_point(point : @geom.Point) -> String {
  "\{format_float(point.x)},\{format_float(point.y)}"
}

///|
fn format_rect(rect : @geom.Rect) -> String {
  "\{format_float(rect.llx)},\{format_float(rect.lly)},\{format_float(rect.urx)},\{format_float(rect.ury)}"
}

///|
fn format_rects(rects : Array[@geom.Rect]) -> String {
  let parts : Array[String] = []
  for rect in rects {
    parts.push(format_rect(rect))
  }
  parts.join(" ")
}

///|
fn port_key(port : @cgraph.Port?) -> String {
  match port {
    None => ""
    Some(value) => {
      let mut out = ""
      match value.name {
        Some(name) => out = name
        None => ()
      }
      match value.compass {
        Some(compass) => {
          let label = match compass {
            @cgraph.Compass::N => "n"
            @cgraph.Compass::NE => "ne"
            @cgraph.Compass::E => "e"
            @cgraph.Compass::SE => "se"
            @cgraph.Compass::S => "s"
            @cgraph.Compass::SW => "sw"
            @cgraph.Compass::W => "w"
            @cgraph.Compass::NW => "nw"
            @cgraph.Compass::C => "c"
          }
          if out == "" {
            out = label
          } else {
            out = "\{out}:\{label}"
          }
        }
        None => ()
      }
      out
    }
  }
}

///|
fn edge_key(edge : @cgraph.Edge) -> String {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let name = match edge.name() {
    Some(value) => value
    None => ""
  }
  let tail_port = port_key(edge.tail_port())
  let head_port = port_key(edge.head_port())
  "\{tail}|\{head}|\{name}|\{tail_port}|\{head_port}"
}

///|
fn compute_bbox(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut bbox_set = false
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  for node in nodes {
    let half_w = node.width_in * 72.0 / 2.0
    let half_h = node.height_in * 72.0 / 2.0
    let left = node.pos.x - half_w
    let right = node.pos.x + half_w
    let bottom = node.pos.y - half_h
    let top = node.pos.y + half_h
    if !bbox_set {
      min_x = left
      max_x = right
      min_y = bottom
      max_y = top
      bbox_set = true
    } else {
      if left < min_x {
        min_x = left
      }
      if right > max_x {
        max_x = right
      }
      if bottom < min_y {
        min_y = bottom
      }
      if top > max_y {
        max_y = top
      }
    }
  }
  for edge in edges {
    for spline in edge.splines {
      match spline.start {
        Some(point) =>
          if !bbox_set {
            min_x = point.x
            max_x = point.x
            min_y = point.y
            max_y = point.y
            bbox_set = true
          } else {
            if point.x < min_x {
              min_x = point.x
            }
            if point.x > max_x {
              max_x = point.x
            }
            if point.y < min_y {
              min_y = point.y
            }
            if point.y > max_y {
              max_y = point.y
            }
          }
        None => ()
      }
      match spline.end {
        Some(point) =>
          if !bbox_set {
            min_x = point.x
            max_x = point.x
            min_y = point.y
            max_y = point.y
            bbox_set = true
          } else {
            if point.x < min_x {
              min_x = point.x
            }
            if point.x > max_x {
              max_x = point.x
            }
            if point.y < min_y {
              min_y = point.y
            }
            if point.y > max_y {
              max_y = point.y
            }
          }
        None => ()
      }
      for point in spline.points {
        if !bbox_set {
          min_x = point.x
          max_x = point.x
          min_y = point.y
          max_y = point.y
          bbox_set = true
        } else {
          if point.x < min_x {
            min_x = point.x
          }
          if point.x > max_x {
            max_x = point.x
          }
          if point.y < min_y {
            min_y = point.y
          }
          if point.y > max_y {
            max_y = point.y
          }
        }
      }
    }
  }
  if bbox_set {
    { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
  } else {
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
}

///|
fn merge_bbox(base : @geom.Rect, other : @geom.Rect) -> @geom.Rect {
  {
    llx: if base.llx < other.llx {
      base.llx
    } else {
      other.llx
    },
    lly: if base.lly < other.lly {
      base.lly
    } else {
      other.lly
    },
    urx: if base.urx > other.urx {
      base.urx
    } else {
      other.urx
    },
    ury: if base.ury > other.ury {
      base.ury
    } else {
      other.ury
    },
  }
}

///|
fn expand_bbox_with_subgraphs(
  bbox : @geom.Rect,
  subgraphs : Array[DotLayoutGraph],
) -> @geom.Rect {
  let mut result = bbox
  for subgraph in subgraphs {
    result = merge_bbox(result, subgraph.bbox)
    if subgraph.subgraphs.length() > 0 {
      result = expand_bbox_with_subgraphs(result, subgraph.subgraphs)
    }
  }
  result
}

///|
fn transform_point(
  point : @geom.Point,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point {
  match rankdir {
    RankDir::TB => point
    RankDir::BT => { x: point.x, y: bbox.lly + bbox.ury - point.y }
    RankDir::LR => { x: bbox.lly + bbox.ury - point.y, y: point.x }
    RankDir::RL => { x: point.y, y: bbox.llx + bbox.urx - point.x }
  }
}

///|
fn transform_optional_point(
  point : @geom.Point?,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point? {
  match point {
    Some(value) => Some(transform_point(value, bbox, rankdir))
    None => None
  }
}

///|
fn transform_spline(
  spline : @geom.Spline,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(transform_point(point, bbox, rankdir))
  }
  {
    start: transform_optional_point(spline.start, bbox, rankdir),
    end: transform_optional_point(spline.end, bbox, rankdir),
    points,
  }
}

///|
fn shift_point(point : @geom.Point, dx : Double, dy : Double) -> @geom.Point {
  { x: point.x + dx, y: point.y + dy }
}

///|
fn shift_optional_point(
  point : @geom.Point?,
  dx : Double,
  dy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(shift_point(value, dx, dy))
    None => None
  }
}

///|
fn shift_spline(
  spline : @geom.Spline,
  dx : Double,
  dy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(shift_point(point, dx, dy))
  }
  {
    start: shift_optional_point(spline.start, dx, dy),
    end: shift_optional_point(spline.end, dx, dy),
    points,
  }
}

///|
fn shift_layout_graph(
  layout : DotLayoutGraph,
  dx : Double,
  dy : Double,
) -> DotLayoutGraph {
  let shifted_nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    shifted_nodes.push({
      node: node_layout.node,
      pos: shift_point(node_layout.pos, dx, dy),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: shift_optional_point(node_layout.label_pos, dx, dy),
    })
  }
  let shifted_edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(shift_spline(spline, dx, dy))
    }
    shifted_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: shift_optional_point(edge_layout.label_pos, dx, dy),
      head_label_pos: shift_optional_point(edge_layout.head_label_pos, dx, dy),
      tail_label_pos: shift_optional_point(edge_layout.tail_label_pos, dx, dy),
    })
  }
  let shifted_subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    shifted_subgraphs.push(shift_layout_graph(subgraph, dx, dy))
  }
  let shifted_bbox : @geom.Rect = {
    llx: layout.bbox.llx + dx,
    lly: layout.bbox.lly + dy,
    urx: layout.bbox.urx + dx,
    ury: layout.bbox.ury + dy,
  }
  {
    graph: layout.graph,
    bbox: shifted_bbox,
    label_pos: shift_optional_point(layout.label_pos, dx, dy),
    nodes: shifted_nodes,
    edges: shifted_edges,
    subgraphs: shifted_subgraphs,
  }
}

///|
fn transform_layout(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> (Array[DotLayoutNode], Array[DotLayoutEdge], @geom.Rect) {
  let transformed_nodes : Array[DotLayoutNode] = []
  for node_layout in nodes {
    transformed_nodes.push({
      node: node_layout.node,
      pos: transform_point(node_layout.pos, bbox, rankdir),
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: transform_optional_point(node_layout.label_pos, bbox, rankdir),
    })
  }
  let transformed_edges : Array[DotLayoutEdge] = []
  for edge_layout in edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(transform_spline(spline, bbox, rankdir))
    }
    transformed_edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: transform_optional_point(edge_layout.label_pos, bbox, rankdir),
      head_label_pos: transform_optional_point(
        edge_layout.head_label_pos,
        bbox,
        rankdir,
      ),
      tail_label_pos: transform_optional_point(
        edge_layout.tail_label_pos,
        bbox,
        rankdir,
      ),
    })
  }
  let transformed_bbox = compute_bbox(transformed_nodes, transformed_edges)
  if transformed_bbox.llx == 0.0 && transformed_bbox.lly == 0.0 {
    (transformed_nodes, transformed_edges, transformed_bbox)
  } else {
    let dx = -transformed_bbox.llx
    let dy = -transformed_bbox.lly
    let shifted_nodes : Array[DotLayoutNode] = []
    for node_layout in transformed_nodes {
      shifted_nodes.push({
        node: node_layout.node,
        pos: shift_point(node_layout.pos, dx, dy),
        width_in: node_layout.width_in,
        height_in: node_layout.height_in,
        label_pos: shift_optional_point(node_layout.label_pos, dx, dy),
      })
    }
    let shifted_edges : Array[DotLayoutEdge] = []
    for edge_layout in transformed_edges {
      let splines : Array[@geom.Spline] = []
      for spline in edge_layout.splines {
        splines.push(shift_spline(spline, dx, dy))
      }
      shifted_edges.push({
        edge: edge_layout.edge,
        splines,
        label_pos: shift_optional_point(edge_layout.label_pos, dx, dy),
        head_label_pos: shift_optional_point(edge_layout.head_label_pos, dx, dy),
        tail_label_pos: shift_optional_point(edge_layout.tail_label_pos, dx, dy),
      })
    }
    let shifted_bbox = compute_bbox(shifted_nodes, shifted_edges)
    (shifted_nodes, shifted_edges, shifted_bbox)
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
fn graph_has_cluster(graph : @cgraph.Graph) -> Bool {
  for subgraph in graph.subgraphs() {
    if is_cluster_graph(subgraph) {
      return true
    }
    if graph_has_cluster(subgraph) {
      return true
    }
  }
  false
}

///|
priv enum LabelLoc {
  Top
  Bottom
}

///|
priv enum LabelJust {
  Left
  Center
  Right
}

///|
fn parse_label_loc(value : String?, default_loc : LabelLoc) -> LabelLoc {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "t" | "top" => LabelLoc::Top
        "b" | "bottom" => LabelLoc::Bottom
        _ => default_loc
      }
    }
    None => default_loc
  }
}

///|
fn parse_label_just(value : String?) -> LabelJust {
  match value {
    Some(text) => {
      let lower = text.to_lower()
      match lower {
        "l" | "left" => LabelJust::Left
        "r" | "right" => LabelJust::Right
        "c" | "center" => LabelJust::Center
        _ => LabelJust::Center
      }
    }
    None => LabelJust::Center
  }
}

///|
fn graph_label_loc(graph : @cgraph.Graph) -> LabelLoc {
  let default_loc = if graph.is_root() {
    LabelLoc::Bottom
  } else {
    LabelLoc::Top
  }
  parse_label_loc(graph.get_attr("labelloc"), default_loc)
}

///|
fn graph_label_just(graph : @cgraph.Graph) -> LabelJust {
  parse_label_just(graph.get_attr("labeljust"))
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (Double, Double)? {
  match graph.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(graph.get_attr("fontsize"))
        let font = @attrs.font_name(graph.get_attr("fontname"))
        let (width_pt, height_pt) = label_text_dimensions(
          value, font, font_size_pt,
        )
        Some((width_pt, height_pt))
      }
    None => None
  }
}

///|
fn graph_label_pos(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
  just : LabelJust,
) -> @geom.Point {
  let margin = 4.0
  let x = match just {
    LabelJust::Left => bbox.llx + margin + label_width_pt / 2.0
    LabelJust::Right => bbox.urx - margin - label_width_pt / 2.0
    LabelJust::Center => (bbox.llx + bbox.urx) / 2.0
  }
  let y = match loc {
    LabelLoc::Top => bbox.ury - margin - label_height_pt / 2.0
    LabelLoc::Bottom => bbox.lly + margin + label_height_pt / 2.0
  }
  { x, y }
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
fn rect_center(rect : @geom.Rect) -> @geom.Point {
  { x: (rect.llx + rect.urx) / 2.0, y: (rect.lly + rect.ury) / 2.0 }
}

///|
fn rect_from_center(
  center : @geom.Point,
  width : Double,
  height : Double,
  pad : Double,
) -> @geom.Rect {
  let half_w = width / 2.0 + pad
  let half_h = height / 2.0 + pad
  {
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  }
}

///|
priv struct EdgeLabelEntry {
  key : String
  pos : @geom.Point
  base_axis : Double
  half_axis : Double
}

///|
fn rect_overlap_amount(
  a : @geom.Rect,
  b : @geom.Rect,
) -> (Double, Double)? {
  let overlap_x = min_double(a.urx, b.urx) - max_double(a.llx, b.llx)
  let overlap_y = min_double(a.ury, b.ury) - max_double(a.lly, b.lly)
  if overlap_x > 0.0 && overlap_y > 0.0 {
    Some((overlap_x, overlap_y))
  } else {
    None
  }
}

///|
fn nudge_label_rect(
  label_pos : @geom.Point,
  label_rect : @geom.Rect,
  other_rect : @geom.Rect,
  label_width : Double,
  label_height : Double,
  pad : Double,
) -> (@geom.Point, @geom.Rect) {
  match rect_overlap_amount(label_rect, other_rect) {
    Some((overlap_x, overlap_y)) => {
      let other_center = rect_center(other_rect)
      if overlap_x < overlap_y {
        let dir = if label_pos.x < other_center.x { -1.0 } else { 1.0 }
        let shift = overlap_x + pad
        let new_pos : @geom.Point = {
          x: label_pos.x + dir * shift,
          y: label_pos.y,
        }
        (new_pos, rect_from_center(new_pos, label_width, label_height, pad))
      } else {
        let dir = if label_pos.y < other_center.y { -1.0 } else { 1.0 }
        let shift = overlap_y + pad
        let new_pos : @geom.Point = {
          x: label_pos.x,
          y: label_pos.y + dir * shift,
        }
        (new_pos, rect_from_center(new_pos, label_width, label_height, pad))
      }
    }
    None => (label_pos, label_rect)
  }
}

///|
fn edge_tail_point(edge_layout : DotLayoutEdge) -> @geom.Point? {
  match edge_layout.splines.get(0) {
    Some(spline) =>
      match spline.start {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 { Some(spline.points[0]) } else { None }
      }
    None => None
  }
}

///|
fn bezier_point(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let p01 = point_lerp(p0, p1, t)
  let p12 = point_lerp(p1, p2, t)
  let p23 = point_lerp(p2, p3, t)
  let p012 = point_lerp(p01, p12, t)
  let p123 = point_lerp(p12, p23, t)
  point_lerp(p012, p123, t)
}

///|
fn sample_spline_points(
  points : Array[@geom.Point],
  steps : Int,
) -> Array[@geom.Point] {
  let samples : Array[@geom.Point] = []
  if points.length() == 0 || steps <= 0 {
    return samples
  }
  samples.push(points[0])
  let mut index = 0
  let step_count = steps.to_double()
  while index + 3 < points.length() {
    let p0 = points[index]
    let p1 = points[index + 1]
    let p2 = points[index + 2]
    let p3 = points[index + 3]
    for step in 1..=steps {
      let t = step.to_double() / step_count
      samples.push(bezier_point(p0, p1, p2, p3, t))
    }
    index = index + 3
  }
  samples
}

///|
fn polyline_point_with_dir(
  points : Array[@geom.Point],
  target_len : Double,
) -> (@geom.Point, @geom.Point)? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some((points[0], point(1.0, 0.0)))
  }
  let mut remaining = target_len
  let mut last_dir = point(1.0, 0.0)
  let mut last_pos = points[points.length() - 1]
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = segment_length(a, b)
    if seg_len > 0.0 {
      let delta = point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      if len > 0.0 {
        last_dir = point_scale(delta, 1.0 / len)
        last_pos = b
      }
    }
    if seg_len <= 0.0 {
      continue
    }
    if remaining <= seg_len {
      let t = remaining / seg_len
      let pos = point_lerp(a, b, t)
      let delta = point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let dir =
        if len <= 0.0 { point(1.0, 0.0) } else { point_scale(delta, 1.0 / len) }
      return Some((pos, dir))
    }
    remaining = remaining - seg_len
  }
  Some((last_pos, last_dir))
}

///|
fn polyline_point_at_axis(
  points : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> (@geom.Point, @geom.Point)? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some((points[0], point(1.0, 0.0)))
  }
  let total_len = polyline_length(points)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  let epsilon = 0.000001
  let mut traveled = 0.0
  let mut best_pos : @geom.Point? = None
  let mut best_dir : @geom.Point? = None
  let mut best_dist = 0.0
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = segment_length(a, b)
    let a_axis = if axis_is_x { a.x } else { a.y }
    let b_axis = if axis_is_x { b.x } else { b.y }
    let min_axis = if a_axis < b_axis { a_axis } else { b_axis }
    let max_axis = if a_axis < b_axis { b_axis } else { a_axis }
    if axis_value < min_axis || axis_value > max_axis {
      traveled = traveled + seg_len
      continue
    }
    let delta_axis = b_axis - a_axis
    let t =
      if Double::abs(delta_axis) <= epsilon {
        0.5
      } else {
        (axis_value - a_axis) / delta_axis
      }
    let pos = point_lerp(a, b, t)
    let delta = point_sub(b, a)
    let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
    let dir =
      if len <= 0.0 { point(1.0, 0.0) } else { point_scale(delta, 1.0 / len) }
    let cross_len = traveled + seg_len * t
    let dist = Double::abs(cross_len - target)
    if best_pos is None || dist < best_dist {
      best_pos = Some(pos)
      best_dir = Some(dir)
      best_dist = dist
    }
    traveled = traveled + seg_len
  }
  match best_pos {
    Some(pos) =>
      match best_dir {
        Some(dir) => Some((pos, dir))
        None => None
      }
    None => None
  }
}

///|
fn spline_label_pos_with_dir(
  spline : @geom.Spline,
) -> (@geom.Point, @geom.Point)? {
  let points = spline.points
  if points.length() == 0 {
    return None
  }
  let samples = sample_spline_points(points, 96)
  if samples.length() == 0 {
    return None
  }
  let total_len = polyline_length(samples)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  polyline_point_with_dir(samples, target)
}

///|
fn spline_label_pos_at_axis(
  spline : @geom.Spline,
  axis_value : Double,
  axis_is_x : Bool,
) -> (@geom.Point, @geom.Point)? {
  let points = spline.points
  if points.length() == 0 {
    return None
  }
  let samples = sample_spline_points(points, 48)
  if samples.length() == 0 {
    return None
  }
  polyline_point_at_axis(samples, axis_value, axis_is_x)
}

///|
fn edge_label_rank_info(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> (Int, Int)? {
  if edge_mid_label_width_pt(edge) <= 0.0 {
    return None
  }
  let tail_rank = match ranks.get(edge.tail().name()) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(edge.head().name()) {
    Some(value) => value
    None => return None
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  let span = max_rank - min_rank
  if span <= 1 {
    return None
  }
  let label_rank = (min_rank + max_rank) / 2
  Some((label_rank, span))
}

///|
fn edge_label_rank_y(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
) -> Double? {
  match edge_label_rank_info(edge, ranks) {
    Some((label_rank, _span)) => rank_y.get(label_rank)
    None => None
  }
}

///|
fn edge_label_rank_x(
  edge : @cgraph.Edge,
  label_rank : Int,
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
) -> Double? {
  match edge_vnodes.get(edge_key(edge)) {
    Some(vnodes) =>
      for name in vnodes {
        match vnode_ranks.get(name) {
          Some(rank) =>
            if rank == label_rank {
              match vnode_positions.get(name) {
                Some(pos) => return Some(pos.x)
                None => ()
              }
            }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
fn edge_label_pos(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  rankdir : RankDir,
  label_rank_y : Double?,
  label_rank_x : Double?,
  apply_label_pad : Bool,
  nodesep_pt : Double,
  label_pad_boost : Double,
) -> @geom.Point? {
  let fallback = match spline_label_pos_with_dir(spline) {
    Some((pos, tangent)) => (pos, tangent)
    None => {
      let mid = point(
        (tail_clip.x + head_clip.x) / 2.0,
        (tail_clip.y + head_clip.y) / 2.0,
      )
      let delta = point_sub(head_clip, tail_clip)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let tangent =
        if len <= 0.0 { point(1.0, 0.0) } else { point_scale(delta, 1.0 / len) }
      (mid, tangent)
    }
  }
  let (raw_pos, dir) = match label_rank_y {
    Some(axis) =>
      match spline_label_pos_at_axis(spline, axis, false) {
        Some((pos, tangent)) => (pos, tangent)
        None => fallback
      }
    None => fallback
  }
  let base_pos =
    match label_rank_x {
      Some(value) =>
        match rankdir {
          RankDir::LR | RankDir::RL => point(raw_pos.x, value)
          _ => point(value, raw_pos.y)
        }
      None => raw_pos
    }
  if edge.tail().name() == edge.head().name() {
    return Some(base_pos)
  }
  match label_rank_y {
    Some(_) =>
      match edge_mid_label_metrics(edge) {
        Some((width, height)) => {
          let mut pad = label_pad_boost
          if apply_label_pad {
            pad = pad + nodesep_pt * 0.22
          } else if label_rank_x is None && width >= EDGE_LABEL_PAD_WIDTH_PT {
            pad = pad + nodesep_pt * 0.22
          }
          let half_extent = match rankdir {
            RankDir::LR | RankDir::RL => height / 2.0
            _ => width / 2.0
          }
          let sign = match rankdir {
            RankDir::RL => -1.0
            _ => 1.0
          }
          Some(point(base_pos.x + sign * (half_extent + pad), base_pos.y))
        }
        None => Some(base_pos)
      }
    None => {
      let (width, height) = match edge_mid_label_metrics(edge) {
        Some((w, h)) => (w, h)
        None => return Some(base_pos)
      }
      let normal = point(-dir.y, dir.x)
      let axis_threshold = 0.1
      let abs_dx = Double::abs(dir.x)
      let abs_dy = Double::abs(dir.y)
      if spline.points.length() > 4 &&
        abs_dx > axis_threshold &&
        abs_dy > axis_threshold {
        return Some(base_pos)
      }
      let offset =
        if abs_dx <= axis_threshold {
          width / 2.0
        } else if abs_dy <= axis_threshold {
          height / 2.0
        } else {
          0.0
        }
      if offset <= 0.0 {
        Some(base_pos)
      } else {
        let pad = label_pad_boost
        Some(point_add(base_pos, point_scale(normal, offset + pad)))
      }
    }
  }
}

///|
fn collect_cluster_label_rects(
  graphs : Array[DotLayoutGraph],
  pad : Double,
) -> Array[@geom.Rect] {
  let rects : Array[@geom.Rect] = []
  for subgraph in graphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some((width, height)) => rects.push(rect_from_center(pos, width, height, pad))
          None => ()
        }
      None => ()
    }
    let nested = collect_cluster_label_rects(subgraph.subgraphs, pad)
    for rect in nested {
      rects.push(rect)
    }
  }
  rects
}

///|
fn adjust_edge_label_positions(
  edges : Array[DotLayoutEdge],
  label_rects : Array[@geom.Rect],
  pad : Double,
) -> (Array[DotLayoutEdge], Map[String, @geom.Point]) {
  let adjusted : Array[DotLayoutEdge] = []
  let updates : Map[String, @geom.Point] = Map::new()
  for edge_layout in edges {
    let mut label_pos = edge_layout.label_pos
    match label_pos {
      Some(pos) =>
        match edge_mid_label_metrics(edge_layout.edge) {
          Some((width, height)) => {
            let mut current_pos = pos
            let mut current_rect = rect_from_center(current_pos, width, height, pad)
            for rect in label_rects {
              let (next_pos, next_rect) = nudge_label_rect(
                current_pos,
                current_rect,
                rect,
                width,
                height,
                pad,
              )
              current_pos = next_pos
              current_rect = next_rect
            }
            label_pos = Some(current_pos)
          }
          None => ()
        }
      None => ()
    }
    match label_pos {
      Some(pos) => updates[edge_key(edge_layout.edge)] = pos
      None => ()
    }
    adjusted.push({
      edge: edge_layout.edge,
      splines: edge_layout.splines,
      label_pos,
      head_label_pos: edge_layout.head_label_pos,
      tail_label_pos: edge_layout.tail_label_pos,
    })
  }
  (adjusted, updates)
}

///|
fn apply_edge_label_updates(
  graphs : Array[DotLayoutGraph],
  updates : Map[String, @geom.Point],
) -> Array[DotLayoutGraph] {
  let updated : Array[DotLayoutGraph] = []
  for graph in graphs {
    let edges : Array[DotLayoutEdge] = []
    for edge_layout in graph.edges {
      let label_pos = match updates.get(edge_key(edge_layout.edge)) {
        Some(pos) => Some(pos)
        None => edge_layout.label_pos
      }
      edges.push({
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos,
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
      })
    }
    let subgraphs = apply_edge_label_updates(graph.subgraphs, updates)
    updated.push({
      graph: graph.graph,
      bbox: graph.bbox,
      label_pos: graph.label_pos,
      nodes: graph.nodes,
      edges,
      subgraphs,
    })
  }
  updated
}

///|
fn adjust_edge_labels_for_cluster_labels(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
) -> DotLayoutGraph {
  let pad = if nodesep_pt * 0.2 < 2.0 { 2.0 } else { nodesep_pt * 0.2 }
  let label_rects : Array[@geom.Rect] = []
  match layout.label_pos {
    Some(pos) =>
      match graph_label_metrics(layout.graph) {
        Some((width, height)) =>
          label_rects.push(rect_from_center(pos, width, height, pad))
        None => ()
      }
    None => ()
  }
  let subgraph_rects = collect_cluster_label_rects(layout.subgraphs, pad)
  for rect in subgraph_rects {
    label_rects.push(rect)
  }
  if label_rects.length() == 0 {
    layout
  } else {
    let (edges, updates) = adjust_edge_label_positions(
      layout.edges,
      label_rects,
      pad,
    )
    let subgraphs = apply_edge_label_updates(layout.subgraphs, updates)
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges,
      subgraphs,
    }
  }
}

///|
fn adjust_edge_labels_for_label_overlaps(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  let axis_is_x = match rankdir {
    RankDir::TB | RankDir::BT => true
    RankDir::LR | RankDir::RL => false
  }
  let tail_pad = max_double(2.0, nodesep_pt * 0.3)
  let gap = max_double(4.0, nodesep_pt * 0.8)
  let groups : Map[String, Array[EdgeLabelEntry]] = Map::new()
  for edge_layout in layout.edges {
    match edge_layout.label_pos {
      Some(pos) =>
        match edge_mid_label_metrics(edge_layout.edge) {
          Some((width, height)) => {
            let pos_axis = if axis_is_x { pos.x } else { pos.y }
            let tail_axis = match edge_tail_point(edge_layout) {
              Some(point) => if axis_is_x { point.x } else { point.y }
              None => pos_axis
            }
            let base_axis =
              if tail_axis + tail_pad > pos_axis { tail_axis + tail_pad } else { pos_axis }
            let half_axis = if axis_is_x { width / 2.0 } else { height / 2.0 }
            let entry = {
              key: edge_key(edge_layout.edge),
              pos,
              base_axis,
              half_axis,
            }
            let tail_name = edge_layout.edge.tail().name()
            let list = match groups.get(tail_name) {
              Some(value) => value
              None => []
            }
            list.push(entry)
            groups[tail_name] = list
          }
          None => ()
        }
      None => ()
    }
  }
  let updates : Map[String, @geom.Point] = Map::new()
  for _, entries in groups {
    if entries.length() < 2 {
      continue
    }
    entries.sort_by((a, b) => Double::compare(a.base_axis, b.base_axis))
    let mut last_axis = 0.0
    let mut last_half = 0.0
    let mut first = true
    for entry in entries {
      let mut axis_value = entry.base_axis
      if !first {
        let min_axis = last_axis + last_half + entry.half_axis + gap
        if axis_value < min_axis {
          axis_value = min_axis
        }
      }
      let new_pos : @geom.Point =
        if axis_is_x {
        { x: axis_value, y: entry.pos.y }
      } else {
        { x: entry.pos.x, y: axis_value }
      }
      if new_pos.x != entry.pos.x || new_pos.y != entry.pos.y {
        updates[entry.key] = new_pos
      }
      last_axis = axis_value
      last_half = entry.half_axis
      first = false
    }
  }
  if updates.length() == 0 {
    layout
  } else {
    let edges : Array[DotLayoutEdge] = []
    for edge_layout in layout.edges {
      let label_pos = match updates.get(edge_key(edge_layout.edge)) {
        Some(pos) => Some(pos)
        None => edge_layout.label_pos
      }
      edges.push({
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos,
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
      })
    }
    let subgraphs = apply_edge_label_updates(layout.subgraphs, updates)
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges,
      subgraphs,
    }
  }
}

///|
fn expand_bbox_for_label(
  bbox : @geom.Rect,
  label_width_pt : Double,
  label_height_pt : Double,
  loc : LabelLoc,
) -> @geom.Rect {
  let pad = 8.0
  let mut llx = bbox.llx
  let mut lly = bbox.lly
  let mut urx = bbox.urx
  let mut ury = bbox.ury
  match loc {
    LabelLoc::Top => ury = ury + label_height_pt + pad
    LabelLoc::Bottom => lly = lly - label_height_pt - pad
  }
  let label_width = label_width_pt + pad * 2.0
  let current_width = urx - llx
  if label_width > current_width {
    let extra = label_width - current_width
    llx = llx - extra / 2.0
    urx = urx + extra / 2.0
  }
  { llx, lly, urx, ury }
}

///|
fn layout_subgraphs(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
) -> Array[DotLayoutGraph] {
  let result : Array[DotLayoutGraph] = []
  for subgraph in graph.subgraphs() {
    let node_set : Map[String, Bool] = Map::new()
    for node in subgraph.nodes() {
      node_set[node.name()] = true
    }
    let edge_set : Map[String, Bool] = Map::new()
    for edge in subgraph.edges() {
      edge_set[edge_key(edge)] = true
    }
    let sub_nodes : Array[DotLayoutNode] = []
    for node_layout in nodes_out {
      if node_set.get(node_layout.node.name()) is Some(_) {
        sub_nodes.push(node_layout)
      }
    }
    let sub_edges : Array[DotLayoutEdge] = []
    for edge_layout in edges_out {
      if edge_set.get(edge_key(edge_layout.edge)) is Some(_) {
        let tail_name = edge_layout.edge.tail().name()
        let head_name = edge_layout.edge.head().name()
        if node_set.get(tail_name) is Some(_) &&
          node_set.get(head_name) is Some(_) {
          sub_edges.push(edge_layout)
        }
      }
    }
    let mut bbox = compute_bbox(sub_nodes, sub_edges)
    let mut label_pos : @geom.Point? = None
    let mut label_info : (Double, Double, LabelLoc, LabelJust)? = None
    let sub_subgraphs = layout_subgraphs(subgraph, nodes_out, edges_out)
    if sub_subgraphs.length() > 0 {
      bbox = expand_bbox_with_subgraphs(bbox, sub_subgraphs)
    }
    if is_cluster_graph(subgraph) {
      let pad = cluster_margin_pt(subgraph)
      let llx = bbox.llx - pad
      let lly = bbox.lly - pad
      let urx = bbox.urx + pad
      let ury = bbox.ury + pad
      bbox = { llx, lly, urx, ury }
      match graph_label_metrics(subgraph) {
        Some((width_pt, height_pt)) => {
          let loc = graph_label_loc(subgraph)
          let just = graph_label_just(subgraph)
          bbox = expand_bbox_for_label(bbox, width_pt, height_pt, loc)
          label_info = Some((width_pt, height_pt, loc, just))
        }
        None => ()
      }
    }
    match label_info {
      Some((width_pt, height_pt, loc, just)) =>
        label_pos = Some(graph_label_pos(bbox, width_pt, height_pt, loc, just))
      None => ()
    }
    result.push({
      graph: subgraph,
      bbox,
      label_pos,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
}

///|

///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  { rankdir: None, nodesep: None, ranksep: None, splines: None }
}

///|
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  let rankdir = match opts.rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
  let nodesep_in = match opts.nodesep {
    Some(value) => value
    None =>
      match graph.get_attr("nodesep") {
        Some(value) => parse_first_double(value, default_nodesep_in())
        None => default_nodesep_in()
      }
  }
  let ranksep_in = match opts.ranksep {
    Some(value) => value
    None =>
      match graph.get_attr("ranksep") {
        Some(value) => parse_first_double(value, default_ranksep_in())
        None => default_ranksep_in()
      }
  }
  let splines = match opts.splines {
    Some(value) => value
    None =>
      match graph.get_attr("splines") {
        Some(value) =>
          match parse_splines(value) {
            Some(parsed) => parsed
            None => SplinesMode::Spline
          }
        None => SplinesMode::Spline
      }
  }
  let _ = splines
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  let has_edge_labels = graph_has_edge_labels(edges)
  let node_order : Map[String, Int] = Map::new()
  for i in 0..<nodes.length() {
    node_order[nodes[i].name()] = i
  }
  let sizes : Map[String, NodeSize] = Map::new()
  let record_orientation = record_layout_orientation(rankdir)
  for node in nodes {
    sizes[node.name()] = node_size(node, record_orientation)
  }
  let ranks = if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(graph, nodes, edges, has_edge_labels)
  } else {
    let base : Map[String, Int] = Map::new()
    for node in nodes {
      base[node.name()] = 0
    }
    base
  }
  let groups = build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  let self_edge_labels = self_edge_label_half_heights(edges)
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height = node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
  if has_edge_labels {
    for edge in edges {
      if !edge_has_label(edge) {
        continue
      }
      let tail = edge.tail().name()
      let head = edge.head().name()
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => continue
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => continue
      }
      let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
      let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
      if max_rank - min_rank <= 1 {
        continue
      }
      let label_rank = (min_rank + max_rank) / 2
      let half_height = edge_label_height_pt(edge) / 2.0
      let current = match rank_pht.get(label_rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[label_rank] = half_height
      }
    }
  }
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  let _ = apply_cluster_rank_heights(
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
  )
  let nodesep_pt = nodesep_in * 72.0
  let has_clusters = graph_has_cluster(graph)
  let mut ranksep_pt = ranksep_in * 72.0
  if has_edge_labels {
    ranksep_pt = (ranksep_pt + 1.0) / 2.0
  }
  let y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  if all_ranks.length() > 0 {
    let max_rank = all_ranks[all_ranks.length() - 1]
    let start_y = match rank_ht1.get(max_rank) {
      Some(value) => value
      None => 0.0
    }
    rank_y[max_rank] = start_y
    let mut idx = all_ranks.length() - 1
    while idx > 0 {
      let upper = all_ranks[idx]
      let lower = all_ranks[idx - 1]
      let upper_pht = match rank_pht.get(upper) {
        Some(value) => value
        None => 0.0
      }
      let lower_pht = match rank_pht.get(lower) {
        Some(value) => value
        None => 0.0
      }
      let upper_ht2 = match rank_ht2.get(upper) {
        Some(value) => value
        None => 0.0
      }
      let lower_ht1 = match rank_ht1.get(lower) {
        Some(value) => value
        None => 0.0
      }
      let d0 = upper_pht + lower_pht + ranksep_pt
      let d1 = upper_ht2 + lower_ht1 + CLUSTER_MARGIN_PT
      let delta = if d0 > d1 { d0 } else { d1 }
      let base_y = match rank_y.get(upper) {
        Some(value) => value
        None => 0.0
      }
      rank_y[lower] = base_y + delta
      idx = idx - 1
    }
    for rank in rank_keys {
      let names = match groups.get(rank) {
        Some(list) => list
        None => []
      }
      let pos_y = match rank_y.get(rank) {
        Some(value) => value
        None => 0.0
      }
      for name in names {
        y_positions[name] = pos_y
      }
    }
  }
  let ordering = match graph.get_attr("ordering") {
    Some(value) => parse_ordering(value)
    None => None
  }
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = node_cluster_key(node)
  }
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    intercluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  let edge_order = collect_edge_order(edges)
  let ordered_groups = match ordering {
    Some(_) => groups
    None => {
      let (parents, children) = build_edge_index(nodes, edges)
      reorder_rank_groups(
        rank_keys, groups, edges, parents, children, cluster_keys, rank_same_groups,
        rank_same_order,
        edge_order,
        node_order,
        sizes,
        nodesep_pt,
        has_edge_labels,
      )
    }
  }
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    edges,
    ranks,
    nodesep_pt,
    existing_names,
    edge_cluster_keys,
  )
  let node_singletons = build_node_singletons(nodes, edges)
  let virtual_slack_edges = build_virtual_slack_edges(
    edges,
    ranks,
    vnode_info.edge_vnodes,
    vnode_info.vnode_ranks,
    node_singletons,
    cluster_keys,
  )
  let order_index = build_order_index(ordered_groups)
  let vnode_order_keys = build_vnode_order_keys(
    edges,
    ranks,
    order_index,
    vnode_info.edge_vnodes,
    vnode_info.vnode_ranks,
  )
  let x_sizes = merge_sizes_with_vnodes(sizes, vnode_info.vnode_sizes)
  let x_groups = build_x_groups_with_vnodes(
    ordered_groups,
    order_index,
    vnode_info.vnodes_by_rank,
    vnode_order_keys,
  )
  let x_rank_keys = collect_rank_keys(x_groups)
  let x_ranks = build_node_ranks(x_groups)
  let vnode_extra_nodes = build_vnode_extra_nodes(vnode_info.vnode_ranks)
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_keys {
    x_cluster_keys[name] = key
  }
  for name, key in vnode_info.vnode_clusters {
    x_cluster_keys[name] = key
  }
  let x_positions = compute_x_positions(
    graph,
    nodes,
    edges,
    x_ranks,
    x_rank_keys,
    x_groups,
    x_sizes,
    x_cluster_keys,
    nodesep_pt,
    ordering,
    has_edge_labels,
    vnode_extra_nodes,
    vnode_info.edge_vnodes,
    virtual_slack_edges,
  )
  adjust_intercluster_alignment(
    nodes,
    edges,
    ranks,
    x_positions,
    cluster_keys,
    intercluster_keys,
    nodesep_pt,
    has_edge_labels,
  )
  let vnode_names : Array[String] = []
  for pair in vnode_extra_nodes {
    let (name, _rank) = pair
    vnode_names.push(name)
  }
  normalize_x_positions(nodes, vnode_names, x_positions, x_sizes)
  let vnode_positions : Map[String, @geom.Point] = Map::new()
  for name, rank in vnode_info.vnode_ranks {
    let pos_x = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = match rank_y.get(rank) {
      Some(value) => value
      None => 0.0
    }
    vnode_positions[name] = { x: pos_x, y: pos_y }
  }
  let positions : Map[String, @geom.Point] = Map::new()
  for node in nodes {
    let name = node.name()
    let pos_x = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = match y_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    positions[name] = { x: pos_x, y: pos_y }
  }
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = match sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
    })
  }
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  for node_layout in nodes_out {
    let size = node_size_from_points(
      node_layout.width_in * 72.0,
      node_layout.height_in * 72.0,
    )
    if is_record_shape(node_layout.node) {
      let ports = record_ports(
        node_layout.node,
        node_layout.pos,
        size,
        record_orientation,
      )
      label_ports_map[node_layout.node.name()] = ports
    } else {
      match @html_label.parse_html_label(label_text(node_layout.node)) {
        Some(@html_label.HtmlLabel::Table(_)) => {
          let ports = html_ports(node_layout.node, node_layout.pos, size)
          label_ports_map[node_layout.node.name()] = ports
        }
        _ => ()
      }
    }
  }
  let mut has_dotted_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
          break
        }
      None => ()
    }
  }
  let label_edge_counts : Map[String, Int] = Map::new()
  for edge in edges {
    if edge_mid_label_text(edge) is Some(_) {
      let tail = edge.tail().name()
      let current = match label_edge_counts.get(tail) {
        Some(value) => value
        None => 0
      }
      label_edge_counts[tail] = current + 1
    }
  }
  let enable_complex_tuning = has_clusters && has_dotted_edges
  let (port_pad_below, port_pad_above) =
    if has_clusters {
    (0.0, 0.0)
  } else {
    record_port_padding_y(edges, positions, label_ports_map)
  }
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if enable_complex_tuning {
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      let head_port = port_key(edge.head_port())
      let key =
        if head_port == "" {
        if is_record_shape(edge.head()) { head_name } else { "" }
      } else {
        "\{head_name}:\{head_port}"
      }
      if key == "" {
        continue
      }
      let tail_pos = match positions.get(tail_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let head_pos = match positions.get(head_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let tail_size = match sizes.get(tail_name) {
        Some(value) => value
        None => node_size(edge.tail(), record_orientation)
      }
      let head_size = match sizes.get(head_name) {
        Some(value) => value
        None => node_size(edge.head(), record_orientation)
      }
      let (raw_tail_anchor, raw_tail_anchor_size) = port_geometry(
        tail_name,
        edge.tail_port(),
        label_ports_map,
        tail_pos,
        tail_size,
      )
      let (raw_head_anchor, raw_head_anchor_size) = port_geometry(
        head_name,
        edge.head_port(),
        label_ports_map,
        head_pos,
        head_size,
      )
      let mut tail_anchor = raw_tail_anchor
      let mut tail_anchor_size = raw_tail_anchor_size
      let mut head_anchor = raw_head_anchor
      let mut head_anchor_size = raw_head_anchor_size
      if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
        let (anchor, size) = record_port_boundary_anchor(
          tail_anchor,
          tail_anchor_size,
          tail_pos,
          tail_size,
          head_anchor,
        )
        tail_anchor = anchor
        tail_anchor_size = size
      }
      if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
        let (anchor, size) = record_port_boundary_anchor(
          head_anchor,
          head_anchor_size,
          head_pos,
          head_size,
          tail_anchor,
        )
        head_anchor = anchor
        head_anchor_size = size
      }
      let dx = head_anchor.x - tail_anchor.x
      let dy = head_anchor.y - tail_anchor.y
      let dist = Double::sqrt(dx * dx + dy * dy)
      let current = match head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      head_port_counts[key] = current + 1
      let mut min_dist = match head_port_min_dist.get(key) {
        Some(value) => value
        None => dist
      }
      let mut max_dist = match head_port_max_dist.get(key) {
        Some(value) => value
        None => dist
      }
      if dist < min_dist {
        min_dist = dist
      }
      if dist > max_dist {
        max_dist = dist
      }
      head_port_min_dist[key] = min_dist
      head_port_max_dist[key] = max_dist
    }
  }
  let edges_out : Array[DotLayoutEdge] = []
  for edge in edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let tail_pos = match positions.get(tail_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions.get(head_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let tail_size = match sizes.get(tail_name) {
      Some(value) => value
      None => node_size(edge.tail(), record_orientation)
    }
    let head_size = match sizes.get(head_name) {
      Some(value) => value
      None => node_size(edge.head(), record_orientation)
    }
    let (raw_tail_anchor, raw_tail_anchor_size) = port_geometry(
      tail_name,
      edge.tail_port(),
      label_ports_map,
      tail_pos,
      tail_size,
    )
    let (raw_head_anchor, raw_head_anchor_size) = port_geometry(
      head_name,
      edge.head_port(),
      label_ports_map,
      head_pos,
      head_size,
    )
    let mut tail_anchor = raw_tail_anchor
    let mut tail_anchor_size = raw_tail_anchor_size
    let mut head_anchor = raw_head_anchor
    let mut head_anchor_size = raw_head_anchor_size
    if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
      let (anchor, size) = record_port_boundary_anchor(
        tail_anchor,
        tail_anchor_size,
        tail_pos,
        tail_size,
        head_anchor,
      )
      tail_anchor = anchor
      tail_anchor_size = size
    }
    if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
      let (anchor, size) = record_port_boundary_anchor(
        head_anchor,
        head_anchor_size,
        head_pos,
        head_size,
        tail_anchor,
      )
      head_anchor = anchor
      head_anchor_size = size
    }
    let mut tail_clip = clip_to_rect(tail_anchor, tail_anchor_size, head_anchor)
    let mut head_clip = clip_to_rect(head_anchor, head_anchor_size, tail_anchor)
    let dir = edge_dir_for(edge, graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
      _ => false
    }
    let mut label_pad_boost = 0.0
    let spline = match splines {
      SplinesMode::Polyline =>
        edge_spline_for_polyline(
          edge, tail_clip, head_clip, rankdir, false, include_tail, include_head,
        )
      SplinesMode::Ortho =>
        edge_spline_for_polyline(
          edge, tail_clip, head_clip, rankdir, true, include_tail, include_head,
        )
      _ => {
        let label_width_pt = edge_mid_label_width_pt(edge)
        let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
        let same_outer_cluster =
          node_cluster_key(edge.tail()) == node_cluster_key(edge.head())
        let diff_local_cluster =
          node_local_cluster_key(edge.tail()) != node_local_cluster_key(edge.head())
        let split_label = enable_complex_tuning &&
          label_width_pt > 0.0 &&
          same_outer_cluster &&
          diff_local_cluster &&
          abs_dx > label_width_pt
        if split_label {
          label_pad_boost = nodesep_pt * 1.2
        }
        let dotted_weight = if enable_complex_tuning { 1.0 } else { 0.8 }
        let mut points = edge_polyline_points(
          edge,
          tail_anchor,
          head_anchor,
          ranks,
          vnode_info.edge_vnodes,
          vnode_info.vnode_ranks,
          vnode_positions,
          nodesep_pt,
          label_width_pt,
          dotted_weight,
          enable_complex_tuning,
          split_label,
        )
        let style_value = if enable_complex_tuning {
          match edge.get_attr("style") {
            Some(value) => value.to_lower()
            None => ""
          }
        } else {
          ""
        }
        let is_dotted = enable_complex_tuning && style_value.contains("dotted")
        if is_dotted && !same_outer_cluster {
          points = adjust_intercluster_dotted_points(
            points,
            tail_anchor,
            head_anchor,
            head_anchor_size,
            nodesep_pt,
          )
        }
        let has_vnodes = match vnode_info.edge_vnodes.get(edge_key(edge)) {
          Some(list) => list.length() > 0
          None => false
        }
        let curve_offset_for = () => {
          let mut curve_offset = 0.0
          let mut curve_skew = 1.0
          if enable_complex_tuning {
            let head_port = port_key(edge.head_port())
            let key =
              if head_port == "" {
              if is_record_shape(edge.head()) { head_name } else { "" }
            } else {
              "\{head_name}:\{head_port}"
            }
            if key != "" {
              let count = match head_port_counts.get(key) {
                Some(value) => value
                None => 0
              }
              if count > 1 {
                let dx = head_anchor.x - tail_anchor.x
                let dy = head_anchor.y - tail_anchor.y
                let dist = Double::sqrt(dx * dx + dy * dy)
                let min_dist = match head_port_min_dist.get(key) {
                  Some(value) => value
                  None => dist
                }
                let max_dist = match head_port_max_dist.get(key) {
                  Some(value) => value
                  None => dist
                }
                let span = max_dist - min_dist
                if span > 0.0 {
                  let t = (dist - min_dist) / span
                  let label_factor = if label_width_pt > 0.0 { 1.0 } else { 0.5 }
                  let port_scale = if head_port == "" { 0.6 } else { 2.4 }
                  curve_offset = nodesep_pt * t * t * label_factor * port_scale
                  if head_port != "" {
                    match rankdir {
                      RankDir::TB | RankDir::BT =>
                        if dx < 0.0 {
                          curve_skew = 0.5
                        }
                      RankDir::LR | RankDir::RL =>
                        if dy < 0.0 {
                          curve_skew = 0.5
                        }
                    }
                  }
                }
              }
            }
          }
          (curve_offset, curve_skew)
        }
        let (curve_offset, curve_skew) = curve_offset_for()
        if points.length() > 2 {
          let clipped = clip_polyline_ends(
            points, tail_anchor, head_anchor, tail_anchor_size, head_anchor_size,
          )
          let simplify_tol = nodesep_pt * 0.8
          let tail_label_edges = match label_edge_counts.get(tail_name) {
            Some(value) => value > 1
            None => false
          }
          let has_explicit_port =
            port_is_explicit(edge.tail_port()) || port_is_explicit(edge.head_port())
          let keep_label_kink =
            label_width_pt > 0.0 &&
            (has_explicit_port ||
              (same_outer_cluster &&
                (abs_dx < nodesep_pt || (tail_label_edges && abs_dx < label_width_pt))))
          let simplified =
            if enable_complex_tuning && has_vnodes && !split_label && !keep_label_kink {
              simplify_polyline(clipped, simplify_tol)
            } else {
              clipped
            }
          let adjusted =
            if is_dotted && same_outer_cluster {
            adjust_intracluster_dotted_points(simplified)
          } else {
            simplified
          }
          tail_clip = adjusted[0]
          head_clip = adjusted[adjusted.length() - 1]
          if adjusted.length() <= 2 {
            edge_spline_for_line(
              edge,
              tail_anchor,
              head_anchor,
              tail_anchor_size,
              head_anchor_size,
              include_tail,
              include_head,
              rankdir,
              curve_offset,
              curve_skew,
            )
          } else {
            let spline = edge_spline_for_points(edge, adjusted, include_tail, include_head)
            if is_dotted && !same_outer_cluster && spline.points.length() > 1 {
              let tuned = spline.points.copy()
              let tail_bias = 0.7
              tuned[1] = {
                x: tuned[1].x,
                y: tuned[1].y * (1.0 - tail_bias) + tail_anchor.y * tail_bias,
              }
              { start: spline.start, end: spline.end, points: tuned }
            } else {
              spline
            }
          }
        } else {
          edge_spline_for_line(
            edge,
            tail_anchor,
            head_anchor,
            tail_anchor_size,
            head_anchor_size,
            include_tail,
            include_head,
            rankdir,
            curve_offset,
            curve_skew,
          )
        }
      }
    }
    let label_rank_info = edge_label_rank_info(edge, ranks)
    let label_rank_y = edge_label_rank_y(edge, ranks, rank_y)
    let label_rank_x = match label_rank_info {
      Some((label_rank, span)) =>
        if span > 2 {
          let base = edge_label_rank_x(
            edge,
            label_rank,
            vnode_info.vnode_ranks,
            vnode_info.edge_vnodes,
            vnode_positions,
          )
          match base {
            Some(value) =>
              if has_clusters {
              Some(value)
            } else {
              Some(value - nodesep_pt * 0.1)
            }
            None => None
          }
        } else {
          None
        }
      None => None
    }
    let apply_label_pad = has_clusters
    let label_pos : @geom.Point? = match edge.get_attr("label") {
      Some(value) =>
        if value == "" {
          None
        } else {
          edge_label_pos(
            edge,
            spline,
            tail_clip,
            head_clip,
            rankdir,
            label_rank_y,
            label_rank_x,
            apply_label_pad,
            nodesep_pt,
            label_pad_boost,
          )
        }
      None => None
    }
    let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
      Some(value) => if value == "" { None } else { Some(head_clip) }
      None => None
    }
    let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
      Some(value) => if value == "" { None } else { Some(tail_clip) }
      None => None
    }
    edges_out.push({
      edge,
      splines: [spline],
      label_pos,
      head_label_pos,
      tail_label_pos,
    })
  }
  let base_bbox = compute_bbox(nodes_out, edges_out)
  let (final_nodes, final_edges, bbox) = if rankdir == RankDir::TB {
    (nodes_out, edges_out, base_bbox)
  } else {
    transform_layout(nodes_out, edges_out, base_bbox, rankdir)
  }
  let subgraphs = layout_subgraphs(graph, final_nodes, final_edges)
  let mut final_bbox = if subgraphs.length() > 0 {
    expand_bbox_with_subgraphs(bbox, subgraphs)
  } else {
    bbox
  }
  if graph.is_root() && graph_has_cluster(graph) {
    let pad = cluster_margin_pt(graph)
    final_bbox = {
      llx: final_bbox.llx,
      lly: final_bbox.lly - pad,
      urx: final_bbox.urx,
      ury: final_bbox.ury + pad,
    }
  }
  if graph.is_root() && (rankdir == RankDir::TB || rankdir == RankDir::BT) {
    if port_pad_below > 0.0 || port_pad_above > 0.0 {
      final_bbox = {
        llx: final_bbox.llx,
        lly: final_bbox.lly - port_pad_below,
        urx: final_bbox.urx,
        ury: final_bbox.ury + port_pad_above,
      }
    }
  }
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match graph_label_metrics(graph) {
      Some((width_pt, height_pt)) => {
        let loc = graph_label_loc(graph)
        let just = graph_label_just(graph)
        final_bbox = expand_bbox_for_label(final_bbox, width_pt, height_pt, loc)
        label_pos = Some(
          graph_label_pos(final_bbox, width_pt, height_pt, loc, just),
        )
      }
      None => ()
    }
  }
  if graph.is_root() {
    let margin_x = if graph_has_cluster(graph) {
      graph_margin_x_pt(graph)
    } else {
      0.0
    }
    if margin_x > 0.0 {
      final_bbox = {
        llx: final_bbox.llx - margin_x,
        lly: final_bbox.lly,
        urx: final_bbox.urx + margin_x,
        ury: final_bbox.ury,
      }
    }
  }
  let layout = {
    graph,
    bbox: final_bbox,
    label_pos,
    nodes: final_nodes,
    edges: final_edges,
    subgraphs,
  }
  let adjusted_for_clusters =
    adjust_edge_labels_for_cluster_labels(layout, nodesep_pt)
  let adjusted = adjust_edge_labels_for_label_overlaps(
    adjusted_for_clusters,
    nodesep_pt,
    rankdir,
  )
  if graph.is_root() {
    let dx = -adjusted.bbox.llx
    let dy = -adjusted.bbox.lly
    if dx != 0.0 || dy != 0.0 {
      shift_layout_graph(adjusted, dx, dy)
    } else {
      adjusted
    }
  } else {
    adjusted
  }
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => if name.has_prefix("cluster") { write_bb = true }
      None => ()
    }
  }
  let record_orientation =
    record_layout_orientation(graph_rankdir(self.graph))
  if write_bb {
    self.graph.set_attr("bb", format_rect(self.bbox))
  }
  match self.label_pos {
    Some(pos) => self.graph.set_attr("lp", format_point(pos))
    None => ()
  }
  for node_layout in self.nodes {
    let node = node_layout.node
    node.set_attr("pos", format_point(node_layout.pos))
    node.set_attr("width", format_dim(node_layout.width_in))
    node.set_attr("height", format_dim(node_layout.height_in))
    if is_record_shape(node) {
      let size = node_size_from_points(
        node_layout.width_in * 72.0,
        node_layout.height_in * 72.0,
      )
      let rects = record_rects(
        node,
        node_layout.pos,
        size,
        record_orientation,
      )
      if rects.length() > 0 {
        node.set_attr("rects", format_rects(rects))
      }
    }
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", format_point(pos))
      None => ()
    }
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    let dir = edge_dir_for(edge, self.graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
      _ => false
    }
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      if include_tail {
        match spline.start {
          Some(point) => parts.push("s,\{format_point(point)}")
          None => ()
        }
      }
      if include_head {
        match spline.end {
          Some(point) => parts.push("e,\{format_point(point)}")
          None => ()
        }
      }
      for point in spline.points {
        parts.push(format_point(point))
      }
      segments.push(parts.join(" "))
    }
    let pos = segments.join(";")
    edge.set_attr("pos", pos)
    match edge_layout.label_pos {
      Some(pos) => edge.set_attr("lp", format_point(pos))
      None => ()
    }
    match edge_layout.head_label_pos {
      Some(pos) => edge.set_attr("head_lp", format_point(pos))
      None => ()
    }
    match edge_layout.tail_label_pos {
      Some(pos) => edge.set_attr("tail_lp", format_point(pos))
      None => ()
    }
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
