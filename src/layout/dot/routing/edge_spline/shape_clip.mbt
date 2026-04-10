// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Shape clipping domain for edge splines: fixed-size shape bounds, inside
/// tests, node clipping, and compass-port projection on shapes.
fn fixedsize_mode(node : @cgraph.Node) -> String {
  match node.get_attr("fixedsize") {
    Some(value) => value.trim(chars=" \n\r\t").to_string().to_lower()
    None => ""
  }
}

///|
fn fixedshape_clip_size(node : @cgraph.Node, fallback : NodeSize) -> NodeSize {
  if fixedsize_mode(node) != "shape" {
    return fallback
  }
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  let regular_shape = shape == "msquare" ||
    shape == "mcircle" ||
    shape == "circle" ||
    shape == "doublecircle"
  let (fallback_width, fallback_height) = if shape == "point" || shape == "dot" {
    let point = @node_primitives.default_node_width_in()
    (point, point)
  } else if regular_shape {
    let height = @node_primitives.default_node_height_in()
    (height, height)
  } else {
    (
      @node_primitives.default_node_width_in(),
      @node_primitives.default_node_height_in(),
    )
  }
  let mut width_in = match node.get_attr("width") {
    Some(value) => @numeric.parse_double_or(value, fallback_width)
    None => fallback_width
  }
  let mut height_in = match node.get_attr("height") {
    Some(value) => @numeric.parse_double_or(value, fallback_height)
    None => fallback_height
  }
  if shape == "point" || shape == "dot" {
    let point_size_in = match node.get_attr("width") {
      Some(value) => @numeric.parse_double_or(value, fallback_width)
      None =>
        match node.get_attr("height") {
          Some(value) => @numeric.parse_double_or(value, fallback_height)
          None => fallback_width
        }
    }
    return @node_primitives.node_size_from_points(
      point_size_in * 72.0,
      point_size_in * 72.0,
    )
  }
  if regular_shape {
    let size_in = if width_in > height_in { width_in } else { height_in }
    width_in = size_in
    height_in = size_in
  }
  if shape == "doublecircle" {
    let gap_in = POLY_GAP_PT * 2.0 / 72.0
    width_in = width_in + gap_in
    height_in = height_in + gap_in
  }
  @node_primitives.node_size_from_points(width_in * 72.0, height_in * 72.0)
}

///|
priv enum ClipShape {
  None
  Rect
  Ellipse
  Polygon(Int, Double, Double, Double, Int)
  DoubleOctagon
  TripleOctagon
  Trapezium
  InvTrapezium
  Parallelogram
  House
  InvHouse
}

///|
fn node_penwidth_pt(node : @cgraph.Node) -> Double {
  match node.get_attr("penwidth") {
    Some(value) => @numeric.parse_double_or(value, 1.0)
    None => 1.0
  }
}

///|
/// Graphviz parity: plain/plaintext/none have no stroked border, so clipping must not inflate by penwidth.
fn shape_has_outline(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  if shape == "none" || shape == "plaintext" || shape == "plain" {
    return false
  }
  polygon_peripheries(node, 1) > 0
}

///|
fn inflate_node_size(size : NodeSize, pad_pt : Double) -> NodeSize {
  if pad_pt <= 0.0 {
    return size
  }
  let width_pt = size.width_pt + pad_pt * 2.0
  let height_pt = size.height_pt + pad_pt * 2.0
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}

///|
fn graph_rankdir_quadrant(edge : @cgraph.Edge) -> Int {
  let mut graph = edge.tail().graph()
  while true {
    match graph.parent() {
      Some(parent) => graph = parent
      None => break
    }
  }
  let rankdir = match graph.get_attr("rankdir") {
    Some(value) => value.to_lower()
    None => ""
  }
  match rankdir {
    "lr" => 1
    "bt" => 2
    "rl" => 3
    _ => 0
  }
}

