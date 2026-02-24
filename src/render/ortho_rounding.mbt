///|
const DISTINCT_TOLERANCE : Double = 0.01

///|
const ORTHO_TOLERANCE : Double = 0.1

///|
const CORNER_TOLERANCE : Double = 0.01

///|
const QUARTER_ARC_SEGMENTS : Int = 8

///|
priv struct RoundedCorner {
  idx : Int
  corner : @geom.Point
  trunc_prev : @geom.Point
  trunc_next : @geom.Point
  wedge_center : @geom.Point
  angle1 : Double
  angle2 : Double
}

///|
fn ortho_point(x : Double, y : Double) -> @geom.Point {
  @geom.Point::{ x, y }
}

///|
fn point_dist(a : @geom.Point, b : @geom.Point) -> Double {
  @math.hypot(a.x - b.x, a.y - b.y)
}

///|
fn find_prev_distinct(points : Array[@geom.Point], i : Int) -> Int? {
  let mut j = i - 1
  while j >= 0 {
    if point_dist(points[j], points[i]) > DISTINCT_TOLERANCE {
      return Some(j)
    }
    j = j - 1
  }
  None
}

///|
fn find_next_distinct(points : Array[@geom.Point], i : Int) -> Int? {
  let mut j = i + 1
  while j < points.length() {
    if point_dist(points[j], points[i]) > DISTINCT_TOLERANCE {
      return Some(j)
    }
    j = j + 1
  }
  None
}

///|
fn calculate_wedge_parameters(
  curr : @geom.Point,
  dx1 : Double,
  dy1 : Double,
  dx2 : Double,
  dy2 : Double,
  radius : Double,
  seg1_horiz : Bool,
  seg2_vert : Bool,
) -> (@geom.Point, Double, Double) {
  if seg1_horiz && seg2_vert {
    if dx1 > 0.0 && dy2 < 0.0 {
      (ortho_point(curr.x - radius, curr.y - radius), 0.0, @math.PI / 2.0)
    } else if dx1 > 0.0 && dy2 > 0.0 {
      (
        ortho_point(curr.x - radius, curr.y + radius),
        -@math.PI / 2.0,
        0.0,
      )
    } else if dx1 < 0.0 && dy2 < 0.0 {
      (
        ortho_point(curr.x + radius, curr.y - radius),
        @math.PI / 2.0,
        @math.PI,
      )
    } else {
      (
        ortho_point(curr.x + radius, curr.y + radius),
        @math.PI,
        3.0 * @math.PI / 2.0,
      )
    }
  } else {
    if dy1 < 0.0 && dx2 > 0.0 {
      (
        ortho_point(curr.x + radius, curr.y + radius),
        @math.PI,
        3.0 * @math.PI / 2.0,
      )
    } else if dy1 < 0.0 && dx2 < 0.0 {
      (
        ortho_point(curr.x - radius, curr.y + radius),
        3.0 * @math.PI / 2.0,
        2.0 * @math.PI,
      )
    } else if dy1 > 0.0 && dx2 > 0.0 {
      (
        ortho_point(curr.x + radius, curr.y - radius),
        @math.PI / 2.0,
        @math.PI,
      )
    } else {
      (ortho_point(curr.x - radius, curr.y - radius), 0.0, @math.PI / 2.0)
    }
  }
}

///|
fn append_curve(
  path : Array[@geom.Point],
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
  x3 : Double,
  y3 : Double,
) -> Unit {
  path.push(ortho_point(x1, y1))
  path.push(ortho_point(x2, y2))
  path.push(ortho_point(x3, y3))
}

///|
fn append_line(path : Array[@geom.Point], x : Double, y : Double) -> Unit {
  let cur = path[path.length() - 1]
  append_curve(path, cur.x, cur.y, x, y, x, y)
}

///|
fn quarter_wedge_path(
  center : @geom.Point,
  radius : Double,
  angle1 : Double,
  angle2 : Double,
) -> Array[@geom.Point] {
  let path : Array[@geom.Point] = []
  path.push(center)
  let mut eta_b = angle1
  let mut cos_eta_b = @math.cos(eta_b)
  let mut sin_eta_b = @math.sin(eta_b)
  let mut x_b = center.x + radius * cos_eta_b
  let mut y_b = center.y + radius * sin_eta_b
  let mut x_b_dot = -radius * sin_eta_b
  let mut y_b_dot = radius * cos_eta_b
  append_line(path, x_b, y_b)
  let d_eta = (angle2 - angle1) / QUARTER_ARC_SEGMENTS.to_double()
  let t = @math.tan(0.5 * d_eta)
  let alpha =
    @math.sin(d_eta) * (Double::sqrt(4.0 + 3.0 * t * t) - 1.0) / 3.0
  for _ in 0..<QUARTER_ARC_SEGMENTS {
    let x_a = x_b
    let y_a = y_b
    let x_a_dot = x_b_dot
    let y_a_dot = y_b_dot
    eta_b = eta_b + d_eta
    cos_eta_b = @math.cos(eta_b)
    sin_eta_b = @math.sin(eta_b)
    x_b = center.x + radius * cos_eta_b
    y_b = center.y + radius * sin_eta_b
    x_b_dot = -radius * sin_eta_b
    y_b_dot = radius * cos_eta_b
    append_curve(
      path,
      x_a + alpha * x_a_dot,
      y_a + alpha * y_a_dot,
      x_b - alpha * x_b_dot,
      y_b - alpha * y_b_dot,
      x_b,
      y_b,
    )
  }
  append_line(path, center.x, center.y)
  path
}

