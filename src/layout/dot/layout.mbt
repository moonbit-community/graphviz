///|
priv struct NodeSize {
  width_in : Double
  height_in : Double
  width_pt : Double
  height_pt : Double
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
    Some(value) => match parse_edge_dir(value) {
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
fn font_width_scale(font_name : String) -> Double {
  let lower = font_name.to_lower()
  if lower.contains("palatino") {
    1.02
  } else {
    1.0
  }
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
fn label_text_dimensions(
  label : String,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  if label == "" {
    return (0.0, 0.0)
  }
  let line_height = if font_name.to_lower().contains("palatino") {
    font_size_pt * 1.125
  } else {
    font_size_pt * LINE_SPACING
  }
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
  let width_scale = font_width_scale(font_name)
  let width_pt =
    max_units.to_double() * font_size_pt * TEXT_SCALE * width_scale / 1000.0
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
fn label_text(node : @cgraph.Node) -> String {
  match node.get_attr("label") {
    Some(value) => {
      if value == "\\N" { node.name() } else { value }
    }
    None => node.name()
  }
}

///|
fn is_record_shape(node : @cgraph.Node) -> Bool {
  match node.get_attr("shape") {
    Some(value) => value.to_lower() == "record"
    None => false
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
        let name = if pos > 1 {
          field.unsafe_substring(start=1, end=pos)
        } else {
          ""
        }
        let len = field.length()
        let text = if pos + 1 < len {
          field.unsafe_substring(start=pos + 1, end=len)
        } else {
          ""
        }
        let port_name : String? = if name == "" { None } else { Some(name) }
        { name: port_name, text }
      }
      None => { name: None, text: field }
    }
  } else {
    { name: None, text: field }
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
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[RecordNodeSize] {
  let sizes : Array[RecordNodeSize] = []
  for node in nodes {
    match node {
      RecordNode::Field(field) => {
        let (text_width_pt, text_height_pt) =
          label_text_dimensions(field.text, font_name, font_size_pt)
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
    nodes,
    orientation,
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
fn node_size_from_points(width_pt : Double, height_pt : Double) -> NodeSize {
  let width_in = width_pt / 72.0
  let height_in = height_pt / 72.0
  { width_in, height_in, width_pt, height_pt }
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
    nodes,
    orientation,
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
      RecordNode::Group(children) => {
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
}

///|
fn record_rects(
  node : @cgraph.Node,
  pos : @geom.Point,
  size : NodeSize,
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
  record_layout_nodes(
    nodes,
    rect,
    RecordOrientation::Horizontal,
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
  record_layout_nodes(
    nodes,
    rect,
    RecordOrientation::Horizontal,
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
priv enum HtmlCellContent {
  Text(String)
  Table(HtmlTable)
}

///|
priv struct HtmlCell {
  content : HtmlCellContent
  port : String?
  col_span : Int
  row_span : Int
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
    if ch.is_ascii_alphabetic() || ch.is_ascii_digit() || ch == '_' || ch == '-' || ch == ':' {
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
  let port : String? = match attrs.get("port") {
    Some(value) => if value == "" { None } else { Some(value) }
    None => None
  }
  let col_span = html_parse_int(attrs.get("colspan"), 1)
  let row_span = html_parse_int(attrs.get("rowspan"), 1)
  let min_width_pt = match attrs.get("width") {
    Some(value) => Some(parse_double(value, 0.0))
    None => None
  }
  let min_height_pt = match attrs.get("height") {
    Some(value) => Some(parse_double(value, 0.0))
    None => None
  }
  let content = parse_html_cell_content(parser)
  { content, port, col_span, row_span, min_width_pt, min_height_pt }
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
  { rows, border_pt, cell_border_pt, cell_spacing_pt, cell_padding_pt }
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
fn html_cell_content_size(
  content : HtmlCellContent,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match content {
    HtmlCellContent::Text(text) => label_text_dimensions(text, font_name, font_size_pt)
    HtmlCellContent::Table(table) => html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn html_cell_size(
  table : HtmlTable,
  cell : HtmlCell,
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
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  let metrics = html_table_metrics(table, font_name, font_size_pt)
  (metrics.total_width, metrics.total_height)
}

///|
fn html_table_cell_layouts(
  table : HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
) -> Array[HtmlCellLayout] {
  let metrics = html_table_metrics(table, font_name, font_size_pt)
  if metrics.total_width <= 0.0 || metrics.total_height <= 0.0 {
    return []
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
  let layouts : Array[HtmlCellLayout] = []
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
    layouts.push({
      rect: { llx, lly, urx, ury },
      cell: placement.cell,
    })
  }
  layouts
}

///|
fn html_label_size(
  label : HtmlLabel,
  font_name : String,
  font_size_pt : Double,
) -> (Double, Double) {
  match label {
    HtmlLabel::Text(text) => label_text_dimensions(text, font_name, font_size_pt)
    HtmlLabel::Table(table) => html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn collect_html_ports(
  table : HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
  ports : Map[String, RecordPort],
) -> Unit {
  let layouts = html_table_cell_layouts(table, rect, font_name, font_size_pt)
  for layout in layouts {
    match layout.cell.port {
      Some(name) => {
        let center = @geom.Point::{
          x: (layout.rect.llx + layout.rect.urx) / 2.0,
          y: (layout.rect.lly + layout.rect.ury) / 2.0,
        }
        let size = node_size_from_points(
          layout.rect.urx - layout.rect.llx,
          layout.rect.ury - layout.rect.lly,
        )
        ports[name] = { center, size }
      }
      None => ()
    }
    match layout.cell.content {
      HtmlCellContent::Table(nested) => {
        collect_html_ports(nested, layout.rect, font_name, font_size_pt, ports)
      }
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
  match parse_html_label(label) {
    Some(HtmlLabel::Table(table)) => {
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
    Some(value) => {
      match value.name {
        Some(name) => {
          match label_ports_map.get(node_name) {
            Some(ports) => {
              match ports.get(name) {
                Some(port_info) => (port_info.center, port_info.size)
                None => (node_pos, node_size)
              }
            }
            None => (node_pos, node_size)
          }
        }
        None => (node_pos, node_size)
      }
    }
    None => (node_pos, node_size)
  }
}

///|
fn node_size(node : @cgraph.Node) -> NodeSize {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let scale_ellipse = match shape {
    "box"
    | "rect"
    | "rectangle"
    | "record"
    | "point"
    | "dot"
    | "plaintext"
    | "plain"
    | "none" => false
    _ => true
  }
  let (fallback_width, fallback_height) = if shape == "point" || shape == "dot" {
    (default_point_size_in(), default_point_size_in())
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
  if is_record_shape(node) {
    let label = label_text(node)
    let nodes = record_nodes(label)
    let record_size = record_group_size(
      nodes,
      RecordOrientation::Horizontal,
      font,
      font_size_pt,
      pad_x_pt,
      pad_y_pt,
    )
    let width_pt =
      if record_size.width_pt > base_width_pt { record_size.width_pt } else { base_width_pt }
    let height_pt =
      if record_size.height_pt > base_height_pt { record_size.height_pt } else { base_height_pt }
    return node_size_from_points(width_pt, height_pt)
  }
  let label = label_text(node)
  if is_html_label_text(label) {
    match parse_html_label(label) {
      Some(html_label) => {
        let (html_width_pt, html_height_pt) =
          html_label_size(html_label, font, font_size_pt)
        let width_pt =
          if html_width_pt + pad_x_pt > base_width_pt {
            html_width_pt + pad_x_pt
          } else {
            base_width_pt
          }
        let height_pt =
          if html_height_pt + pad_y_pt > base_height_pt {
            html_height_pt + pad_y_pt
          } else {
            base_height_pt
          }
        return node_size_from_points(width_pt, height_pt)
      }
      None => ()
    }
  }
  let (text_width_pt, text_height_pt) =
    label_text_dimensions(label, font, font_size_pt)
  let has_label = text_width_pt > 0.0 || text_height_pt > 0.0
  let label_width_pt = if has_label { text_width_pt + pad_x_pt } else { 0.0 }
  let label_height_pt = if has_label { text_height_pt + pad_y_pt } else { 0.0 }
  let mut scaled_label_width_pt = label_width_pt
  let mut scaled_label_height_pt = label_height_pt
  if scale_ellipse && has_label {
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
  }
  let scaled_label_width_in = scaled_label_width_pt / 72.0
  let scaled_label_height_in = scaled_label_height_pt / 72.0
  let width_in = if scaled_label_width_in > base_width_in {
    scaled_label_width_in
  } else {
    base_width_in
  }
  let height_in = if scaled_label_height_in > base_height_in {
    scaled_label_height_in
  } else {
    base_height_in
  }
  {
    width_in,
    height_in,
    width_pt: width_in * 72.0,
    height_pt: height_in * 72.0,
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
fn ordered_nodes(graph : @cgraph.Graph) -> Array[@cgraph.Node] {
  graph.nodes()
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
fn edge_weight(edge : @cgraph.Edge) -> Int {
  let weight_value = match edge.get_attr("weight") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let weight = weight_value.round().to_int()
  if weight < 0 { 0 } else { weight }
}

///|
fn edge_minlen(edge : @cgraph.Edge) -> Int {
  let minlen_value = match edge.get_attr("minlen") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let minlen = minlen_value.round().to_int()
  if minlen < 1 { 1 } else { minlen }
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
    Some(value) => {
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
    }
    None => ()
  }
  for child in subgraph.subgraphs() {
    add_rank_same_constraints(rank_graph, index, child)
  }
}

///|
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
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
    let minlen = edge_minlen(edge)
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
    None => match x_positions.get(name) {
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
  neighbors : Map[String, Array[String]],
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let mut i = 1
  while i < sorted.length() {
    let current = sorted[i]
    let current_key = position_key(current, desired, x_positions)
    let mut j = i
    let current_degree = match neighbors.get(current) {
      Some(list) => list.length()
      None => 0
    }
    while j > 0 {
      let prev = sorted[j - 1]
      let prev_key = position_key(prev, desired, x_positions)
      if prev_key < current_key {
        break
      }
      if prev_key == current_key {
        let prev_degree = match neighbors.get(prev) {
          Some(list) => list.length()
          None => 0
        }
        if prev_degree <= current_degree {
          break
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
fn node_width_pt(name : String, sizes : Map[String, NodeSize]) -> Double {
  match sizes.get(name) {
    Some(value) => value.width_pt
    None => default_node_width_in() * 72.0
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
  let widths : Array[Double] = []
  let targets : Array[Double] = []
  let cumulative : Array[Double] = []
  let mut cum = 0.0
  for i in 0..<len {
    let name = names[i]
    let width = node_width_pt(name, sizes)
    widths.push(width)
    let fallback = match x_positions.get(name) {
      Some(value) => value
      None => width / 2.0
    }
    let target = match desired.get(name) {
      Some(value) => (value + fallback) / 2.0
      None => fallback
    }
    targets.push(target)
    if i == 0 {
      cum = 0.0
    } else {
      let prev_width = widths[i - 1]
      let sep = (prev_width + width) / 2.0 + nodesep_pt
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
  x_positions : Map[String, Double],
  sizes : Map[String, NodeSize],
) -> Unit {
  let mut min_x = 0.0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let width = node_width_pt(name, sizes)
    let pos = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let left = pos - width / 2.0
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
  }
}

///|
fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
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
    while i < names.length() {
      let name = names[i]
      let tail_width = node_width_pt(prev, sizes)
      let head_width = node_width_pt(name, sizes)
      let width = tail_width / 2.0 + head_width / 2.0 + nodesep_pt
      current = trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
}

///|
fn reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
) -> Map[Int, Array[String]] {
  let ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    ordered[rank] = names
  }
  let mut x_positions = compute_rank_positions(rank_keys, ordered, sizes, nodesep_pt)
  if rank_keys.length() > 1 {
    let mut idx = rank_keys.length() - 1
    while idx > 0 {
      let rank = rank_keys[idx - 1]
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() > 1 {
        let desired = compute_desired_positions(names, children, x_positions)
        ordered[rank] = sort_by_positions(names, desired, x_positions, children)
        x_positions = compute_rank_positions(rank_keys, ordered, sizes, nodesep_pt)
      }
      idx = idx - 1
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
        ordered[rank] = sort_by_positions(names, desired, x_positions, parents)
        x_positions = compute_rank_positions(rank_keys, ordered, sizes, nodesep_pt)
      }
      j = j + 1
    }
  }
  ordered
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
        Some(point) => {
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
        None => ()
      }
      match spline.end {
        Some(point) => {
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
    llx: if base.llx < other.llx { base.llx } else { other.llx },
    lly: if base.lly < other.lly { base.lly } else { other.lly },
    urx: if base.urx > other.urx { base.urx } else { other.urx },
    ury: if base.ury > other.ury { base.ury } else { other.ury },
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
fn shift_optional_point(point : @geom.Point?, dx : Double, dy : Double) -> @geom.Point? {
  match point {
    Some(value) => Some(shift_point(value, dx, dy))
    None => None
  }
}

///|
fn shift_spline(spline : @geom.Spline, dx : Double, dy : Double) -> @geom.Spline {
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
      head_label_pos: transform_optional_point(edge_layout.head_label_pos, bbox, rankdir),
      tail_label_pos: transform_optional_point(edge_layout.tail_label_pos, bbox, rankdir),
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
  let default_loc = if graph.is_root() { LabelLoc::Bottom } else { LabelLoc::Top }
  parse_label_loc(graph.get_attr("labelloc"), default_loc)
}

///|
fn graph_label_just(graph : @cgraph.Graph) -> LabelJust {
  parse_label_just(graph.get_attr("labeljust"))
}

///|
fn graph_label_metrics(graph : @cgraph.Graph) -> (Double, Double)? {
  match graph.get_attr("label") {
    Some(value) => {
      if value == "" {
        None
      } else {
        let font_size_pt = @attrs.font_size(graph.get_attr("fontsize"))
        let font = @attrs.font_name(graph.get_attr("fontname"))
        let (width_pt, height_pt) = label_text_dimensions(value, font, font_size_pt)
        Some((width_pt, height_pt))
      }
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
    LabelLoc::Top => {
      ury = ury + label_height_pt + pad
    }
    LabelLoc::Bottom => {
      lly = lly - label_height_pt - pad
    }
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
        sub_edges.push(edge_layout)
      }
    }
    let mut bbox = compute_bbox(sub_nodes, sub_edges)
    let mut label_pos : @geom.Point? = None
    let mut label_info : (Double, Double, LabelLoc, LabelJust)? = None
    if is_cluster_graph(subgraph) {
      let pad = 8.0
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
    let sub_subgraphs = layout_subgraphs(subgraph, nodes_out, edges_out)
    if sub_subgraphs.length() > 0 {
      bbox = expand_bbox_with_subgraphs(bbox, sub_subgraphs)
    }
    match label_info {
      Some((width_pt, height_pt, loc, just)) => {
        label_pos = Some(graph_label_pos(bbox, width_pt, height_pt, loc, just))
      }
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
  {
    rankdir: None,
    nodesep: None,
    ranksep: None,
    splines: None,
  }
}

///|
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  let rankdir = match opts.rankdir {
    Some(value) => value
    None => match graph.get_attr("rankdir") {
      Some(value) => match parse_rankdir(value) {
        Some(parsed) => parsed
        None => RankDir::TB
      }
      None => RankDir::TB
    }
  }
  let nodesep_in = match opts.nodesep {
    Some(value) => value
    None => match graph.get_attr("nodesep") {
      Some(value) => parse_first_double(value, default_nodesep_in())
      None => default_nodesep_in()
    }
  }
  let ranksep_in = match opts.ranksep {
    Some(value) => value
    None => match graph.get_attr("ranksep") {
      Some(value) => parse_first_double(value, default_ranksep_in())
      None => default_ranksep_in()
    }
  }
  let splines = match opts.splines {
    Some(value) => value
    None => match graph.get_attr("splines") {
      Some(value) => match parse_splines(value) {
        Some(parsed) => parsed
        None => SplinesMode::Spline
      }
      None => SplinesMode::Spline
    }
  }
  let _ = splines
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    sizes[node.name()] = node_size(node)
  }
  let ranks = if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(graph, nodes, edges)
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
  let rank_heights : Map[Int, Double] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_height = 0.0
    for name in names {
      let size = match sizes.get(name) {
        Some(value) => value
        None => node_size(graph.node(name))
      }
      if size.height_pt > max_height {
        max_height = size.height_pt
      }
    }
    rank_heights[rank] = max_height
  }
  let nodesep_pt = nodesep_in * 72.0
  let ranksep_pt = ranksep_in * 72.0
  let y_positions : Map[String, Double] = Map::new()
  let mut total_height = 0.0
  for i in 0..<rank_keys.length() {
    let rank = rank_keys[i]
    let height = match rank_heights.get(rank) {
      Some(value) => value
      None => 0.0
    }
    total_height = total_height + height
    if i + 1 < rank_keys.length() {
      total_height = total_height + ranksep_pt
    }
  }
  let mut current_y = total_height
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let max_height = match rank_heights.get(rank) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = current_y - max_height / 2.0
    for name in names {
      y_positions[name] = pos_y
    }
    current_y = current_y - max_height - ranksep_pt
  }
  let ordering = match graph.get_attr("ordering") {
    Some(value) => parse_ordering(value)
    None => None
  }
  let ordered_groups = match ordering {
    Some(_) => groups
    None => {
      let (parents, children) = build_edge_index(nodes, edges)
      reorder_rank_groups(
        rank_keys,
        groups,
        parents,
        children,
        sizes,
        nodesep_pt,
      )
    }
  }
  let x_positions = compute_x_positions(
    nodes,
    edges,
    ranks,
    rank_keys,
    ordered_groups,
    sizes,
    nodesep_pt,
    ordering,
  )
  normalize_x_positions(nodes, x_positions, sizes)
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
      None => node_size(node)
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
      let ports = record_ports(node_layout.node, node_layout.pos, size)
      label_ports_map[node_layout.node.name()] = ports
    } else {
      match parse_html_label(label_text(node_layout.node)) {
        Some(HtmlLabel::Table(_)) => {
          let ports = html_ports(node_layout.node, node_layout.pos, size)
          label_ports_map[node_layout.node.name()] = ports
        }
        _ => ()
      }
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
      None => node_size(edge.tail())
    }
    let head_size = match sizes.get(head_name) {
      Some(value) => value
      None => node_size(edge.head())
    }
    let (tail_anchor, tail_anchor_size) = port_geometry(
      tail_name,
      edge.tail_port(),
      label_ports_map,
      tail_pos,
      tail_size,
    )
    let (head_anchor, head_anchor_size) = port_geometry(
      head_name,
      edge.head_port(),
      label_ports_map,
      head_pos,
      head_size,
    )
    let tail_clip = clip_to_rect(tail_anchor, tail_anchor_size, head_anchor)
    let head_clip = clip_to_rect(head_anchor, head_anchor_size, tail_anchor)
    let dir = edge_dir_for(edge, graph.kind())
    let include_tail = match dir {
      EdgeDir::Back | EdgeDir::Both => true
      _ => false
    }
    let include_head = match dir {
      EdgeDir::Forward | EdgeDir::Both => true
      _ => false
    }
    let spline = match splines {
      SplinesMode::Polyline => edge_spline_for_polyline(
        edge,
        tail_clip,
        head_clip,
        rankdir,
        false,
        include_tail,
        include_head,
      )
      SplinesMode::Ortho => edge_spline_for_polyline(
        edge,
        tail_clip,
        head_clip,
        rankdir,
        true,
        include_tail,
        include_head,
      )
      _ => edge_spline_for_line(
        edge,
        tail_anchor,
        head_anchor,
        tail_anchor_size,
        head_anchor_size,
        include_tail,
        include_head,
      )
    }
    let label_pos : @geom.Point? = match edge.get_attr("label") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some({ x: (tail_clip.x + head_clip.x) / 2.0, y: (tail_clip.y + head_clip.y) / 2.0 })
        }
      }
      None => None
    }
    let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some(head_clip)
        }
      }
      None => None
    }
    let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some(tail_clip)
        }
      }
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
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match graph_label_metrics(graph) {
      Some((width_pt, height_pt)) => {
        let loc = graph_label_loc(graph)
        let just = graph_label_just(graph)
        final_bbox = expand_bbox_for_label(final_bbox, width_pt, height_pt, loc)
        label_pos = Some(graph_label_pos(final_bbox, width_pt, height_pt, loc, just))
      }
      None => ()
    }
  }
  {
    graph,
    bbox: final_bbox,
    label_pos,
    nodes: final_nodes,
    edges: final_edges,
    subgraphs,
  }
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => {
        if name.has_prefix("cluster") {
          write_bb = true
        }
      }
      None => ()
    }
  }
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
      let rects = record_rects(node, node_layout.pos, size)
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