///|
fn trim_record_border_for_clip(
  size : NodeSize,
  rankdir_lr_rl : Bool,
) -> NodeSize {
  let trim = RECORD_BORDER_PT * 2.0
  if trim <= 0.0 {
    return size
  }
  if rankdir_lr_rl {
    // Graphviz parity: for LR/RL, record_inside rotates probe points before
    // testing the inner record bbox; in layout coords this trims X by border.
    let width_pt = if size.width_pt > trim { size.width_pt - trim } else { 0.0 }
    let half = width_pt / 2.0
    {
      width_in: width_pt / 72.0,
      height_in: size.height_in,
      width_pt,
      height_pt: size.height_pt,
      left_pt: half,
      right_pt: half,
    }
  } else {
    // Graphviz record shapes store ND_height with a +1pt render kluge.
    // record_inside clips against the pre-kluge field bbox, so strip the
    // border term on Y before adding penwidth during clipping.
    let height_pt = if size.height_pt > trim {
      size.height_pt - trim
    } else {
      0.0
    }
    {
      width_in: size.width_in,
      height_in: height_pt / 72.0,
      width_pt: size.width_pt,
      height_pt,
      left_pt: size.left_pt,
      right_pt: size.right_pt,
    }
  }
}

///|
priv struct PolygonClipParams {
  sides : Int
  orientation : Double
  distortion : Double
  skew : Double
}

///|
fn polygon_clip_params(node : @cgraph.Node) -> PolygonClipParams {
  // Graphviz parity (poly_init): explicit sides=0 keeps ellipse mode unless
  // skew/distortion force high-sided polygon fallback.
  let mut sides = match node.get_attr("sides") {
    Some(value) => @numeric.parse_double_or(value, 4.0).round().to_int()
    None => 4
  }
  if sides < 0 {
    sides = 0
  }
  let orientation = match node.get_attr("orientation") {
    Some(value) => @numeric.parse_double_or(value, 0.0)
    None => 0.0
  }
  let distortion = match node.get_attr("distortion") {
    Some(value) => @numeric.parse_double_or(value, 0.0)
    None => 0.0
  }
  let skew = match node.get_attr("skew") {
    Some(value) => @numeric.parse_double_or(value, 0.0)
    None => 0.0
  }
  if sides <= 2 &&
    (Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001) {
    sides = 120
  }
  { sides, orientation, distortion, skew }
}

///|
fn polygon_peripheries(node : @cgraph.Node, default : Int) -> Int {
  let mut peripheries = match node.get_attr("peripheries") {
    Some(value) =>
      @numeric.parse_double_or(value, default.to_double()).round().to_int()
    None => default
  }
  if peripheries < 0 {
    peripheries = 0
  }
  peripheries
}

///|
fn builtin_polygon_clip_params(
  node : @cgraph.Node,
  shape : String,
) -> PolygonClipParams? {
  let (sides, default_orientation, default_distortion, default_skew) = match
    shape {
    "triangle" => (3, 0.0, 0.0, 0.0)
    "invtriangle" => (3, 180.0, 0.0, 0.0)
    "pentagon" => (5, 0.0, 0.0, 0.0)
    "hexagon" => (6, 0.0, 0.0, 0.0)
    "septagon" => (7, 0.0, 0.0, 0.0)
    "octagon" => (8, 0.0, 0.0, 0.0)
    "egg" => (120, 0.0, -0.3, 0.0)
    _ => return None
  }
  let orientation = match node.get_attr("orientation") {
    Some(value) => @numeric.parse_double_or(value, default_orientation)
    None => default_orientation
  }
  let distortion = match node.get_attr("distortion") {
    Some(value) => @numeric.parse_double_or(value, default_distortion)
    None => default_distortion
  }
  let skew = match node.get_attr("skew") {
    Some(value) => @numeric.parse_double_or(value, default_skew)
    None => default_skew
  }
  Some({ sides, orientation, distortion, skew })
}

///|

///|

///|

