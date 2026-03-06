///|
/// Graphviz parity: record layout aligned to refs/graphviz/lib/common/shapes.c + output.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
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
    numbers.push(@dot_shared.parse_double_or(token.to_string(), 0.0))
  }
  numbers
}

///|
priv struct MarginValues {
  x_in : Double
  y_in : Double
}

///|
priv struct NodePadding {
  pad_x_pt : Double
  pad_y_pt : Double
}

priv struct SizePt {
  width_pt : Double
  height_pt : Double
}

///|
fn parse_margin(value : String) -> MarginValues? {
  let numbers = extract_numbers(value)
  if numbers.length() == 0 {
    return None
  }
  if numbers.length() == 1 {
    let val = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
    return Some({ x_in: val, y_in: val })
  }
  let x = if numbers[0] < 0.0 { 0.0 } else { numbers[0] }
  let y = if numbers[1] < 0.0 { 0.0 } else { numbers[1] }
  Some({ x_in: x, y_in: y })
}

///|
/// Graphviz parity: root graph margin defaults to 0 unless explicitly set.
/// Do not change behavior without updating fixtures/tests.
fn graph_margin_x_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some(margins) => margins.x_in * 72.0
        None => 0.0
      }
    None => 0.0
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
fn node_padding(node : @cgraph.Node) -> NodePadding {
  let mut pad_x_pt = PAD_X_PT
  let mut pad_y_pt = PAD_Y_PT
  match node.get_attr("margin") {
    Some(value) =>
      match parse_margin(value) {
        Some(margins) => {
          pad_x_pt = margins.x_in * 72.0 * 2.0
          pad_y_pt = margins.y_in * 72.0 * 2.0
        }
        None => ()
      }
    None => ()
  }
  { pad_x_pt, pad_y_pt }
}

///|
priv enum NodeFixedSizeMode {
  None
  True
  Shape
} derive(Eq)

///|
fn node_fixedsize_mode(node : @cgraph.Node) -> NodeFixedSizeMode {
  match node.get_attr("fixedsize") {
    Some(value) =>
      match value.trim(chars=" \n\r\t").to_string().to_lower() {
        "true" | "yes" | "1" => NodeFixedSizeMode::True
        "shape" => NodeFixedSizeMode::Shape
        _ => NodeFixedSizeMode::None
      }
    None => NodeFixedSizeMode::None
  }
}

