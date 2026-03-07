///|
/// Routing-domain sampled point plus tangent vector used by edge/port label
/// placement.
pub struct PointWithTangent {
  pos : @geom.Point
  tangent : @geom.Point
}

///|
pub fn make_point_with_tangent(
  pos : @geom.Point,
  tangent : @geom.Point,
) -> PointWithTangent {
  { pos, tangent }
}

///|
fn bezier_point(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let p01 = @edge_spline.point_lerp(p0, p1, t)
  let p12 = @edge_spline.point_lerp(p1, p2, t)
  let p23 = @edge_spline.point_lerp(p2, p3, t)
  let p012 = @edge_spline.point_lerp(p01, p12, t)
  let p123 = @edge_spline.point_lerp(p12, p23, t)
  @edge_spline.point_lerp(p012, p123, t)
}

///|
/// Graphviz parity: linear interpolation aligned to refs/graphviz/lib/common/utils.c
/// (Bezier helper, uses fused multiply-add to match Graphviz compiler output).
/// Do not change behavior without updating fixtures/tests.
fn point_lerp_fma(
  a : @geom.Point,
  b : @geom.Point,
  t : Double,
) -> @geom.Point {
  let mt = 1.0 - t
  let x = @edge_spline.libm_fma(mt, a.x, t * b.x)
  let y = @edge_spline.libm_fma(mt, a.y, t * b.y)
  @edge_spline.point(x, y)
}

///|
/// Graphviz parity: Bézier evaluation aligned to refs/graphviz/lib/common/utils.c
/// (Bezier).
/// Do not change behavior without updating fixtures/tests.
pub fn bezier_point_fma(
  p0 : @geom.Point,
  p1 : @geom.Point,
  p2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let vtemp : Array[Array[@geom.Point]] = []
  let mut row = 0
  while row < 4 {
    let line : Array[@geom.Point] = []
    let mut col = 0
    while col < 4 {
      line.push(@edge_spline.point(0.0, 0.0))
      col = col + 1
    }
    vtemp.push(line)
    row = row + 1
  }
  vtemp[0][0] = p0
  vtemp[0][1] = p1
  vtemp[0][2] = p2
  vtemp[0][3] = p3
  let mut i = 1
  while i <= 3 {
    let mut j = 0
    while j <= 3 - i {
      let a = vtemp[i - 1][j]
      let b = vtemp[i - 1][j + 1]
      vtemp[i][j] = point_lerp_fma(a, b, t)
      j = j + 1
    }
    i = i + 1
  }
  vtemp[3][0]
}

///|
pub fn sample_spline_points(
  points : Array[@geom.Point],
  steps : Int,
) -> Array[@geom.Point] {
  let samples : Array[@geom.Point] = []
  if points.length() == 0 || steps <= 0 {
    return samples
  }
  samples.push(points[0])
  let mut index = 0
  let step_count = steps.to_double()
  while index + 3 < points.length() {
    let p0 = points[index]
    let p1 = points[index + 1]
    let p2 = points[index + 2]
    let p3 = points[index + 3]
    for step in 1..=steps {
      let t = step.to_double() / step_count
      samples.push(bezier_point(p0, p1, p2, p3, t))
    }
    index = index + 3
  }
  samples
}

///|
fn polyline_point_with_dir(
  points : Array[@geom.Point],
  target_len : Double,
) -> PointWithTangent? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some({ pos: points[0], tangent: @edge_spline.point(1.0, 0.0) })
  }
  let mut remaining = target_len
  let mut last_dir = @edge_spline.point(1.0, 0.0)
  let mut last_pos = points[points.length() - 1]
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = @edge_spline.segment_length(a, b)
    if seg_len > 0.0 {
      let delta = @edge_spline.point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      if len > 0.0 {
        last_dir = @edge_spline.point_scale(delta, 1.0 / len)
        last_pos = b
      }
    }
    if seg_len <= 0.0 {
      continue
    }
    if remaining <= seg_len {
      let t = remaining / seg_len
      let pos = @edge_spline.point_lerp(a, b, t)
      let delta = @edge_spline.point_sub(b, a)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let dir =
        if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
      return Some({ pos, tangent: dir })
    }
    remaining = remaining - seg_len
  }
  Some({ pos: last_pos, tangent: last_dir })
}