///|
/// Graphviz parity: clip_shape_kind mirrors shape clipping in refs/graphviz/lib/common/shapes.c.
fn clip_shape_kind(node : @cgraph.Node, port : @cgraph.Port?) -> ClipShape {
  if @edge_identity.port_is_explicit(port) &&
    @record_geometry.is_record_shape(node) {
    return ClipShape::Rect
  }
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" => ClipShape::Ellipse
    "box"
    | "rect"
    | "rectangle"
    | "record"
    | "mrecord"
    | "msquare"
    | "rpromoter"
    | "lpromoter"
    | "rarrow"
    | "larrow"
    | "plaintext"
    | "plain" => ClipShape::Rect
    "diamond" =>
      ClipShape::Polygon(4, 45.0, 0.0, 0.0, polygon_peripheries(node, 1))
    "mdiamond" =>
      ClipShape::Polygon(4, 45.0, 0.0, 0.0, polygon_peripheries(node, 1))
    "polygon" => {
      let params = polygon_clip_params(node)
      if params.sides < 3 {
        ClipShape::Ellipse
      } else {
        ClipShape::Polygon(
          params.sides,
          params.orientation,
          params.distortion,
          params.skew,
          polygon_peripheries(node, 1),
        )
      }
    }
    "triangle"
    | "invtriangle"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "egg" =>
      match builtin_polygon_clip_params(node, shape) {
        Some(params) =>
          ClipShape::Polygon(
            params.sides,
            params.orientation,
            params.distortion,
            params.skew,
            polygon_peripheries(node, 1),
          )
        None => ClipShape::None
      }
    "doubleoctagon" => ClipShape::DoubleOctagon
    "tripleoctagon" => ClipShape::TripleOctagon
    "trapezium" => ClipShape::Trapezium
    "invtrapezium" => ClipShape::InvTrapezium
    "parallelogram" => ClipShape::Parallelogram
    "house" => ClipShape::House
    "invhouse" => ClipShape::InvHouse
    "none" => ClipShape::Rect
    "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      ClipShape::Ellipse
    // Graphviz fallback for unrecognized shapes is box-like clipping.
    _ => ClipShape::Rect
  }
}

///|
fn point_inside_rect(
  point : @geom.Point,
  center : @geom.Point,
  size : NodeSize,
) -> Bool {
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  let dx = Double::abs(point.x - center.x)
  let dy = Double::abs(point.y - center.y)
  dx <= half_w && dy <= half_h
}

///|
fn point_inside_ellipse(
  point : @geom.Point,
  center : @geom.Point,
  size : NodeSize,
) -> Bool {
  let rx = size.width_pt / 2.0
  let ry = size.height_pt / 2.0
  if rx <= 0.0 || ry <= 0.0 {
    return false
  }
  let dx = (point.x - center.x) / rx
  let dy = (point.y - center.y) / ry
  // Graphviz parity: poly_inside uses strict < for ellipses (shapes.c).
  dx * dx + dy * dy < 1.0
}

///|
fn rotate_ccw_quadrant(pt : @geom.Point, quadrant : Int) -> @geom.Point {
  match quadrant {
    1 => point(-pt.y, pt.x)
    2 => point(-pt.x, -pt.y)
    3 => point(pt.y, -pt.x)
    _ => pt
  }
}

///|
priv struct PolygonShapeParams {
  sides : Int
  orientation_deg : Double
  distortion : Double
  skew : Double
  peripheries : Int
}

///|
fn polygon_shape_params(shape : ClipShape) -> PolygonShapeParams? {
  match shape {
    ClipShape::Polygon(sides, orientation, distortion, skew, peripheries) =>
      Some({
        sides,
        orientation_deg: orientation,
        distortion,
        skew,
        peripheries,
      })
    ClipShape::DoubleOctagon =>
      Some({
        sides: 8,
        orientation_deg: 0.0,
        distortion: 0.0,
        skew: 0.0,
        peripheries: 2,
      })
    ClipShape::TripleOctagon =>
      Some({
        sides: 8,
        orientation_deg: 0.0,
        distortion: 0.0,
        skew: 0.0,
        peripheries: 3,
      })
    ClipShape::Trapezium =>
      Some({
        sides: 4,
        orientation_deg: 0.0,
        distortion: -0.4,
        skew: 0.0,
        peripheries: 1,
      })
    ClipShape::InvTrapezium =>
      Some({
        sides: 4,
        orientation_deg: 180.0,
        distortion: -0.4,
        skew: 0.0,
        peripheries: 1,
      })
    ClipShape::Parallelogram =>
      Some({
        sides: 4,
        orientation_deg: 0.0,
        distortion: 0.0,
        skew: 0.6,
        peripheries: 1,
      })
    ClipShape::House =>
      Some({
        sides: 5,
        orientation_deg: 0.0,
        distortion: -0.64,
        skew: 0.0,
        peripheries: 1,
      })
    ClipShape::InvHouse =>
      Some({
        sides: 5,
        orientation_deg: 180.0,
        distortion: -0.64,
        skew: 0.0,
        peripheries: 1,
      })
    _ => None
  }
}

