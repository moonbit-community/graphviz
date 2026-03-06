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