///|
fn polyline_point_at_axis(
  points : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> PointWithTangent? {
  if points.length() == 0 {
    return None
  }
  if points.length() == 1 {
    return Some({ pos: points[0], tangent: @edge_spline.point(1.0, 0.0) })
  }
  let total_len = @edge_spline.polyline_length(points)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  let epsilon = 0.000001
  let mut traveled = 0.0
  let mut best_pos : @geom.Point? = None
  let mut best_dir : @geom.Point? = None
  let mut best_dist = 0.0
  for i in 0..<(points.length() - 1) {
    let a = points[i]
    let b = points[i + 1]
    let seg_len = @edge_spline.segment_length(a, b)
    let a_axis = if axis_is_x { a.x } else { a.y }
    let b_axis = if axis_is_x { b.x } else { b.y }
    let min_axis = if a_axis < b_axis { a_axis } else { b_axis }
    let max_axis = if a_axis < b_axis { b_axis } else { a_axis }
    if axis_value < min_axis || axis_value > max_axis {
      traveled = traveled + seg_len
      continue
    }
    let delta_axis = b_axis - a_axis
    let t =
      if Double::abs(delta_axis) <= epsilon {
        0.5
      } else {
        (axis_value - a_axis) / delta_axis
      }
    let pos = @edge_spline.point_lerp(a, b, t)
    let delta = @edge_spline.point_sub(b, a)
    let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
    let dir =
      if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
    let cross_len = traveled + seg_len * t
    let dist = Double::abs(cross_len - target)
    if best_pos is None || dist < best_dist {
      best_pos = Some(pos)
      best_dir = Some(dir)
      best_dist = dist
    }
    traveled = traveled + seg_len
  }
  match best_pos {
    Some(pos) =>
      match best_dir {
        Some(dir) => Some({ pos, tangent: dir })
        None => None
      }
    None => None
  }
}

///|
pub fn spline_label_pos_with_samples(
  samples : Array[@geom.Point],
) -> PointWithTangent? {
  if samples.length() == 0 {
    return None
  }
  let total_len = @edge_spline.polyline_length(samples)
  let target = if total_len <= 0.0 { 0.0 } else { total_len / 2.0 }
  polyline_point_with_dir(samples, target)
}

///|
pub fn spline_label_pos_at_samples(
  samples : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> PointWithTangent? {
  if samples.length() == 0 {
    return None
  }
  polyline_point_at_axis(samples, axis_value, axis_is_x)
}

///|
/// Graphviz parity: place_portlabel uses eflag/sflag to choose marker tangent
/// (marker present => use marker+endpoint tangent, absent => use Bezier sample).
/// Do not change behavior without updating fixtures/tests.
pub fn port_label_points(
  spline : @geom.Spline,
  is_head : Bool,
  marker_present : Bool,
) -> PointWithTangent? {
  let points = spline.points
  if points.length() < 4 {
    return None
  }
  let head_bezier_sample = () => {
    let start = points.length() - 4
    let p0 = points[start]
    let p1 = points[start + 1]
    let p2 = points[start + 2]
    let p3 = points[start + 3]
    { pos: p3, tangent: bezier_point_fma(p0, p1, p2, p3, 0.9) }
  }
  let tail_bezier_sample = () => {
    let p0 = points[0]
    let p1 = points[1]
    let p2 = points[2]
    let p3 = points[3]
    { pos: p0, tangent: bezier_point_fma(p0, p1, p2, p3, 0.1) }
  }
  if is_head {
    if !marker_present {
      return Some(head_bezier_sample())
    }
    match spline.end {
      Some(end_point) => Some({ pos: end_point, tangent: points[points.length() - 1] })
      None => Some(head_bezier_sample())
    }
  } else {
    if !marker_present {
      return Some(tail_bezier_sample())
    }
    match spline.start {
      Some(start_point) => Some({ pos: start_point, tangent: points[0] })
      None => Some(tail_bezier_sample())
    }
  }
}