///|
/// Graphviz parity: rebuild built-in polygon vertices from shapes.c poly_init
/// (sides/distortion/skew/orientation), then scale to current node extents.
fn polygon_vertices_for_shape(
  size : NodeSize,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> Array[@geom.Point] {
  if sides < 3 {
    return []
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  if half_w <= 0.0 || half_h <= 0.0 {
    return []
  }
  let sector = 2.0 * @math.PI / sides.to_double()
  let side_len = @math.sin(sector / 2.0)
  let abs_mix = Double::abs(distortion) + Double::abs(skew)
  let skew_dist = Double::sqrt(abs_mix * abs_mix + 1.0)
  let cos_half = @math.cos(sector / 2.0)
  if Double::abs(cos_half) <= 0.0000001 {
    return []
  }
  let g_distortion = distortion * Double::sqrt(2.0) / cos_half
  let g_skew = skew / 2.0
  let mut angle = (sector - @math.PI) / 2.0
  let mut sinx = @math.sin(angle)
  let mut cosx = @math.cos(angle)
  let mut r = point(0.5 * cosx, 0.5 * sinx)
  let mut xmax = 0.0
  let mut ymax = 0.0
  angle = angle + (@math.PI - sector) / 2.0
  let base : Array[@geom.Point] = []
  for _ in 0..<sides {
    angle = angle + sector
    sinx = @math.sin(angle)
    cosx = @math.cos(angle)
    r = point(r.x + side_len * cosx, r.y + side_len * sinx)
    let mut px = r.x * (skew_dist + r.y * g_distortion) + r.y * g_skew
    let mut py = r.y
    let alpha = orientation_deg * @math.PI / 180.0 + @math.atan2(py, px)
    let radius = Double::sqrt(px * px + py * py)
    px = radius * @math.cos(alpha)
    py = radius * @math.sin(alpha)
    if Double::abs(px) > xmax {
      xmax = Double::abs(px)
    }
    if Double::abs(py) > ymax {
      ymax = Double::abs(py)
    }
    base.push(point(px, py))
  }
  if xmax <= 0.0 || ymax <= 0.0 {
    return []
  }
  let scale_x = half_w / xmax
  let scale_y = half_h / ymax
  let out : Array[@geom.Point] = []
  for vertex in base {
    out.push(point(vertex.x * scale_x, vertex.y * scale_y))
  }
  out
}

///|
fn point_nearly_equal(a : @geom.Point, b : @geom.Point) -> Bool {
  Double::abs(a.x - b.x) <= 0.0000001 && Double::abs(a.y - b.y) <= 0.0000001
}

///|
/// Graphviz parity: polygon outline for clipping follows poly_init bisector
/// expansion with GAP=4 and extra penwidth/2 (shapes.c).
fn polygon_outline_vertices(
  base : Array[@geom.Point],
  outline_pad_pt : Double,
) -> Array[@geom.Point] {
  if outline_pad_pt <= 0.0 || base.length() < 3 {
    return base
  }
  let sides = base.length()
  let mut prev = base[sides - 1]
  for j in 1..<=sides {
    let candidate = base[(sides - j) % sides]
    if !point_nearly_equal(candidate, base[0]) {
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
    if !point_nearly_equal(q, prev_vertex) {
      let mut next = base[(i + 1) % sides]
      for j in 1..<sides {
        let candidate = base[(i + j) % sides]
        if !point_nearly_equal(candidate, q) {
          next = candidate
          break
        }
      }
      let alpha = beta
      beta = @math.atan2(next.y - q.y, next.x - q.x)
      let gamma = (alpha + @math.PI - beta) / 2.0
      let sin_gamma = @math.sin(gamma)
      if Double::abs(sin_gamma) > 0.0000001 {
        let temp = POLY_GAP_PT / sin_gamma
        offset_y = @math.sin(alpha - gamma) * temp
        offset_x = @math.cos(alpha - gamma) * temp
      }
    }
    prev_vertex = q
    out.push(
      point(
        q.x + offset_x * outline_pad_pt / POLY_GAP_PT,
        q.y + offset_y * outline_pad_pt / POLY_GAP_PT,
      ),
    )
  }
  out
}

///|
fn polygon_outline_vertices_for_shape(
  size : NodeSize,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
  peripheries : Int,
  outline_pad_pt : Double,
) -> Array[@geom.Point] {
  let base_outline_pad = if peripheries > 1 {
    POLY_GAP_PT * Double::from_int(peripheries - 1)
  } else {
    0.0
  }
  if size.width_pt <= 0.0 || size.height_pt <= 0.0 {
    return []
  }
  if base_outline_pad <= 0.0 {
    let base = polygon_vertices_for_shape(
      size, sides, orientation_deg, distortion, skew,
    )
    return polygon_outline_vertices(base, outline_pad_pt)
  }
  let target_w = size.width_pt
  let target_h = size.height_pt
  let mut inner_w = target_w
  let mut inner_h = target_h
  let shrink = base_outline_pad * 2.0
  if inner_w > shrink {
    inner_w = inner_w - shrink
  } else {
    inner_w = target_w * 0.5
  }
  if inner_h > shrink {
    inner_h = inner_h - shrink
  } else {
    inner_h = target_h * 0.5
  }
  for _ in 0..<8 {
    if inner_w <= 0.0 || inner_h <= 0.0 {
      break
    }
    let inner_size = @node_primitives.node_size_from_points(inner_w, inner_h)
    let base = polygon_vertices_for_shape(
      inner_size, sides, orientation_deg, distortion, skew,
    )
    if base.length() < 3 {
      break
    }
    let expanded = polygon_outline_vertices(base, base_outline_pad)
    let mut max_x = 0.0
    let mut max_y = 0.0
    for vertex in expanded {
      if Double::abs(vertex.x) > max_x {
        max_x = Double::abs(vertex.x)
      }
      if Double::abs(vertex.y) > max_y {
        max_y = Double::abs(vertex.y)
      }
    }
    if max_x <= 0.0 || max_y <= 0.0 {
      break
    }
    inner_w = inner_w * (target_w / (max_x * 2.0))
    inner_h = inner_h * (target_h / (max_y * 2.0))
  }
  let final_size = @node_primitives.node_size_from_points(inner_w, inner_h)
  let final_base = polygon_vertices_for_shape(
    final_size, sides, orientation_deg, distortion, skew,
  )
  if final_base.length() < 3 {
    return final_base
  }
  polygon_outline_vertices(final_base, base_outline_pad + outline_pad_pt)
}

///|
fn point_in_convex_polygon(
  point : @geom.Point,
  vertices : Array[@geom.Point],
) -> Bool {
  if vertices.length() < 3 {
    return false
  }
  let mut sign = 0
  for i in 0..<vertices.length() {
    let a = vertices[i]
    let b = vertices[(i + 1) % vertices.length()]
    let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
    if Double::abs(cross) <= 0.000001 {
      continue
    }
    let current = if cross > 0.0 { 1 } else { -1 }
    if sign == 0 {
      sign = current
    } else if sign != current {
      return false
    }
  }
  true
}

///|
/// Graphviz parity: polygon outline geometry is fixed for a given
/// shape/size/rankdir tuple, so repeated inside tests in one clip pass can
/// reuse the same outline vertices.
fn build_point_inside_shape_fn(
  center : @geom.Point,
  size : NodeSize,
  shape : ClipShape,
  rankdir_quadrant : Int,
  outline_pad_pt : Double,
) -> (@geom.Point) -> Bool {
  match shape {
    ClipShape::Rect => (probe_point) => point_inside_rect(probe_point, center, size)
    ClipShape::Ellipse =>
      (probe_point) => point_inside_ellipse(probe_point, center, size)
    ClipShape::Trapezium
    | ClipShape::InvTrapezium
    | ClipShape::Parallelogram
    | ClipShape::House
    | ClipShape::InvHouse
    | ClipShape::DoubleOctagon
    | ClipShape::TripleOctagon
    | ClipShape::Polygon(_, _, _, _, _) =>
      match polygon_shape_params(shape) {
        Some(params) => {
          let polygon_size = if rankdir_quadrant == 1 || rankdir_quadrant == 3 {
            @node_primitives.node_size_from_points(size.height_pt, size.width_pt)
          } else {
            size
          }
          let vertices = polygon_outline_vertices_for_shape(
            polygon_size,
            params.sides,
            params.orientation_deg,
            params.distortion,
            params.skew,
            params.peripheries,
            outline_pad_pt,
          )
          (probe_point) => {
            let rel = point(
              probe_point.x - center.x,
              probe_point.y - center.y,
            )
            let probe = rotate_ccw_quadrant(rel, rankdir_quadrant)
            point_in_convex_polygon(probe, vertices)
          }
        }
        None => (_point) => false
      }
    ClipShape::None => (_point) => false
  }
}

///|
fn clip_spline_start(
  points : Array[@geom.Point],
  center : @geom.Point,
  size : NodeSize,
  shape : ClipShape,
  rankdir_quadrant : Int,
  outline_pad_pt : Double,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  match shape {
    ClipShape::None => return points
    _ => ()
  }
  let inside = build_point_inside_shape_fn(
    center,
    size,
    shape,
    rankdir_quadrant,
    outline_pad_pt,
  )
  let mut start = 0
  while start + 3 < points.length() && inside(points[start + 3]) {
    start += 3
  }
  // Graphviz parity: clip even if the endpoint is on the boundary.
  if start + 3 >= points.length() {
    return points
  }
  let out = if start == 0 {
    points.copy()
  } else {
    let trimmed : Array[@geom.Point] = []
    let mut idx = start
    while idx < points.length() {
      trimmed.push(points[idx])
      idx = idx + 1
    }
    trimmed
  }
  let segment : Array[@geom.Point] = [out[0], out[1], out[2], out[3]]
  let clipped = bezier_clip(segment, inside, true)
  out[0] = clipped[0]
  out[1] = clipped[1]
  out[2] = clipped[2]
  out[3] = clipped[3]
  out
}

///|
fn clip_spline_end(
  points : Array[@geom.Point],
  center : @geom.Point,
  size : NodeSize,
  shape : ClipShape,
  rankdir_quadrant : Int,
  outline_pad_pt : Double,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  match shape {
    ClipShape::None => return points
    _ => ()
  }
  let inside = build_point_inside_shape_fn(
    center,
    size,
    shape,
    rankdir_quadrant,
    outline_pad_pt,
  )
  let mut end = points.length() - 4
  while end > 0 && inside(points[end]) {
    end -= 3
  }
  // Graphviz parity: clip even if the endpoint is on the boundary.
  if end + 3 >= points.length() {
    return points
  }
  let keep_len = end + 4
  let out = if keep_len == points.length() {
    points.copy()
  } else {
    let trimmed : Array[@geom.Point] = []
    let mut idx = 0
    while idx < keep_len {
      trimmed.push(points[idx])
      idx = idx + 1
    }
    trimmed
  }
  let last = out.length() - 4
  let segment : Array[@geom.Point] = [
    out[last],
    out[last + 1],
    out[last + 2],
    out[last + 3],
  ]
  let clipped = bezier_clip(segment, inside, false)
  out[last] = clipped[0]
  out[last + 1] = clipped[1]
  out[last + 2] = clipped[2]
  out[last + 3] = clipped[3]
  out
}

///|
fn clip_spline_to_nodes(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
  tail_clip_center : @geom.Point,
  tail_size : NodeSize,
  head_clip_center : @geom.Point,
  head_size : NodeSize,
  tail_port_side? : Int = 0,
  head_port_side? : Int = 0,
  tail_clip_enabled_override~ : Bool?,
  head_clip_enabled_override~ : Bool?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
  clip_swapped? : Bool = false,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  let (tail_node, head_node, tail_port, head_port) = if clip_swapped {
    (edge.head(), edge.tail(), edge.head_port(), edge.tail_port())
  } else {
    (edge.tail(), edge.head(), edge.tail_port(), edge.head_port())
  }
  let tail_shape = clip_shape_kind(tail_node, tail_port)
  let head_shape = clip_shape_kind(head_node, head_port)
  let tail_center = tail_clip_center
  let head_center = head_clip_center
  // Graphviz parity: ellipse clipping uses penwidth even when peripheries=0.
  let tail_penwidth = if shape_has_outline(tail_node) ||
    (match tail_shape {
      ClipShape::Ellipse => true
      _ => false
    }) {
    node_penwidth_pt(tail_node)
  } else {
    0.0
  }
  let head_penwidth = if shape_has_outline(head_node) ||
    (match head_shape {
      ClipShape::Ellipse => true
      _ => false
    }) {
    node_penwidth_pt(head_node)
  } else {
    0.0
  }
  let rankdir_quadrant = graph_rankdir_quadrant(edge)
  let rankdir_lr_rl = rankdir_quadrant == 1 || rankdir_quadrant == 3
  let tail_base_size = fixedshape_clip_size(tail_node, tail_size)
  let head_base_size = fixedshape_clip_size(head_node, head_size)
  let tail_shape_size = if @record_geometry.is_record_shape(tail_node) &&
    !@edge_identity.port_is_explicit(tail_port) {
    trim_record_border_for_clip(tail_base_size, rankdir_lr_rl)
  } else {
    tail_base_size
  }
  let head_shape_size = if @record_geometry.is_record_shape(head_node) &&
    !@edge_identity.port_is_explicit(head_port) {
    trim_record_border_for_clip(head_base_size, rankdir_lr_rl)
  } else {
    head_base_size
  }
  let tail_polygon_outline_pad = match tail_shape {
    ClipShape::Trapezium
    | ClipShape::InvTrapezium
    | ClipShape::Parallelogram
    | ClipShape::House
    | ClipShape::InvHouse
    | ClipShape::DoubleOctagon
    | ClipShape::TripleOctagon
    | ClipShape::Polygon(_, _, _, _, _) =>
      // Graphviz parity guard: poly_inside clips against bisector-expanded
      // polygon outline + penwidth/2 (shapes.c poly_init outp path).
      if tail_penwidth > 0.0 {
        tail_penwidth / 2.0
      } else {
        0.0
      }
    _ => 0.0
  }
  let head_polygon_outline_pad = match head_shape {
    ClipShape::Trapezium
    | ClipShape::InvTrapezium
    | ClipShape::Parallelogram
    | ClipShape::House
    | ClipShape::InvHouse
    | ClipShape::DoubleOctagon
    | ClipShape::TripleOctagon
    | ClipShape::Polygon(_, _, _, _, _) =>
      if head_penwidth > 0.0 {
        head_penwidth / 2.0
      } else {
        0.0
      }
    _ => 0.0
  }
  let tail_clip_size = match tail_shape {
    ClipShape::Rect | ClipShape::Ellipse =>
      // Graphviz parity guard: shape_clip(record_inside) extends both node
      // and port boxes by penwidth/2 before Bézier clipping.
      if tail_penwidth > 0.0 && fixedsize_mode(tail_node) != "shape" {
        inflate_node_size(tail_shape_size, tail_penwidth / 2.0)
      } else {
        tail_shape_size
      }
    ClipShape::Trapezium
    | ClipShape::InvTrapezium
    | ClipShape::Parallelogram
    | ClipShape::House
    | ClipShape::InvHouse
    | ClipShape::DoubleOctagon
    | ClipShape::TripleOctagon
    | ClipShape::Polygon(_, _, _, _, _)
    | ClipShape::None => tail_shape_size
  }
  let head_clip_size = match head_shape {
    ClipShape::Rect | ClipShape::Ellipse =>
      if head_penwidth > 0.0 && fixedsize_mode(head_node) != "shape" {
        inflate_node_size(head_shape_size, head_penwidth / 2.0)
      } else {
        head_shape_size
      }
    ClipShape::Trapezium
    | ClipShape::InvTrapezium
    | ClipShape::Parallelogram
    | ClipShape::House
    | ClipShape::InvHouse
    | ClipShape::DoubleOctagon
    | ClipShape::TripleOctagon
    | ClipShape::Polygon(_, _, _, _, _)
    | ClipShape::None => head_shape_size
  }
  // Graphviz parity: compass/dynamic ports disable clipping after resolvePort
  // when the resolved side is exposed.
  let tail_clip_default = match tail_port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => true
        Some(_) => false
        None => tail_port_side == 0
      }
    None => true
  }
  let tail_clip_enabled = match tail_clip_enabled_override {
    Some(value) => if value { tail_clip_default } else { false }
    None => tail_clip_default
  }
  let head_clip_default = match head_port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => true
        Some(_) => false
        None => head_port_side == 0
      }
    None => true
  }
  let head_clip_enabled = match head_clip_enabled_override {
    Some(value) => if value { head_clip_default } else { false }
    None => head_clip_default
  }
  let tail_clipped = if !tail_clip_enabled {
    points
  } else {
    match tail_shape {
      ClipShape::None => points
      _ =>
        clip_spline_start(
          points, tail_center, tail_clip_size, tail_shape, rankdir_quadrant, tail_polygon_outline_pad,
        )
    }
  }
  let head_clipped = if !head_clip_enabled {
    tail_clipped
  } else {
    match head_shape {
      ClipShape::None => tail_clipped
      _ =>
        clip_spline_end(
          tail_clipped, head_center, head_clip_size, head_shape, rankdir_quadrant,
          head_polygon_outline_pad,
        )
    }
  }
  let head_cluster_clipped = match head_cluster_bbox {
    Some(rect) => clip_spline_end_to_bbox(head_clipped, rect)
    None => head_clipped
  }
  match tail_cluster_bbox {
    Some(rect) => clip_spline_start_to_bbox(head_cluster_clipped, rect)
    None => head_cluster_clipped
  }
}

