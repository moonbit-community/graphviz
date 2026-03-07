///|
/// Node-size and shape-geometry kernels shared across dot stages, routing,
/// engines, and dot layout postprocess.
type RecordOrientation = @dot_shared.RecordOrientation
type NodeSize = @dot_shared.NodeSize
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
///|
/// Polygon-shape attribute and geometry helpers used by node sizing and
/// compass-port clipping in dot layout.

///|
fn attr_bool_true(value : String?) -> Bool {
  match value {
    Some(raw) =>
      match raw.to_lower() {
        "true" | "yes" | "1" => true
        _ => false
      }
    None => false
  }
}

///|
fn polygon_attr_int(node : @cgraph.Node, key : String, fallback : Int) -> Int {
  match node.get_attr(key) {
    Some(value) => @dot_shared.parse_double_or(value, fallback.to_double()).round().to_int()
    None => fallback
  }
}

///|
fn polygon_attr_double(
  node : @cgraph.Node,
  key : String,
  fallback : Double,
) -> Double {
  match node.get_attr(key) {
    Some(value) => @dot_shared.parse_double_or(value, fallback)
    None => fallback
  }
}

///|
fn polygon_shape_attrs(
  node : @cgraph.Node,
) -> PolygonShapeAttrs {
  // Graphviz parity (poly_init): polygon shape accepts explicit sides=0 which
  // keeps ellipse behavior; missing sides falls back to 4.
  let mut sides = match node.get_attr("sides") {
    Some(value) => @dot_shared.parse_double_or(value, 4.0).round().to_int()
    None => 4
  }
  if sides < 0 {
    sides = 0
  }
  let mut peripheries = polygon_attr_int(node, "peripheries", 1)
  if peripheries < 0 {
    peripheries = 0
  }
  let orientation = polygon_attr_double(node, "orientation", 0.0)
  let skew = polygon_attr_double(node, "skew", 0.0)
  let distortion = polygon_attr_double(node, "distortion", 0.0)
  if sides <= 2 && (Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001) {
    // Graphviz parity: skew/distort forces polygon fallback from ellipse to
    // high-side polygon (poly_init sides=120).
    sides = 120
  }
  let regular = attr_bool_true(node.get_attr("regular"))
  { sides, peripheries, orientation, distortion, skew, regular }
}

///|
/// Graphviz parity: built-in polygon shape defaults mirror shapes.c polygon_t.
fn builtin_polygon_shape_attrs(
  shape : String,
) -> PolygonShapeAttrs? {
  match shape {
    "diamond" => Some({
      sides: 4,
      peripheries: 1,
      orientation: 0.0,
      distortion: 0.0,
      skew: 0.0,
      regular: false,
    })
    "triangle" => Some({
      sides: 3,
      peripheries: 1,
      orientation: 0.0,
      distortion: 0.0,
      skew: 0.0,
      regular: false,
    })
    "invtriangle" => Some({
      sides: 3,
      peripheries: 1,
      orientation: 180.0,
      distortion: 0.0,
      skew: 0.0,
      regular: false,
    })
    "egg" => Some({
      sides: 120,
      peripheries: 1,
      orientation: 0.0,
      distortion: -0.3,
      skew: 0.0,
      regular: false,
    })
    "octagon" => Some({
      sides: 8,
      peripheries: 1,
      orientation: 0.0,
      distortion: 0.0,
      skew: 0.0,
      regular: false,
    })
    "doubleoctagon" => Some({
      sides: 8,
      peripheries: 2,
      orientation: 0.0,
      distortion: 0.0,
      skew: 0.0,
      regular: false,
    })
    "tripleoctagon" => Some({
      sides: 8,
      peripheries: 3,
      orientation: 0.0,
      distortion: 0.0,
      skew: 0.0,
      regular: false,
    })
    "house" => Some({
      sides: 5,
      peripheries: 1,
      orientation: 0.0,
      distortion: -0.64,
      skew: 0.0,
      regular: false,
    })
    "invhouse" => Some({
      sides: 5,
      peripheries: 1,
      orientation: 180.0,
      distortion: -0.64,
      skew: 0.0,
      regular: false,
    })
    _ => None
  }
}