///|
/// Graphviz parity: apply PAD to label dimensions for non-plain shapes
/// (macros.h PAD + shapes.c poly_init).
fn apply_label_padding_for_shape(
  shape : String,
  width_pt : Double,
  height_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> SizePt {
  if shape == "plain" || (width_pt <= 0.0 && height_pt <= 0.0) {
    { width_pt, height_pt }
  } else {
    { width_pt: width_pt + pad_x_pt, height_pt: height_pt + pad_y_pt }
  }
}

priv struct RecordField {
  name : String?
  text : String
}

///|
priv struct RecordPort {
  center : @geom.Point
  size : NodeSize
  sides : Int
}

///|
priv enum RecordOrientation {
  Horizontal
  Vertical
}

///|
fn record_layout_orientation(_rankdir : RankDir) -> RecordOrientation {
  match _rankdir {
    RankDir::LR | RankDir::RL => RecordOrientation::Vertical
    _ => RecordOrientation::Horizontal
  }
}

///|
priv enum RecordNode {
  Field(RecordField)
  Group(Array[RecordNode])
}

///|
let record_nodes_cache : Ref[Map[String, Array[RecordNode]]] =
  @ref.new(Map::new())

///|
let html_label_cache : Ref[Map[String, @html_label.HtmlLabel]] =
  @ref.new(Map::new())

///|
let record_ports_cache : Ref[Map[String, Map[String, RecordPort]]] =
  @ref.new(Map::new())

///|
let html_ports_cache : Ref[Map[String, Map[String, RecordPort]]] =
  @ref.new(Map::new())

///|
fn reset_label_caches() -> Unit {
  record_nodes_cache.val = Map::new()
  html_label_cache.val = Map::new()
  record_ports_cache.val = Map::new()
  html_ports_cache.val = Map::new()
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
  let normalized = normalize_record_text(raw_text).trim(chars=" \n\r\t").to_string()
  let text = if normalized == "" { " " } else { normalized }
  { name: port_name, text }
}

///|
fn normalize_record_text(text : String) -> String {
  let sb = StringBuilder::new()
  let mut escaping = false
  for ch in text {
    if escaping {
      escaping = false
      if ch == 'n' || ch == 'l' || ch == 'r' {
        sb.write_char('\\')
        sb.write_char(ch)
      } else {
        sb.write_char(ch)
      }
      continue
    }
    if ch == '\\' {
      escaping = true
      continue
    }
    sb.write_char(ch)
  }
  if escaping {
    sb.write_char('\\')
  }
  sb.to_string()
}

///|
fn record_nodes(label : String) -> Array[RecordNode] {
  match record_nodes_cache.val.get(label) {
    Some(cached) => cached
    None => {
      let chars : Array[Char] = []
      for ch in label {
        chars.push(ch)
      }
      let parser = RecordParser::{ chars, index: 0 }
      // Graphviz parity: preserve outer braces as an explicit group.
      // Do not flatten a single top-level group; it flips field orientation.
      let nodes = parse_record_nodes(parser)
      record_nodes_cache.val[label] = nodes
      nodes
    }
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
        let width_pt = text_width_pt + pad_x_pt
        let height_pt = text_height_pt + pad_y_pt
        sizes.push({ width_pt, height_pt })
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
fn swap_node_size(size : NodeSize) -> NodeSize {
  let width_in = size.height_in
  let height_in = size.width_in
  let width_pt = size.height_pt
  let height_pt = size.width_pt
  let half = width_pt / 2.0
  { width_in, height_in, width_pt, height_pt, left_pt: half, right_pt: half }
}

///|
fn vnode_size_from_widths(left_pt : Double, right_pt : Double) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  let height_pt = VNODE_HEIGHT_PT
  let height_in = height_pt / 72.0
  {
    width_in,
    height_in,
    width_pt,
    height_pt,
    left_pt,
    right_pt,
  }
}

///|
fn vnode_size_from_widths_with_h(
  left_pt : Double,
  right_pt : Double,
  height_pt : Double,
) -> NodeSize {
  let width_pt = left_pt + right_pt
  let width_in = width_pt / 72.0
  let height_in = height_pt / 72.0
  { width_in, height_in, width_pt, height_pt, left_pt, right_pt }
}

///|
fn size_with_extra_right(size : NodeSize, extra_right_pt : Double) -> NodeSize {
  if extra_right_pt <= 0.0 {
    size
  } else {
    vnode_size_from_widths_with_h(
      size.left_pt,
      size.right_pt + extra_right_pt,
      size.height_pt,
    )
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
  sides : Int,
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
  let last = nodes.length() - 1
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
    let child_sides =
      if sides == 0 {
      0
    } else {
      let mut mask = 0
      match orientation {
        RecordOrientation::Horizontal =>
          if i == 0 {
            if i == last {
              mask =
                PORT_SIDE_TOP |
                PORT_SIDE_BOTTOM |
                PORT_SIDE_LEFT |
                PORT_SIDE_RIGHT
            } else {
              mask = PORT_SIDE_TOP | PORT_SIDE_BOTTOM | PORT_SIDE_LEFT
            }
          } else if i == last {
            mask = PORT_SIDE_TOP | PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT
          } else {
            mask = PORT_SIDE_TOP | PORT_SIDE_BOTTOM
          }
        RecordOrientation::Vertical =>
          if i == 0 {
            if i == last {
              mask =
                PORT_SIDE_TOP |
                PORT_SIDE_BOTTOM |
                PORT_SIDE_LEFT |
                PORT_SIDE_RIGHT
            } else {
              mask = PORT_SIDE_TOP | PORT_SIDE_LEFT | PORT_SIDE_RIGHT
            }
          } else if i == last {
            mask = PORT_SIDE_LEFT | PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT
          } else {
            mask = PORT_SIDE_LEFT | PORT_SIDE_RIGHT
          }
      }
      sides & mask
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
            let field_size = @dot_shared.node_size_from_points(
              child_rect.urx - child_rect.llx,
              child_rect.ury - child_rect.lly,
            )
            ports[name] = {
              center,
              size: field_size,
              sides: child_sides,
            }
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
          child_sides,
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
  let padding = node_padding(node)
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
    lly: rect.lly + @dot_shared.RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - @dot_shared.RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    padding.pad_x_pt,
    padding.pad_y_pt,
    PORT_SIDE_TOP | PORT_SIDE_BOTTOM | PORT_SIDE_LEFT | PORT_SIDE_RIGHT,
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
  let is_origin = pos.x == 0.0 && pos.y == 0.0
  if is_origin {
    let name = node.name()
    match record_ports_cache.val.get(name) {
      Some(cached) => return cached
      None => ()
    }
  }
  let label = label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = node_padding(node)
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
    lly: rect.lly + @dot_shared.RECORD_BORDER_PT,
    urx: rect.urx,
    ury: rect.ury - @dot_shared.RECORD_BORDER_PT,
  }
  record_layout_nodes(
    nodes,
    inner_rect,
    orientation,
    font,
    font_size_pt,
    padding.pad_x_pt,
    padding.pad_y_pt,
    PORT_SIDE_TOP | PORT_SIDE_BOTTOM | PORT_SIDE_LEFT | PORT_SIDE_RIGHT,
    rects,
    ports,
  )
  if is_origin {
    record_ports_cache.val[node.name()] = ports
  }
  ports
}

///|
/// Graphviz parity: record_path field selection aligned to refs/graphviz/lib/common/shapes.c.
/// Do not change behavior without updating fixtures/tests.
fn record_top_level_rects(
  nodes : Array[RecordNode],
  rect : @geom.Rect,
  orientation : RecordOrientation,
  font_name : String,
  font_size_pt : Double,
  pad_x_pt : Double,
  pad_y_pt : Double,
) -> Array[@geom.Rect] {
  if nodes.length() == 0 {
    return []
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
  let rects : Array[@geom.Rect] = []
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
    rects.push(child_rect)
  }
  rects
}

///|
/// Graphviz parity: record_path boxes aligned to refs/graphviz/lib/common/shapes.c.
/// Do not change behavior without updating fixtures/tests.
fn record_port_path_box(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  pos : @geom.Point,
  size : NodeSize,
  rankdir : RankDir,
) -> @geom.Rect? {
  if !@dot_shared.port_is_explicit(port) {
    return None
  }
  if !is_record_shape(node) {
    return None
  }
  let orientation = record_layout_orientation(rankdir)
  let raw_ports = record_ports(node, { x: 0.0, y: 0.0 }, size, orientation)
  let resolved_port = resolve_label_port_for_node(port, raw_ports)
  let name = match resolved_port.name {
    Some(value) => value
    None => return None
  }
  let port_info = match raw_ports.get(name) {
    Some(value) => value
    None => return None
  }
  let label = label_text(node)
  let nodes = record_nodes(label)
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = node_padding(node)
  let node_rect : @geom.Rect = {
    llx: -size.width_pt / 2.0,
    lly: -size.height_pt / 2.0,
    urx: size.width_pt / 2.0,
    ury: size.height_pt / 2.0,
  }
  let inner_rect : @geom.Rect = {
    llx: node_rect.llx,
    lly: node_rect.lly + @dot_shared.RECORD_BORDER_PT,
    urx: node_rect.urx,
    ury: node_rect.ury - @dot_shared.RECORD_BORDER_PT,
  }
  let top_rects =
    record_top_level_rects(
      nodes,
      inner_rect,
      orientation,
      font,
      font_size_pt,
      padding.pad_x_pt,
      padding.pad_y_pt,
    )
  let port_x = port_info.center.x
  let mut chosen : @geom.Rect? = None
  for rect in top_rects {
    let hit = match orientation {
      RecordOrientation::Horizontal =>
        port_x >= rect.llx && port_x <= rect.urx
      RecordOrientation::Vertical =>
        port_x >= rect.lly && port_x <= rect.ury
    }
    if hit {
      chosen = Some(rect)
      break
    }
  }
  let field_rect = match chosen {
    Some(value) => value
    None => return None
  }
  let path_rect_local : @geom.Rect = match orientation {
    RecordOrientation::Horizontal => {
      llx: field_rect.llx,
      lly: node_rect.lly,
      urx: field_rect.urx,
      ury: node_rect.ury,
    }
    RecordOrientation::Vertical => {
      llx: node_rect.llx,
      lly: field_rect.lly,
      urx: node_rect.urx,
      ury: field_rect.ury,
    }
  }
  let corners : Array[@geom.Point] = [
    @edge_spline.point(path_rect_local.llx, path_rect_local.lly),
    @edge_spline.point(path_rect_local.llx, path_rect_local.ury),
    @edge_spline.point(path_rect_local.urx, path_rect_local.lly),
    @edge_spline.point(path_rect_local.urx, path_rect_local.ury),
  ]
  let mut minx = 1.0e308
  let mut miny = 1.0e308
  let mut maxx = -1.0e308
  let mut maxy = -1.0e308
  for corner in corners {
    let offset = layout_port_offset(corner, rankdir)
    let abs = @edge_spline.point(pos.x + offset.x, pos.y + offset.y)
    if abs.x < minx { minx = abs.x }
    if abs.x > maxx { maxx = abs.x }
    if abs.y < miny { miny = abs.y }
    if abs.y > maxy { maxy = abs.y }
  }
  Some({ llx: minx, lly: miny, urx: maxx, ury: maxy })
}

///|
fn record_port_padding_y(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> RecordPortPaddingY {
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
                          @dot_shared.RECORD_BORDER_PT / 2.0 -
                          0.01
                        let adjusted =
                          if half_height < 0.0 {
                          0.0
                        } else {
                          half_height * 0.5
                        }
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
    if @dot_shared.port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
      update_padding(edge.tail().name(), edge.tail_port())
    }
    if @dot_shared.port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
      update_padding(edge.head().name(), edge.head_port())
    }
  }
  { below: extra_below, above: extra_above }
}

///|
priv struct RecordPortPaddingY {
  below : Double
  above : Double
}

///|
///|
fn html_cell_content_size(
  content : @html_label.HtmlCellContent,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  match content {
    @html_label.HtmlCellContent::Text(text) => {
      let (width_pt, height_pt) =
        label_text_dimensions(text, font_name, font_size_pt)
      { width_pt, height_pt }
    }
    @html_label.HtmlCellContent::StyledText(spans) => {
      let text = StringBuilder::new()
      for span in spans {
        text.write_string(span.text)
      }
      let (width_pt, height_pt) =
        label_text_dimensions(text.to_string(), font_name, font_size_pt)
      { width_pt, height_pt }
    }
    @html_label.HtmlCellContent::Table(table) => {
      html_table_size(table, font_name, font_size_pt)
    }
  }
}

///|
/// Graphviz parity: html cell border defaults to table border when cellborder is unset.
fn html_table_cell_border_pt(table : @html_label.HtmlTable) -> Double {
  if table.cell_border_pt >= 0.0 {
    table.cell_border_pt
  } else if table.border_pt >= 0.0 {
    table.border_pt
  } else {
    1.0
  }
}

///|
fn html_cell_size(
  table : @html_label.HtmlTable,
  cell : @html_label.HtmlCell,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  let content_size = html_cell_content_size(
    cell.content,
    font_name,
    font_size_pt,
  )
  let cell_border_pt = html_table_cell_border_pt(table)
  let mut width =
    content_size.width_pt + table.cell_padding_pt * 2.0 + cell_border_pt * 2.0
  let mut height =
    content_size.height_pt + table.cell_padding_pt * 2.0 + cell_border_pt * 2.0
  match cell.min_width_pt {
    Some(value) => if value > width { width = value }
    None => ()
  }
  match cell.min_height_pt {
    Some(value) => if value > height { height = value }
    None => ()
  }
  { width_pt: width, height_pt: height }
}

///|
fn html_table_size(
  table : @html_label.HtmlTable,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  let (width_pt, height_pt) =
    @html_label.html_table_size(table, cell => {
      let cell_size = html_cell_size(table, cell, font_name, font_size_pt)
      (cell_size.width_pt, cell_size.height_pt)
    })
  { width_pt, height_pt }
}

///|
fn html_table_layout(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  font_name : String,
  font_size_pt : Double,
) -> @html_label.HtmlTableLayout {
  @html_label.html_table_layout(table, rect, cell => {
    let cell_size = html_cell_size(table, cell, font_name, font_size_pt)
    (cell_size.width_pt, cell_size.height_pt)
  })
}

///|
fn parse_html_label_cached(label : String) -> @html_label.HtmlLabel? {
  match html_label_cache.val.get(label) {
    Some(cached) => Some(cached)
    None =>
      match @html_label.parse_html_label(label) {
        Some(parsed) => {
          html_label_cache.val[label] = parsed
          Some(parsed)
        }
        None => None
      }
  }
}

///|
fn html_label_size(
  label : @html_label.HtmlLabel,
  font_name : String,
  font_size_pt : Double,
) -> SizePt {
  match label {
    @html_label.HtmlLabel::Text(text) => {
      let (width_pt, height_pt) =
        label_text_dimensions(text, font_name, font_size_pt)
      { width_pt, height_pt }
    }
    @html_label.HtmlLabel::Table(table) =>
      html_table_size(table, font_name, font_size_pt)
  }
}

///|
fn collect_html_ports(
  table : @html_label.HtmlTable,
  rect : @geom.Rect,
  node_rect : @geom.Rect,
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
        let size = @dot_shared.node_size_from_points(
          cell_layout.rect.urx - cell_layout.rect.llx,
          cell_layout.rect.ury - cell_layout.rect.lly,
        )
        let sides = port_side_mask_from_rects(cell_layout.rect, node_rect)
        ports[name] = { center, size, sides }
      }
      None => ()
    }
    match cell_layout.cell.content {
      @html_label.HtmlCellContent::Table(nested) =>
        collect_html_ports(
          nested,
          cell_layout.rect,
          node_rect,
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
  let is_origin = pos.x == 0.0 && pos.y == 0.0
  if is_origin {
    let name = node.name()
    match html_ports_cache.val.get(name) {
      Some(cached) => return cached
      None => ()
    }
  }
  let ports : Map[String, RecordPort] = Map::new()
  match parse_html_label_cached(label) {
    Some(@html_label.HtmlLabel::Table(table)) => {
      let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
      let font = @attrs.font_name(node.get_attr("fontname"))
      let rect : @geom.Rect = {
        llx: pos.x - size.width_pt / 2.0,
        lly: pos.y - size.height_pt / 2.0,
        urx: pos.x + size.width_pt / 2.0,
        ury: pos.y + size.height_pt / 2.0,
      }
      collect_html_ports(table, rect, rect, font, font_size_pt, ports)
    }
    _ => ()
  }
  if is_origin {
    html_ports_cache.val[node.name()] = ports
  }
  ports
}

///|
fn layout_port_offset(offset : @geom.Point, rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => offset
    RankDir::BT => { x: offset.x, y: -offset.y }
    RankDir::LR => { x: offset.y, y: -offset.x }
    RankDir::RL => { x: -offset.y, y: offset.x }
  }
}