///|
fn rankdir_to_quadrant(rankdir : RankDir) -> Int {
  match rankdir {
    RankDir::TB => 0
    RankDir::LR => 1
    RankDir::BT => 2
    RankDir::RL => 3
  }
}

///|
fn rotate_cw_quadrant(pt : @geom.Point, quadrant : Int) -> @geom.Point {
  match quadrant {
    1 => point(pt.y, -pt.x)
    2 => point(-pt.x, -pt.y)
    3 => point(-pt.y, pt.x)
    _ => pt
  }
}

///|
fn compass_target_offset(
  compass : @cgraph.Compass,
  maxv : Double,
  rankdir : RankDir,
) -> @geom.Point? {
  let raw = match compass {
    @cgraph.Compass::N => Some(point(0.0, maxv))
    @cgraph.Compass::NE => Some(point(maxv, maxv))
    @cgraph.Compass::E => Some(point(maxv, 0.0))
    @cgraph.Compass::SE => Some(point(maxv, -maxv))
    @cgraph.Compass::S => Some(point(0.0, -maxv))
    @cgraph.Compass::SW => Some(point(-maxv, -maxv))
    @cgraph.Compass::W => Some(point(-maxv, 0.0))
    @cgraph.Compass::NW => Some(point(-maxv, maxv))
    @cgraph.Compass::C => None
  }
  match raw {
    Some(value) => Some(rotate_cw_quadrant(value, rankdir_to_quadrant(rankdir)))
    None => None
  }
}

