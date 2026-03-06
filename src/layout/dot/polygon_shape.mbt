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