///|
/// Graphviz parity: built-in polygon shapes honor peripheries/orientation attrs
/// and regular=true override (poly_init late_* flow for non-generic polygons).
fn builtin_polygon_attrs(
  node : @cgraph.Node,
  shape : String,
) -> PolygonShapeAttrs? {
  match builtin_polygon_shape_attrs(shape) {
    Some(base) => {
      let mut peripheries =
        polygon_attr_int(node, "peripheries", base.peripheries)
      if peripheries < 0 {
        peripheries = 0
      }
      let orientation =
        base.orientation + polygon_attr_double(node, "orientation", 0.0)
      let regular = base.regular || attr_bool_true(node.get_attr("regular"))
      Some({
        sides: base.sides,
        peripheries,
        orientation,
        distortion: base.distortion,
        skew: base.skew,
        regular,
      })
    }
    None => None
  }
}

///|
fn polygon_is_box_like(
  sides : Int,
  orientation : Double,
  distortion : Double,
  skew : Double,
) -> Bool {
  if sides != 4 || Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001 {
    return false
  }
  let nearest = (orientation / 90.0).round() * 90.0
  Double::abs(orientation - nearest) < 0.5
}

///|
fn polygon_scaled_label_bbox(
  label_width_pt : Double,
  label_height_pt : Double,
  base_height_pt : Double,
  sides : Int,
  is_box : Bool,
) -> ScaledLabelBBox {
  if is_box {
    return { width_pt: label_width_pt, height_pt: label_height_pt }
  }
  let sqrt2 = Double::sqrt(2.0)
  let mut bb_width = label_width_pt
  let mut bb_height = label_height_pt
  let temp = bb_height * sqrt2
  if base_height_pt > temp {
    let ratio = if base_height_pt > 0.0 { bb_height / base_height_pt } else { 0.0 }
    let denom = 1.0 - ratio * ratio
    if denom > 0.0 {
      bb_width = bb_width * Double::sqrt(1.0 / denom)
    } else {
      bb_width = bb_width * sqrt2
      bb_height = temp
    }
  } else {
    bb_width = bb_width * sqrt2
    bb_height = temp
  }
  if sides > 2 {
    let cos_val = @math.cos(@math.PI / sides.to_double())
    if cos_val > 0.0000001 {
      bb_width = bb_width / cos_val
      bb_height = bb_height / cos_val
    }
  }
  { width_pt: bb_width, height_pt: bb_height }
}

///|
priv struct PolygonShapeAttrs {
  sides : Int
  peripheries : Int
  orientation : Double
  distortion : Double
  skew : Double
  regular : Bool
}

///|
priv struct ScaledLabelBBox {
  width_pt : Double
  height_pt : Double
}

///|
priv struct PolygonVerticesResult {
  bbox_width_pt : Double
  bbox_height_pt : Double
  vertices : Array[@geom.Point]
}