///|
fn clip_line_to_rect(
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
  point(center.x + dx * t, center.y + dy * t)
}

///|
fn compass_penwidth_applies(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  shape != "none" && shape != "plaintext" && shape != "plain"
}

///|
/// Graphviz parity: resolve compass ports via the same bezier-clip + insidefn
/// flow used by shapes.c compassPoint, including penwidth/periphery outline.
pub fn compass_port_point_on_shape(
  node : @cgraph.Node,
  center : @geom.Point,
  size : NodeSize,
  compass : @cgraph.Compass,
  rankdir : RankDir,
) -> @geom.Point {
  if compass == @cgraph.Compass::C {
    return center
  }
  let base_size = fixedshape_clip_size(node, size)
  let shape = clip_shape_kind(node, None)
  let penwidth = if compass_penwidth_applies(node) {
    node_penwidth_pt(node)
  } else {
    0.0
  }
  let clip_size = match shape {
    ClipShape::Rect | ClipShape::Ellipse =>
      if penwidth > 0.0 && fixedsize_mode(node) != "shape" {
        inflate_node_size(base_size, penwidth / 2.0)
      } else {
        base_size
      }
    _ => base_size
  }
  let outline_pad = match shape {
    ClipShape::Trapezium
    | ClipShape::InvTrapezium
    | ClipShape::Parallelogram
    | ClipShape::House
    | ClipShape::InvHouse
    | ClipShape::DoubleOctagon
    | ClipShape::TripleOctagon
    | ClipShape::Polygon(_, _, _, _, _) =>
      if penwidth > 0.0 {
        penwidth / 2.0
      } else {
        0.0
      }
    _ => 0.0
  }
  // Graphviz parity: compassPort scales the ray using the pre-outline
  // port box extent (b.UR), while insidefn still clips against outline data.
  let half_w = base_size.width_pt / 2.0
  let half_h = base_size.height_pt / 2.0
  let maxv = if half_w > half_h { half_w } else { half_h }
  let target_offset = match
    compass_target_offset(compass, maxv * 4.0, rankdir) {
    Some(value) => value
    None => return center
  }
  let target = point_add(center, target_offset)
  match shape {
    // Graphviz box-ish compass ports are direct, not insidefn-clipped.
    ClipShape::Rect => clip_line_to_rect(center, clip_size, target)
    ClipShape::None => center
    _ => {
      let inside = build_point_inside_shape_fn(
        center,
        clip_size,
        shape,
        rankdir_to_quadrant(rankdir),
        outline_pad,
      )
      let curve : Array[@geom.Point] = [center, center, target, target]
      let clipped = bezier_clip(curve, inside, true)
      clipped[0]
    }
  }
}
