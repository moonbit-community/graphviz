///|
/// Node-size computation for plain/html/record/polygon shapes, aligned with
/// Graphviz shapes.c behavior and dot layout sizing invariants.

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