///|
fn layout_ports_from_final(
  ports : Map[String, RecordPort],
  layout_pos : @geom.Point,
  rankdir : RankDir,
) -> Map[String, RecordPort] {
  let rotated : Map[String, RecordPort] = Map::new()
  for name, port in ports {
    let offset = layout_port_offset(port.center, rankdir)
    let center = @geom.Point::{
      x: layout_pos.x + offset.x,
      y: layout_pos.y + offset.y,
    }
    let size = match rankdir {
      RankDir::LR | RankDir::RL => swap_node_size(port.size)
      _ => port.size
    }
    rotated[name] = { center, size, sides: port.sides }
  }
  rotated
}

///|
const PORT_SIDE_BOTTOM : Int = 1
///|
const PORT_SIDE_RIGHT : Int = 2
///|
const PORT_SIDE_TOP : Int = 4
///|
const PORT_SIDE_LEFT : Int = 8
///|
const PORT_SIDE_ALL : Int =
  PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT | PORT_SIDE_TOP | PORT_SIDE_LEFT

///|
fn cvt_pt(p : @geom.Point, rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => p
    RankDir::BT => @edge_spline.point(p.x, -p.y)
    RankDir::LR => @edge_spline.point(-p.y, p.x)
    RankDir::RL => @edge_spline.point(p.y, p.x)
  }
}

