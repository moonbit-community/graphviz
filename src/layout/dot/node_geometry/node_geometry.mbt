// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Node-size and shape-geometry kernels shared across dot stages, routing,
/// engines, and dot layout postprocess.
type RecordOrientation = @layout_prep.RecordOrientation

///|
type NodeSize = @node_primitives.NodeSize

///|
priv struct SizePt {
  width_pt : Double
  height_pt : Double
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
      match value.trim(chars=" \n\r\t").to_owned().to_lower() {
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
    { width_pt, height_pt, }
  } else {
    { width_pt: width_pt + pad_x_pt, height_pt: height_pt + pad_y_pt, }
  }
}

///|
/// Node-size computation for plain/html/record/polygon shapes, aligned with
/// Graphviz shapes.c behavior and dot layout sizing invariants.

///|
pub fn node_size(
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  node_size_and_label_space(node, record_orientation).0
}

///|
/// Horizontal justification space computed before polygon outline expansion.
/// Record and HTML labels have their own field/cell layout and return None.
pub fn node_label_space(node : @cgraph.Node) -> Double? {
  node_size_and_label_space(node, RecordOrientation::Horizontal).1
}

///|
/// Vertical displacement for top/bottom plain labels, before outline expansion.
pub fn node_label_y_offset(node : @cgraph.Node) -> Double {
  let location = node.get_attr("labelloc").unwrap_or_default()
  guard location.has_prefix("t") || location.has_prefix("b") else { return 0.0 }
  node_size_and_label_space(node, RecordOrientation::Horizontal).2
}