///|
fn polygon_vertices_for_size(
  width_pt : Double,
  height_pt : Double,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> PolygonVerticesResult {
  if sides < 3 {
    return { bbox_width_pt: width_pt, bbox_height_pt: height_pt, vertices: [] }
  }
  if width_pt <= 0.0 || height_pt <= 0.0 {
    return { bbox_width_pt: width_pt, bbox_height_pt: height_pt, vertices: [] }
  }
  let sector = 2.0 * @math.PI / sides.to_double()
  let side_len = @math.sin(sector / 2.0)
  let abs_mix = Double::abs(distortion) + Double::abs(skew)
  let skew_dist = Double::sqrt(abs_mix * abs_mix + 1.0)
  let cos_half = @math.cos(sector / 2.0)
  if Double::abs(cos_half) <= 0.0000001 {
    return { bbox_width_pt: width_pt, bbox_height_pt: height_pt, vertices: [] }
  }
  let g_distortion = distortion * Double::sqrt(2.0) / cos_half
  let g_skew = skew / 2.0
  let mut angle = (sector - @math.PI) / 2.0
  let mut sinx = @math.sin(angle)
  let mut cosx = @math.cos(angle)
  let mut r = @edge_spline.point(0.5 * cosx, 0.5 * sinx)
  let mut max_x = 0.0
  let mut max_y = 0.0
  angle = angle + (@math.PI - sector) / 2.0
  let base : Array[@geom.Point] = []
  for _ in 0..<sides {
    angle = angle + sector
    sinx = @math.sin(angle)
    cosx = @math.cos(angle)
    r = @edge_spline.point(r.x + side_len * cosx, r.y + side_len * sinx)
    let mut px = r.x * (skew_dist + r.y * g_distortion) + r.y * g_skew
    let mut py = r.y
    let alpha = orientation_deg * @math.PI / 180.0 + @math.atan2(py, px)
    let radius = Double::sqrt(px * px + py * py)
    px = radius * @math.cos(alpha)
    py = radius * @math.sin(alpha)
    // Graphviz poly_init: compute distorted polygon extents in point space
    // before enforcing min width/height.
    px = px * width_pt
    py = py * height_pt
    if Double::abs(px) > max_x {
      max_x = Double::abs(px)
    }
    if Double::abs(py) > max_y {
      max_y = Double::abs(py)
    }
    base.push(@edge_spline.point(px, py))
  }
  if max_x <= 0.0 || max_y <= 0.0 {
    return { bbox_width_pt: width_pt, bbox_height_pt: height_pt, vertices: [] }
  }
  let xmax = max_x * 2.0
  let ymax = max_y * 2.0
  let bbox_width = if width_pt > xmax { width_pt } else { xmax }
  let bbox_height = if height_pt > ymax { height_pt } else { ymax }
  let scale_x = if xmax > 0.0 { bbox_width / xmax } else { 1.0 }
  let scale_y = if ymax > 0.0 { bbox_height / ymax } else { 1.0 }
  let out : Array[@geom.Point] = []
  for vertex in base {
    out.push(@edge_spline.point(vertex.x * scale_x, vertex.y * scale_y))
  }
  {
    bbox_width_pt: bbox_width,
    bbox_height_pt: bbox_height,
    vertices: out,
  }
}

///|
fn points_nearly_equal(a : @geom.Point, b : @geom.Point) -> Bool {
  Double::abs(a.x - b.x) <= 0.0000001 && Double::abs(a.y - b.y) <= 0.0000001
}

///|
fn polygon_outline_for_size(
  base : Array[@geom.Point],
  outline_pad_pt : Double,
) -> Array[@geom.Point] {
  if outline_pad_pt <= 0.0 || base.length() < 3 {
    return base
  }
  let sides = base.length()
  let mut prev = base[sides - 1]
  for j in 1..=sides {
    let candidate = base[(sides - j) % sides]
    if !points_nearly_equal(candidate, base[0]) {
      prev = candidate
      break
    }
  }
  let mut beta = @math.atan2(base[0].y - prev.y, base[0].x - prev.x)
  let mut prev_vertex = prev
  let mut offset_x = 0.0
  let mut offset_y = 0.0
  let out : Array[@geom.Point] = []
  for i in 0..<sides {
    let q = base[i]
    if !points_nearly_equal(q, prev_vertex) {
      let mut next = base[(i + 1) % sides]
      for j in 1..<sides {
        let candidate = base[(i + j) % sides]
        if !points_nearly_equal(candidate, q) {
          next = candidate
          break
        }
      }
      let alpha = beta
      beta = @math.atan2(next.y - q.y, next.x - q.x)
      let gamma = (alpha + @math.PI - beta) / 2.0
      let sin_gamma = @math.sin(gamma)
      if Double::abs(sin_gamma) > 0.0000001 {
        let temp = PERIPHERY_GAP_PT / sin_gamma
        offset_y = @math.sin(alpha - gamma) * temp
        offset_x = @math.cos(alpha - gamma) * temp
      }
    }
    prev_vertex = q
    out.push(
      @edge_spline.point(
        q.x + offset_x * outline_pad_pt / PERIPHERY_GAP_PT,
        q.y + offset_y * outline_pad_pt / PERIPHERY_GAP_PT,
      ),
    )
  }
  out
}
///|
/// Shape-aware compass clipping policy for dot endpoint sampling.
pub fn compass_uses_shape_clipping(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      true
    "diamond"
    | "mdiamond"
    | "triangle"
    | "invtriangle"
    | "trapezium"
    | "invtrapezium"
    | "parallelogram"
    | "egg"
    | "house"
    | "invhouse"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "doubleoctagon"
    | "tripleoctagon" =>
      true
    "polygon" => {
      let attrs = polygon_shape_attrs(node)
      if attrs.sides < 3 {
        true
      } else {
        !polygon_is_box_like(
          attrs.sides,
          attrs.orientation,
          attrs.distortion,
          attrs.skew,
        )
      }
    }
    _ => false
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
    (@dot_shared.default_point_size_in(), @dot_shared.default_point_size_in())
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
  let padding = @label_attrs.node_padding(node)
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
  let label = @label_attrs.label_text(node)
  if @html_label.is_html_label_text(label) {
    match @html_layout.parse_html_label_cached(label) {
      Some(html_label) => {
        let html_dims = @html_layout.html_label_size(
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
    let bordered_height = height_pt + @record_geometry.RECORD_BORDER_PT * 2.0
    return @dot_shared.node_size_from_points(width_pt, bordered_height)
  }
  let (text_width_pt, text_height_pt) = @label_metrics.label_text_dimensions(
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
///|

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