///|
fn invflip_side(side : Int, rankdir : RankDir) -> Int {
  let mut out = 0
  let add = (from : Int, to : Int) => {
    if (side & from) != 0 {
      out = out | to
    }
  }
  match rankdir {
    RankDir::TB => side
    RankDir::BT => {
      add(PORT_SIDE_TOP, PORT_SIDE_BOTTOM)
      add(PORT_SIDE_BOTTOM, PORT_SIDE_TOP)
      add(PORT_SIDE_LEFT, PORT_SIDE_LEFT)
      add(PORT_SIDE_RIGHT, PORT_SIDE_RIGHT)
      out
    }
    RankDir::LR => {
      add(PORT_SIDE_TOP, PORT_SIDE_RIGHT)
      add(PORT_SIDE_BOTTOM, PORT_SIDE_LEFT)
      add(PORT_SIDE_LEFT, PORT_SIDE_TOP)
      add(PORT_SIDE_RIGHT, PORT_SIDE_BOTTOM)
      out
    }
    RankDir::RL => {
      add(PORT_SIDE_TOP, PORT_SIDE_RIGHT)
      add(PORT_SIDE_BOTTOM, PORT_SIDE_LEFT)
      add(PORT_SIDE_LEFT, PORT_SIDE_BOTTOM)
      add(PORT_SIDE_RIGHT, PORT_SIDE_TOP)
      out
    }
  }
}