///|
fn point_at_any_corner(
  point : @geom.Point,
  corners : Array[RoundedCorner],
) -> Bool {
  for corner in corners {
    if point_dist(point, corner.corner) < CORNER_TOLERANCE {
      return true
    }
  }
  false
}

///|
fn find_ortho_corners(
  points : Array[@geom.Point],
  radius : Double,
) -> Array[RoundedCorner] {
  let corners : Array[RoundedCorner] = []
  for i in 0..<points.length() {
    let prev_idx = match find_prev_distinct(points, i) {
      Some(idx) => idx
      None => continue
    }
    let next_idx = match find_next_distinct(points, i) {
      Some(idx) => idx
      None => continue
    }
    let prev = points[prev_idx]
    let curr = points[i]
    let next = points[next_idx]
    let mut duplicate = false
    for existing in corners {
      if point_dist(curr, existing.corner) < CORNER_TOLERANCE {
        duplicate = true
        break
      }
    }
    if duplicate {
      continue
    }
    let mut dx1 = curr.x - prev.x
    let mut dy1 = curr.y - prev.y
    let mut dx2 = next.x - curr.x
    let mut dy2 = next.y - curr.y
    let seg1_horiz = Double::abs(dy1) < ORTHO_TOLERANCE &&
      Double::abs(dx1) > ORTHO_TOLERANCE
    let seg1_vert = Double::abs(dx1) < ORTHO_TOLERANCE &&
      Double::abs(dy1) > ORTHO_TOLERANCE
    let seg2_horiz = Double::abs(dy2) < ORTHO_TOLERANCE &&
      Double::abs(dx2) > ORTHO_TOLERANCE
    let seg2_vert = Double::abs(dx2) < ORTHO_TOLERANCE &&
      Double::abs(dy2) > ORTHO_TOLERANCE
    let is_corner = (seg1_horiz && seg2_vert) || (seg1_vert && seg2_horiz)
    if !is_corner {
      continue
    }
    let len1 = @math.hypot(dx1, dy1)
    let len2 = @math.hypot(dx2, dy2)
    if len1 <= 0.0 || len2 <= 0.0 {
      continue
    }
    dx1 = dx1 / len1
    dy1 = dy1 / len1
    dx2 = dx2 / len2
    dy2 = dy2 / len2
    let trunc_prev = ortho_point(curr.x - dx1 * radius, curr.y - dy1 * radius)
    let trunc_next = ortho_point(curr.x + dx2 * radius, curr.y + dy2 * radius)
    let (wedge_center, angle1, angle2) = calculate_wedge_parameters(
      curr,
      dx1,
      dy1,
      dx2,
      dy2,
      radius,
      seg1_horiz,
      seg2_vert,
    )
    corners.push({
      idx: i,
      corner: curr,
      trunc_prev,
      trunc_next,
      wedge_center,
      angle1,
      angle2,
    })
  }
  corners.sort_by((a, b) => Int::compare(a.idx, b.idx))
  corners
}

///|
/// Return Graphviz-style polyline chunks for rounded orthogonal splines.
pub fn rounded_ortho_polylines(
  points : Array[@geom.Point],
  radius : Double,
) -> Array[Array[@geom.Point]] {
  if points.length() == 0 || radius <= 0.0 {
    return []
  }
  let corners = find_ortho_corners(points, radius)
  if corners.length() == 0 {
    return []
  }
  let out : Array[Array[@geom.Point]] = []
  let mut seg_start_idx = 0
  let mut seg_start_pt = points[0]
  for c in 0..=corners.length() {
    let seg_end_idx = if c < corners.length() {
      corners[c].idx
    } else {
      points.length() - 1
    }
    let seg_end_pt = if c < corners.length() {
      corners[c].trunc_prev
    } else {
      points[points.length() - 1]
    }
    let seg : Array[@geom.Point] = []
    seg.push(seg_start_pt)
    for pt in (seg_start_idx + 1)..<seg_end_idx {
      if !point_at_any_corner(points[pt], corners) {
        seg.push(points[pt])
      }
    }
    seg.push(seg_end_pt)
    if seg.length() >= 2 {
      out.push(seg)
    }
    if c < corners.length() {
      let mut next_idx = corners[c].idx + 1
      while next_idx < points.length() &&
        point_at_any_corner(points[next_idx], corners) {
        next_idx = next_idx + 1
      }
      seg_start_idx = next_idx
      seg_start_pt = corners[c].trunc_next
    }
  }
  for corner in corners {
    let wedge = quarter_wedge_path(
      corner.wedge_center,
      radius,
      corner.angle1,
      corner.angle2,
    )
    if wedge.length() > 4 {
      let arc_start_idx = 3
      let arc_end_idx = wedge.length() - 4
      if arc_end_idx >= arc_start_idx {
        let arc_points : Array[@geom.Point] = []
        for i in arc_start_idx..=arc_end_idx {
          arc_points.push(wedge[i])
        }
        if arc_points.length() >= 2 {
          out.push(arc_points)
        }
      }
    }
  }
  out
}
