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
fn clip_to_ellipse(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  let rx = size.width_pt / 2.0
  let ry = size.height_pt / 2.0
  if rx <= 0.0 || ry <= 0.0 {
    return center
  }
  let denom = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry)
  if denom <= 0.0 {
    return center
  }
  let t = 1.0 / Double::sqrt(denom)
  { x: center.x + dx * t, y: center.y + dy * t }
}

///|
fn clip_to_diamond(
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
  if half_w <= 0.0 || half_h <= 0.0 {
    return center
  }
  let denom = Double::abs(dx) / half_w + Double::abs(dy) / half_h
  if denom <= 0.0 {
    return center
  }
  let t = 1.0 / denom
  { x: center.x + dx * t, y: center.y + dy * t }
}

///|
fn point_inside_bbox(point : @geom.Point, rect : @geom.Rect) -> Bool {
  point.x >= rect.llx &&
  point.x <= rect.urx &&
  point.y >= rect.lly &&
  point.y <= rect.ury
}

///|
fn clip_to_bbox(
  from : @geom.Point,
  rect : @geom.Rect,
  target : @geom.Point,
) -> @geom.Point {
  let dx = target.x - from.x
  let dy = target.y - from.y
  if dx == 0.0 && dy == 0.0 {
    return from
  }
  if point_inside_bbox(target, rect) {
    return target
  }
  let eps = 0.000001
  let mut best : Double? = None
  let consider = (t : Double) => {
    if t <= 0.0 || t > 1.0 + eps {
      return
    }
    let x = from.x + dx * t
    let y = from.y + dy * t
    if x + eps < rect.llx || x - eps > rect.urx {
      return
    }
    if y + eps < rect.lly || y - eps > rect.ury {
      return
    }
    match best {
      Some(value) =>
        if t < value {
          best = Some(t)
        }
      None => best = Some(t)
    }
  }
  if dx != 0.0 {
    consider((rect.llx - from.x) / dx)
    consider((rect.urx - from.x) / dx)
  }
  if dy != 0.0 {
    consider((rect.lly - from.y) / dy)
    consider((rect.ury - from.y) / dy)
  }
  match best {
    Some(t) => @edge_spline.point(from.x + dx * t, from.y + dy * t)
    None => from
  }
}

///|
fn clip_polygon_attr_int(
  node : @cgraph.Node,
  key : String,
  fallback : Int,
) -> Int {
  match node.get_attr(key) {
    Some(value) => parse_double(value, fallback.to_double()).round().to_int()
    None => fallback
  }
}

///|
fn clip_polygon_attr_double(
  node : @cgraph.Node,
  key : String,
  fallback : Double,
) -> Double {
  match node.get_attr(key) {
    Some(value) => parse_double(value, fallback)
    None => fallback
  }
}

///|
priv struct ClipPolygonShapeParams {
  sides : Int
  orientation : Double
  distortion : Double
  skew : Double
}

///|
fn clip_polygon_shape_params(
  node : @cgraph.Node,
  shape : String,
) -> ClipPolygonShapeParams? {
  match shape {
    "triangle" => Some({ sides: 3, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "invtriangle" =>
      Some({ sides: 3, orientation: 180.0, distortion: 0.0, skew: 0.0 })
    "trapezium" =>
      Some({ sides: 4, orientation: 0.0, distortion: -0.4, skew: 0.0 })
    "invtrapezium" =>
      Some({ sides: 4, orientation: 180.0, distortion: -0.4, skew: 0.0 })
    "parallelogram" =>
      Some({ sides: 4, orientation: 0.0, distortion: 0.0, skew: 0.6 })
    "egg" => Some({ sides: 120, orientation: 0.0, distortion: -0.3, skew: 0.0 })
    "house" => Some({ sides: 5, orientation: 0.0, distortion: -0.64, skew: 0.0 })
    "invhouse" =>
      Some({ sides: 5, orientation: 180.0, distortion: -0.64, skew: 0.0 })
    "pentagon" => Some({ sides: 5, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "hexagon" => Some({ sides: 6, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "septagon" => Some({ sides: 7, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "octagon" | "doubleoctagon" | "tripleoctagon" =>
      Some({ sides: 8, orientation: 0.0, distortion: 0.0, skew: 0.0 })
    "polygon" => {
      let mut sides = clip_polygon_attr_int(node, "sides", 4)
      if sides < 0 {
        sides = 0
      }
      let orientation = clip_polygon_attr_double(node, "orientation", 0.0)
      let distortion = clip_polygon_attr_double(node, "distortion", 0.0)
      let skew = clip_polygon_attr_double(node, "skew", 0.0)
      if sides <= 2 && (Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001) {
        sides = 120
      }
      if sides >= 3 {
        Some({ sides, orientation, distortion, skew })
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn clip_polygon_for_shape(
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
  let mut r = @edge_spline.point(0.5 * cosx, 0.5 * sinx)
  let mut xmax = 0.0
  let mut ymax = 0.0
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
    if Double::abs(px) > xmax {
      xmax = Double::abs(px)
    }
    if Double::abs(py) > ymax {
      ymax = Double::abs(py)
    }
    base.push(@edge_spline.point(px, py))
  }
  if xmax <= 0.0 || ymax <= 0.0 {
    return []
  }
  let scale_x = half_w / xmax
  let scale_y = half_h / ymax
  let out : Array[@geom.Point] = []
  for vertex in base {
    out.push(@edge_spline.point(vertex.x * scale_x, vertex.y * scale_y))
  }
  out
}

///|
fn clip_to_polygon_shape(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> @geom.Point {
  let vertices =
    clip_polygon_for_shape(
      size,
      sides,
      orientation_deg,
      distortion,
      skew,
    )
  if vertices.length() < 3 {
    return clip_to_rect(center, size, target)
  }
  let dx = target.x - center.x
  let dy = target.y - center.y
  if Double::abs(dx) <= 0.0000001 && Double::abs(dy) <= 0.0000001 {
    return center
  }
  let mut best_t = 0.0
  let mut found = false
  for i in 0..<vertices.length() {
    let a = vertices[i]
    let b = vertices[(i + 1) % vertices.length()]
    let sx = b.x - a.x
    let sy = b.y - a.y
    let denom = dx * sy - dy * sx
    if Double::abs(denom) <= 0.0000001 {
      continue
    }
    let t = (a.x * sy - a.y * sx) / denom
    let u = (a.x * dy - a.y * dx) / denom
    if t < 0.0 {
      continue
    }
    if u < -0.000001 || u > 1.000001 {
      continue
    }
    if !found || t < best_t {
      best_t = t
      found = true
    }
  }
  if found {
    @edge_spline.point(center.x + dx * best_t, center.y + dy * best_t)
  } else {
    clip_to_rect(center, size, target)
  }
}

///|
/// Graphviz parity: route anchor clipping uses node shape bounds.
fn clip_to_node_shape(
  node : @cgraph.Node,
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      clip_to_ellipse(center, size, target)
    "diamond" | "mdiamond" => clip_to_diamond(center, size, target)
    _ =>
      match clip_polygon_shape_params(node, shape) {
        Some(params) =>
          clip_to_polygon_shape(
            center,
            size,
            target,
            params.sides,
            params.orientation,
            params.distortion,
            params.skew,
          )
        None => clip_to_rect(center, size, target)
      }
  }
}