///|
fn node_size_and_label_space(
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> (NodeSize, Double?, Double) {
  let fixedsize_mode = node_fixedsize_mode(node)
  let location = node.get_attr("labelloc").unwrap_or_default()
  let centered_label = !location.has_prefix("t") && !location.has_prefix("b")
  let shape = geometry_shape_name(
    node.get_attr("shape").unwrap_or_default().to_lower(),
  )
  let regular_shape = shape == "msquare" ||
    shape == "square" ||
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
    (
      @node_primitives.default_point_size_in(),
      @node_primitives.default_point_size_in(),
    )
  } else if regular_shape {
    let height = @node_primitives.default_node_height_in()
    (height, height)
  } else {
    (
      @node_primitives.default_node_width_in(),
      @node_primitives.default_node_height_in(),
    )
  }
  let base_width_in = match node.get_attr("width") {
    Some(value) => @numeric.parse_double_or(value, fallback_width)
    None => fallback_width
  }
  let base_height_in = match node.get_attr("height") {
    Some(value) => @numeric.parse_double_or(value, fallback_height)
    None => fallback_height
  }
  // poly_init/userSize compares explicitly supplied dimensions, not a
  // supplied width against the default height (or vice versa).
  let (base_width_in, base_height_in) = if regular_shape {
    let supplied_width = node
      .get_attr("width")
      .map_or(0.0, value => @numeric.parse_attr_double(value, 0.0, 0.01))
    let supplied_height = node
      .get_attr("height")
      .map_or(0.0, value => @numeric.parse_attr_double(value, 0.0, 0.02))
    let supplied_size = Double::max(supplied_width, supplied_height)
    let size = if supplied_size > 0.0 {
      supplied_size
    } else {
      Double::min(base_width_in, base_height_in)
    }
    (size, size)
  } else {
    (base_width_in, base_height_in)
  }
  let font_size_pt = @attrs.font_size(node.get_attr("fontsize"))
  let font = @attrs.font_name(node.get_attr("fontname"))
  let padding = @label_attrs.node_padding(node)
  let base_width_pt = base_width_in * 72.0
  let base_height_pt = base_height_in * 72.0
  if shape == "point" || shape == "dot" {
    let point_size_in = match node.get_attr("width") {
      Some(value) => @numeric.parse_double_or(value, fallback_width)
      None =>
        match node.get_attr("height") {
          Some(value) => @numeric.parse_double_or(value, fallback_height)
          None => fallback_width
        }
    }
    return (
      @node_primitives.node_size_from_points(
        point_size_in * 72.0,
        point_size_in * 72.0,
      ),
      None,
      0.0,
    )
  }
  let label = @label_attrs.label_text(node)
  let html = node
    .get_attr_value("label")
    .map(value => value is @cgraph.AttrValue::Html(_))
  if html.unwrap_or_else(() => @html_label.is_html_label_text(label)) {
    match @html_layout.parse_html_label_cached(label, html~) {
      Some(html_label) => {
        let html_dims = @html_layout.html_label_size(
          html_label, font, font_size_pt,
        )
        let padded_dims = apply_label_padding_for_shape(
          shape,
          html_dims.width_pt,
          html_dims.height_pt,
          padding.pad_x_pt,
          padding.pad_y_pt,
        )
        let mut label_width_pt = padded_dims.width_pt
        let mut label_height_pt = padded_dims.height_pt
        if fixedsize_mode == NodeFixedSizeMode::None && scale_ellipse {
          let sqrt2 = Double::sqrt(2.0)
          let scaled_height = label_height_pt * sqrt2
          if base_height_pt > scaled_height && centered_label {
            let ratio = label_height_pt / base_height_pt
            let denominator = 1.0 - ratio * ratio
            if denominator > 0.0 {
              label_width_pt = label_width_pt * Double::sqrt(1.0 / denominator)
            } else {
              label_width_pt = label_width_pt * sqrt2
              label_height_pt = scaled_height
            }
          } else {
            label_width_pt = label_width_pt * sqrt2
            label_height_pt = scaled_height
          }
        }
        let mut width_pt = if label_width_pt > base_width_pt {
          label_width_pt
        } else {
          base_width_pt
        }
        let mut height_pt = if label_height_pt > base_height_pt {
          label_height_pt
        } else {
          base_height_pt
        }
        if fixedsize_mode == NodeFixedSizeMode::True {
          width_pt = base_width_pt
          height_pt = base_height_pt
        }
        if regular_shape && fixedsize_mode != NodeFixedSizeMode::Shape {
          let size_pt = if width_pt > height_pt { width_pt } else { height_pt }
          width_pt = size_pt
          height_pt = size_pt
        }
        if (shape == "box" || shape == "rect" || shape == "rectangle") &&
          polygon_attr_int(node, "peripheries", 1) >= 1 &&
          polygon_attr_double(node, "penwidth", 1.0) > 0.0 {
          let extent = box_vertex_extent(width_pt, height_pt)
          width_pt = extent.width_pt
          height_pt = extent.height_pt
        }
        return (
          @node_primitives.node_size_from_points(width_pt, height_pt),
          None,
          0.0,
        )
      }
      None => ()
    }
  }
  if @record_geometry.is_record_shape(node) {
    let nodes = @record_layout.record_nodes(label)
    let record_size = @record_layout.record_group_size(
      nodes,
      record_orientation,
      font,
      font_size_pt,
      padding.pad_x_pt,
      padding.pad_y_pt,
    )
    let (width_pt, height_pt) = match fixedsize_mode {
      NodeFixedSizeMode::True => (base_width_pt, base_height_pt)
      NodeFixedSizeMode::Shape =>
        (
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
      NodeFixedSizeMode::None =>
        (
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
    let bordered_height = height_pt + @record_geometry.RECORD_BORDER_PT * 2.0
    return (
      @node_primitives.node_size_from_points(width_pt, bordered_height),
      None,
      0.0,
    )
  }
  let simple_label = @label_attrs.simple_label_text(node)
  let (text_width_pt, text_height_pt) = @label_metrics.label_text_dimensions(
    simple_label, font, font_size_pt,
  )
  let has_label = text_width_pt > 0.0 || text_height_pt > 0.0
  let label_dims = if has_label {
    apply_label_padding_for_shape(
      shape,
      text_width_pt,
      text_height_pt,
      padding.pad_x_pt,
      padding.pad_y_pt,
    )
  } else {
    { width_pt: 0.0, height_pt: 0.0, }
  }
  let polygon_shape = match builtin_polygon_attrs(node, shape) {
    Some(attrs) => Some(attrs)
    None =>
      if shape == "polygon" {
        Some(polygon_shape_attrs(node))
      } else {
        None
      }
  }
  let mut scaled_label_width_pt = label_dims.width_pt
  let mut scaled_label_height_pt = label_dims.height_pt
  if fixedsize_mode == NodeFixedSizeMode::None {
    if polygon_shape is Some(_) && has_label {
      let polygon_attrs = match polygon_shape {
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
      let scaled_bbox = polygon_scaled_label_bbox(
        label_dims.width_pt,
        label_dims.height_pt,
        base_height_pt,
        polygon_attrs.sides,
        is_box,
        centered_label,
      )
      scaled_label_width_pt = scaled_bbox.width_pt
      scaled_label_height_pt = scaled_bbox.height_pt
    } else if shape == "mdiamond" && has_label {
      let sqrt2 = Double::sqrt(2.0)
      let temp = label_dims.height_pt * sqrt2
      if base_height_pt > temp && centered_label {
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
      if base_height_pt > temp && centered_label {
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
  let vertical_space = if fixedsize_mode == NodeFixedSizeMode::Shape {
    text_height_pt
  } else {
    label_dims.height_pt + height_in * 72.0 - scaled_label_height_pt
  }
  let label_y_offset = if location.has_prefix("t") {
    (vertical_space - text_height_pt) / 2.0
  } else if location.has_prefix("b") {
    (text_height_pt - vertical_space) / 2.0
  } else {
    0.0
  }
  let label_space = if @attrs.graphviz_bool(node.get_attr("nojustify")) {
    text_width_pt
  } else {
    let is_box = polygon_shape.map_or(!scale_ellipse && shape != "mdiamond", attrs => {
      shape != "diamond" &&
      polygon_is_box_like(
        attrs.sides,
        attrs.orientation,
        attrs.distortion,
        attrs.skew,
      )
    })
    let regular_polygon = regular_shape ||
      polygon_shape.map_or(false, attrs => attrs.regular)
    let label_box_width = if fixedsize_mode == NodeFixedSizeMode::Shape {
      base_width_in
    } else {
      width_in
    }
    let label_box_height = if fixedsize_mode == NodeFixedSizeMode::Shape {
      base_height_in
    } else {
      height_in
    }
    let bb_width = if regular_polygon {
      Double::max(label_box_width, label_box_height) * 72.0
    } else {
      label_box_width * 72.0
    }
    let bb_height = if regular_polygon {
      Double::max(label_box_width, label_box_height) * 72.0
    } else {
      label_box_height * 72.0
    }
    let available = if is_box {
      bb_width
    } else if label_dims.height_pt < bb_height {
      let ratio = label_dims.height_pt / bb_height
      bb_width * Double::sqrt(1.0 - ratio * ratio)
    } else {
      label_dims.width_pt
    }
    Double::max(label_dims.width_pt, available) -
    (label_dims.width_pt - text_width_pt)
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
            let extra = PERIPHERY_GAP_PT *
              2.0 *
              Double::from_int(attrs.peripheries - 1)
            polygon_width_pt = polygon_width_pt + extra
            polygon_height_pt = polygon_height_pt + extra
          }
        } else {
          let polygon_vertices = polygon_vertices_for_size(
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
            let outline_pad_pt = PERIPHERY_GAP_PT *
              Double::from_int(attrs.peripheries - 1)
            let expanded_vertices = polygon_outline_for_size(
              polygon_vertices.vertices,
              outline_pad_pt,
            )
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
      let gap_in = PERIPHERY_GAP_PT *
        2.0 *
        Double::from_int(peripheries - 1) /
        72.0
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
    let mut peripheries = polygon_attr_int(
      node, "peripheries", default_peripheries,
    )
    if peripheries < 0 {
      peripheries = 0
    }
    if peripheries > 1 {
      let gap_in = PERIPHERY_GAP_PT *
        2.0 *
        Double::from_int(peripheries - 1) /
        72.0
      width_in = width_in + gap_in
      height_in = height_in + gap_in
    }
  }
  let width_pt = width_in * 72.0
  let half = width_pt / 2.0
  (
    {
      width_in,
      height_in,
      width_pt,
      height_pt: height_in * 72.0,
      left_pt: half,
      right_pt: half,
    },
    Some(label_space),
    label_y_offset,
  )
}

///|

///|

///|
/// Graphviz parity: output-size lookup prefers precomputed output sizes and
/// falls back to node geometry calculation when a node is not present.
pub fn resolve_node_output_size(
  output_sizes : Map[String, NodeSize],
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  let name = node.name()
  match output_sizes.get(name) {
    Some(value) => value
    None => node_size(node, record_orientation)
  }
}

///|
const PERIPHERY_GAP_PT : Double = 4.0

///|
pub const SELF_EDGE_SIZE_PT : Double = 18.0

///|
pub const EDGE_LABEL_PAD_WIDTH_PT : Double = 100.0

///|
pub const EDGE_LABEL_FLAT_SPACE_PT : Double = 6.0

///|
pub const PORT_LABEL_DISTANCE_PT : Double = 10.0

///|
pub const GRAPHVIZ_PI : Double = 3.14159265358979323846

///|
pub const PORT_LABEL_ANGLE_DEG : Double = -25.0

///|
pub const PORT_LABEL_ANGLE_MIN_DEG : Double = -180.0

///|
const ELLIPSE_LABEL_SCALE : Double = 1.0