///|
fn port_side_mask_from_rects(
  port_rect : @geom.Rect,
  node_rect : @geom.Rect,
) -> Int {
  let eps = if @dot_shared.RECORD_BORDER_PT > 0.01 {
    @dot_shared.RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let mut mask = 0
  if Double::abs(port_rect.llx - node_rect.llx) <= eps {
    mask = mask | PORT_SIDE_LEFT
  }
  if Double::abs(port_rect.urx - node_rect.urx) <= eps {
    mask = mask | PORT_SIDE_RIGHT
  }
  if Double::abs(port_rect.lly - node_rect.lly) <= eps {
    mask = mask | PORT_SIDE_BOTTOM
  }
  if Double::abs(port_rect.ury - node_rect.ury) <= eps {
    mask = mask | PORT_SIDE_TOP
  }
  mask
}

///|
priv struct DynamicPortAnchor {
  anchor : @geom.Point?
  side : Int
}

///|
priv struct ResolvedLabelPort {
  name : String?
  effective_compass : @cgraph.Compass?
}

///|
priv struct DynamicPortAnchorForEdge {
  anchor : @geom.Point?
  side : Int
  is_dynamic : Bool
}

///|
fn resolve_dynamic_port_anchor(
  raw_port : RecordPort,
  node_pos : @geom.Point,
  other_pos : @geom.Point,
  rankdir : RankDir,
) -> DynamicPortAnchor {
  let sides = raw_port.sides
  if sides == 0 || sides == PORT_SIDE_ALL {
    return { anchor: None, side: 0 }
  }
  let half_w = raw_port.size.width_pt / 2.0
  let half_h = raw_port.size.height_pt / 2.0
  let port_rect : @geom.Rect = {
    llx: raw_port.center.x - half_w,
    lly: raw_port.center.y - half_h,
    urx: raw_port.center.x + half_w,
    ury: raw_port.center.y + half_h,
  }
  let mid_x = (port_rect.llx + port_rect.urx) / 2.0
  let mid_y = (port_rect.lly + port_rect.ury) / 2.0
  let pt = cvt_pt(node_pos, rankdir)
  let opt = cvt_pt(other_pos, rankdir)
  let mut best_side = 0
  let mut best_dist = 0.0
  let mut best_point = @edge_spline.point(0.0, 0.0)
  let mut seen = false
  let consider = (side : Int, pos : @geom.Point) => {
    if (sides & side) == 0 {
      return ()
    }
    let cand = @edge_spline.point_add(pt, pos)
    let dist = @edge_spline.point_dist2(cand, opt)
    if !seen || dist < best_dist {
      best_dist = dist
      best_side = side
      best_point = pos
      seen = true
    }
  }
  consider(PORT_SIDE_BOTTOM, @edge_spline.point(mid_x, port_rect.lly))
  consider(PORT_SIDE_RIGHT, @edge_spline.point(port_rect.urx, mid_y))
  consider(PORT_SIDE_TOP, @edge_spline.point(mid_x, port_rect.ury))
  consider(PORT_SIDE_LEFT, @edge_spline.point(port_rect.llx, mid_y))
  if !seen {
    return { anchor: None, side: 0 }
  }
  let offset = layout_port_offset(best_point, rankdir)
  let anchor = @edge_spline.point_add(node_pos, offset)
  { anchor: Some(anchor), side: invflip_side(best_side, rankdir) }
}

fn compass_port_name(compass : @cgraph.Compass) -> String {
  match compass {
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
}

///|
/// Graphviz parity: `node:token` resolves to a label/record port first,
/// then falls back to compass semantics when no such port exists.
fn resolve_label_port_for_node(
  port : @cgraph.Port?,
  ports : Map[String, RecordPort],
) -> ResolvedLabelPort {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          if ports.get(name) is Some(_) {
            { name: Some(name), effective_compass: value.compass }
          } else {
            { name: None, effective_compass: value.compass }
          }
        None =>
          match value.compass {
            Some(compass) => {
              let fallback_name = compass_port_name(compass)
              if ports.get(fallback_name) is Some(_) {
                { name: Some(fallback_name), effective_compass: None }
              } else {
                { name: None, effective_compass: Some(compass) }
              }
            }
            None => { name: None, effective_compass: None }
          }
      }
    None => { name: None, effective_compass: None }
  }
}

///|
fn resolve_label_port_for_graph(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_raw : Map[String, Map[String, RecordPort]],
) -> ResolvedLabelPort {
  match label_ports_raw.get(node_name) {
    Some(ports) => resolve_label_port_for_node(port, ports)
    None =>
      match port {
        Some(value) => { name: None, effective_compass: value.compass }
        None => { name: None, effective_compass: None }
      }
  }
}

///|
///|
fn dynamic_port_anchor_for_edge(
  port : @cgraph.Port?,
  node_name : String,
  raw_ports_map : Map[String, Map[String, RecordPort]],
  node_pos : @geom.Point,
  other_pos : @geom.Point,
  rankdir : RankDir,
  record_border_adjust : Double,
) -> DynamicPortAnchorForEdge {
  let resolved_port =
    resolve_label_port_for_graph(node_name, port, raw_ports_map)
  if resolved_port.effective_compass is Some(_) {
    return { anchor: None, side: 0, is_dynamic: false }
  }
  let port_name = match resolved_port.name {
    Some(value) => value
    None => return { anchor: None, side: 0, is_dynamic: false }
  }
  match raw_ports_map.get(node_name) {
    Some(raw_ports) =>
      match raw_ports.get(port_name) {
        Some(raw_port) => {
          let resolved_anchor =
            resolve_dynamic_port_anchor(
              raw_port,
              node_pos,
              other_pos,
              rankdir,
            )
          // Graphviz parity: keep resolvePort side in all rankdirs.
          // beginpath/endpath rely on this side to build record_path boxes.
          let effective_side = resolved_anchor.side
          // Graphviz parity: keep the raw dynamic anchor.
          // beginpath/endpath clamp start/end to box bounds in routespl.c,
          // and extra record-border shifts introduce 0.5pt drift in structs/records.
          let adjusted_anchor = resolved_anchor.anchor
          ignore(record_border_adjust)
          {
            anchor: adjusted_anchor,
            side: effective_side,
            is_dynamic: true,
          }
        }
        None => { anchor: None, side: 0, is_dynamic: false }
      }
    None => { anchor: None, side: 0, is_dynamic: false }
  }
}

///|
fn compass_side_mask(compass : @cgraph.Compass) -> Int {
  match compass {
    @cgraph.Compass::N => PORT_SIDE_TOP
    @cgraph.Compass::NE => PORT_SIDE_TOP | PORT_SIDE_RIGHT
    @cgraph.Compass::E => PORT_SIDE_RIGHT
    @cgraph.Compass::SE => PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT
    @cgraph.Compass::S => PORT_SIDE_BOTTOM
    @cgraph.Compass::SW => PORT_SIDE_BOTTOM | PORT_SIDE_LEFT
    @cgraph.Compass::W => PORT_SIDE_LEFT
    @cgraph.Compass::NW => PORT_SIDE_TOP | PORT_SIDE_LEFT
    @cgraph.Compass::C => 0
  }
}

///|
fn port_side_mask_from_rect(
  port_rect : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> Int {
  let node_rect = @edge_spline.port_side_rect(node_pos, node_size)
  port_side_mask_from_rects(port_rect, node_rect)
}

///|
fn port_side_mask_from_anchor(
  anchor : @geom.Point,
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> Int {
  let eps = if @dot_shared.RECORD_BORDER_PT > 0.01 {
    @dot_shared.RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let node_rect = @edge_spline.port_side_rect(node_pos, node_size)
  if Double::abs(anchor.x - node_rect.llx) <= eps {
    return PORT_SIDE_LEFT
  }
  if Double::abs(anchor.x - node_rect.urx) <= eps {
    return PORT_SIDE_RIGHT
  }
  if Double::abs(anchor.y - node_rect.lly) <= eps {
    return PORT_SIDE_BOTTOM
  }
  if Double::abs(anchor.y - node_rect.ury) <= eps {
    return PORT_SIDE_TOP
  }
  0
}

///|
fn port_side_for_edge(
  port : @cgraph.Port?,
  port_rect : @geom.Rect?,
  node_pos : @geom.Point,
  node_size : NodeSize,
  side_anchor : @geom.Point?,
) -> Int {
  let all_sides =
    PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT | PORT_SIDE_TOP | PORT_SIDE_LEFT
  let base_sides = match port_rect {
    Some(rect) => port_side_mask_from_rect(rect, node_pos, node_size)
    None => all_sides
  }
  match port {
    Some(value) =>
      match value.compass {
        Some(compass) => base_sides & compass_side_mask(compass)
        None =>
          match side_anchor {
            Some(anchor) => port_side_mask_from_anchor(anchor, node_pos, node_size)
            None => 0
          }
      }
    None => 0
  }
}

///|
fn port_rect_from_geometry(
  port : @cgraph.Port?,
  center : @geom.Point,
  size : NodeSize,
  node_size : NodeSize,
) -> @geom.Rect? {
  if !@dot_shared.port_is_explicit(port) {
    return None
  }
  let eps = if @dot_shared.RECORD_BORDER_PT > 0.01 {
    @dot_shared.RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let is_port_rect =
    Double::abs(size.width_pt - node_size.width_pt) > eps ||
      Double::abs(size.height_pt - node_size.height_pt) > eps
  if !is_port_rect {
    return None
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  Some({
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  })
}

///|
fn port_geometry(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_map : Map[String, Map[String, RecordPort]],
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> PortGeometry {
  let resolved_port =
    resolve_label_port_for_graph(node_name, port, label_ports_map)
  let name = match resolved_port.name {
    Some(value) => value
    None => return { center: node_pos, size: node_size }
  }
  match label_ports_map.get(node_name) {
    Some(ports) =>
      match ports.get(name) {
        Some(port_info) => { center: port_info.center, size: port_info.size }
        None => { center: node_pos, size: node_size }
      }
    None => { center: node_pos, size: node_size }
  }
}

///|
priv struct PortGeometry {
  center : @geom.Point
  size : NodeSize
}

///|
/// Graphviz parity: detect label ports using raw record/html port maps.
/// Do not change behavior without updating fixtures/tests.
fn port_is_label_port(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_raw : Map[String, Map[String, RecordPort]],
) -> Bool {
  let resolved_port =
    resolve_label_port_for_graph(node_name, port, label_ports_raw)
  resolved_port.name is Some(_)
}

///|
fn node_size(
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  let fixedsize_mode = node_fixedsize_mode(node)
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let regular_shape =
    shape == "msquare" ||
    shape == "mcircle" ||
    shape == "circle" ||
    shape == "doublecircle"
  // Graphviz parity: polygon promoter/arrow shapes use box-style label scaling.
  let scale_ellipse = match shape {
    "box"
    | "rect"
    | "rectangle"
    | "record"
    | "mrecord"
    | "msquare"
    | "mdiamond"
    | "rpromoter"
    | "lpromoter"
    | "rarrow"
    | "larrow"
    | "box3d"
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
    let height = @dot_shared.default_node_height_in()
    (height, height)
  } else {
    (@dot_shared.default_node_width_in(), @dot_shared.default_node_height_in())
  }
  let base_width_in = match node.get_attr("width") {
    Some(value) => @dot_shared.parse_double_or(value, fallback_width)
    None => fallback_width
  }
  let base_height_in = match node.get_attr("height") {
    Some(value) => @dot_shared.parse_double_or(value, fallback_height)
    None => fallback_height
  }
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = node_padding(node)
  let base_width_pt = base_width_in * 72.0
  let base_height_pt = base_height_in * 72.0
  if shape == "point" || shape == "dot" {
    let point_size_in = match node.get_attr("width") {
      Some(value) => @dot_shared.parse_double_or(value, fallback_width)
      None =>
        match node.get_attr("height") {
          Some(value) => @dot_shared.parse_double_or(value, fallback_height)
          None => fallback_width
        }
    }
    return @dot_shared.node_size_from_points(point_size_in * 72.0, point_size_in * 72.0)
  }
  let label = label_text(node)
  if @html_label.is_html_label_text(label) {
    match parse_html_label_cached(label) {
      Some(html_label) => {
        let html_dims = html_label_size(
          html_label, font, font_size_pt,
        )
        let padded_dims =
          apply_label_padding_for_shape(
            shape,
            html_dims.width_pt,
            html_dims.height_pt,
            padding.pad_x_pt,
            padding.pad_y_pt,
          )
        let (width_pt, height_pt) = match fixedsize_mode {
          NodeFixedSizeMode::True => (base_width_pt, base_height_pt)
          NodeFixedSizeMode::Shape => (
            if padded_dims.width_pt > base_width_pt {
              padded_dims.width_pt
            } else {
              base_width_pt
            },
            if padded_dims.height_pt > base_height_pt {
              padded_dims.height_pt
            } else {
              base_height_pt
            },
          )
          NodeFixedSizeMode::None => (
            if padded_dims.width_pt > base_width_pt {
              padded_dims.width_pt
            } else {
              base_width_pt
            },
            if padded_dims.height_pt > base_height_pt {
              padded_dims.height_pt
            } else {
              base_height_pt
            },
          )
        }
        return @dot_shared.node_size_from_points(width_pt, height_pt)
      }
      None => ()
    }
  }
  if is_record_shape(node) {
    let nodes = record_nodes(label)
    let record_size = record_group_size(
      nodes,
      record_orientation,
      font,
      font_size_pt,
      padding.pad_x_pt,
      padding.pad_y_pt,
    )
    let (width_pt, height_pt) = match fixedsize_mode {
      NodeFixedSizeMode::True => (base_width_pt, base_height_pt)
      NodeFixedSizeMode::Shape => (
        if record_size.width_pt > base_width_pt {
          record_size.width_pt
        } else {
          base_width_pt
        },
        if record_size.height_pt > base_height_pt {
          record_size.height_pt
        } else {
          base_height_pt
        },
      )
      NodeFixedSizeMode::None => (
        if record_size.width_pt > base_width_pt {
          record_size.width_pt
        } else {
          base_width_pt
        },
        if record_size.height_pt > base_height_pt {
          record_size.height_pt
        } else {
          base_height_pt
        },
      )
    }
    let bordered_height = height_pt + @dot_shared.RECORD_BORDER_PT * 2.0
    return @dot_shared.node_size_from_points(width_pt, bordered_height)
  }
  let (text_width_pt, text_height_pt) = label_text_dimensions(
    label, font, font_size_pt,
  )
  let has_label = text_width_pt > 0.0 || text_height_pt > 0.0
  let label_dims =
    if has_label {
      apply_label_padding_for_shape(
        shape,
        text_width_pt,
        text_height_pt,
        padding.pad_x_pt,
        padding.pad_y_pt,
      )
    } else {
      { width_pt: 0.0, height_pt: 0.0 }
  }
  let polygon_shape = match builtin_polygon_attrs(node, shape) {
    Some(attrs) => Some(attrs)
    None => if shape == "polygon" { Some(polygon_shape_attrs(node)) } else { None }
  }
  let mut scaled_label_width_pt = label_dims.width_pt
  let mut scaled_label_height_pt = label_dims.height_pt
  if fixedsize_mode == NodeFixedSizeMode::None {
    if polygon_shape is Some(_) && has_label {
      let polygon_attrs =
        match polygon_shape {
          Some(values) => values
          None =>
            {
              sides: 4,
              peripheries: 1,
              orientation: 0.0,
              distortion: 0.0,
              skew: 0.0,
              regular: false,
            }
        }
      let is_box = shape != "diamond" &&
        polygon_is_box_like(
          polygon_attrs.sides,
          polygon_attrs.orientation,
          polygon_attrs.distortion,
          polygon_attrs.skew,
        )
      let scaled_bbox =
        polygon_scaled_label_bbox(
          label_dims.width_pt,
          label_dims.height_pt,
          base_height_pt,
          polygon_attrs.sides,
          is_box,
        )
      scaled_label_width_pt = scaled_bbox.width_pt
      scaled_label_height_pt = scaled_bbox.height_pt
    } else if shape == "mdiamond" && has_label {
      let sqrt2 = Double::sqrt(2.0)
      let temp = label_dims.height_pt * sqrt2
      if base_height_pt > temp {
        let ratio = label_dims.height_pt / base_height_pt
        let denom = 1.0 - ratio * ratio
        if denom > 0.0 {
          let scale = Double::sqrt(1.0 / denom)
          scaled_label_width_pt = label_dims.width_pt * scale
        } else {
          scaled_label_width_pt = label_dims.width_pt * sqrt2
          scaled_label_height_pt = temp
        }
      } else {
        scaled_label_width_pt = label_dims.width_pt * sqrt2
        scaled_label_height_pt = temp
      }
      let cos_val = sqrt2 / 2.0
      scaled_label_width_pt = scaled_label_width_pt / cos_val
      scaled_label_height_pt = scaled_label_height_pt / cos_val
    } else if scale_ellipse && has_label {
      let sqrt2 = Double::sqrt(2.0)
      let temp = label_dims.height_pt * sqrt2
      if base_height_pt > temp {
        let ratio = label_dims.height_pt / base_height_pt
        let denom = 1.0 - ratio * ratio
        if denom > 0.0 {
          let scale = Double::sqrt(1.0 / denom)
          scaled_label_width_pt = label_dims.width_pt * scale
        } else {
          scaled_label_width_pt = label_dims.width_pt * sqrt2
          scaled_label_height_pt = temp
        }
      } else {
        scaled_label_width_pt = label_dims.width_pt * sqrt2
        scaled_label_height_pt = temp
      }
      scaled_label_width_pt = scaled_label_width_pt * ELLIPSE_LABEL_SCALE
      // Graphviz parity: skew/distortion polygon labels (e.g. trapezium/parallelogram)
      // expand by polygon cosine factor in shapes.c poly_init.
      let polygon_sides = match shape {
        "trapezium" | "invtrapezium" | "parallelogram" => 4
        _ => 0
      }
      if polygon_sides > 2 {
        let cos_val = @math.cos(@math.PI / polygon_sides.to_double())
        if cos_val > 0.0 {
          scaled_label_width_pt = scaled_label_width_pt / cos_val
          scaled_label_height_pt = scaled_label_height_pt / cos_val
        }
      }
    }
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
  match fixedsize_mode {
    NodeFixedSizeMode::True => {
      width_in = base_width_in
      height_in = base_height_in
    }
    NodeFixedSizeMode::Shape | NodeFixedSizeMode::None => ()
  }
  if regular_shape && fixedsize_mode != NodeFixedSizeMode::Shape {
    let size_in = if width_in > height_in { width_in } else { height_in }
    width_in = size_in
    height_in = size_in
  }
  if fixedsize_mode != NodeFixedSizeMode::Shape {
    match polygon_shape {
    Some(attrs) => {
      if attrs.regular {
        let size_in = if width_in > height_in { width_in } else { height_in }
        width_in = size_in
        height_in = size_in
      }
      let mut polygon_width_pt = width_in * 72.0
      let mut polygon_height_pt = height_in * 72.0
      if attrs.sides < 3 {
        if attrs.peripheries > 1 {
          let extra =
            PERIPHERY_GAP_PT * 2.0 * Double::from_int(attrs.peripheries - 1)
          polygon_width_pt = polygon_width_pt + extra
          polygon_height_pt = polygon_height_pt + extra
        }
      } else {
        let polygon_vertices =
          polygon_vertices_for_size(
            polygon_width_pt,
            polygon_height_pt,
            attrs.sides,
            attrs.orientation,
            attrs.distortion,
            attrs.skew,
          )
        polygon_width_pt = polygon_vertices.bbox_width_pt
        polygon_height_pt = polygon_vertices.bbox_height_pt
        if attrs.peripheries > 1 && polygon_vertices.vertices.length() > 0 {
          let outline_pad_pt =
            PERIPHERY_GAP_PT * Double::from_int(attrs.peripheries - 1)
          let expanded_vertices =
            polygon_outline_for_size(polygon_vertices.vertices, outline_pad_pt)
          let mut max_x = polygon_width_pt / 2.0
          let mut max_y = polygon_height_pt / 2.0
          for vertex in expanded_vertices {
            if Double::abs(vertex.x) > max_x {
              max_x = Double::abs(vertex.x)
            }
            if Double::abs(vertex.y) > max_y {
              max_y = Double::abs(vertex.y)
            }
          }
          polygon_width_pt = max_x * 2.0
          polygon_height_pt = max_y * 2.0
        }
      }
      width_in = polygon_width_pt / 72.0
      height_in = polygon_height_pt / 72.0
    }
    None => ()
  }
  }
  if shape == "parallelogram" && fixedsize_mode != NodeFixedSizeMode::Shape {
    // Graphviz parity: skewed quad bbox in shapes.c poly_init widens by a
    // constant factor for the built-in skew=0.6 parallelogram polygon.
    width_in = width_in * 1.0367531594794965
  }
  if shape == "box" || shape == "rect" || shape == "rectangle" {
    let mut peripheries = polygon_attr_int(node, "peripheries", 1)
    if peripheries < 0 {
      peripheries = 0
    }
    if peripheries > 1 {
      // Graphviz parity: extra box peripheries expand the node bbox by GAP on
      // both axes for each additional periphery (shapes.c poly_init).
      let gap_in =
        PERIPHERY_GAP_PT * 2.0 * Double::from_int(peripheries - 1) / 72.0
      width_in = width_in + gap_in
      height_in = height_in + gap_in
    }
  }
  if shape == "" ||
    shape == "ellipse" ||
    shape == "oval" ||
    shape == "circle" ||
    shape == "mcircle" ||
    shape == "doublecircle" {
    let default_peripheries = if shape == "doublecircle" { 2 } else { 1 }
    let mut peripheries = polygon_attr_int(node, "peripheries", default_peripheries)
    if peripheries < 0 {
      peripheries = 0
    }
    if peripheries > 1 {
      let gap_in =
        PERIPHERY_GAP_PT * 2.0 * Double::from_int(peripheries - 1) / 72.0
      width_in = width_in + gap_in
      height_in = height_in + gap_in
    }
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
