///|
/// Edge-label overlap nudge geometry plus spline sampling/tangent helpers used
/// by edge-label and port-label placement paths.

///|
priv struct PointWithTangent {
  pos : @geom.Point
  tangent : @geom.Point
}

///|
priv struct EdgeLabelRankInfo {
  label_rank : Int
  span : Int
}

///|
priv struct RectOverlapAmount {
  overlap_x : Double
  overlap_y : Double
}

///|
priv struct LabelRectNudge {
  label_pos : @geom.Point
  label_rect : @geom.Rect
}

///|
fn rect_overlap_amount(
  a : @geom.Rect,
  b : @geom.Rect,
) -> RectOverlapAmount? {
  let overlap_x = min_double(a.urx, b.urx) - max_double(a.llx, b.llx)
  let overlap_y = min_double(a.ury, b.ury) - max_double(a.lly, b.lly)
  if overlap_x > 0.0 && overlap_y > 0.0 {
    Some({ overlap_x, overlap_y })
  } else {
    None
  }
}

///|
fn nudge_label_rect(
  label_pos : @geom.Point,
  label_rect : @geom.Rect,
  other_rect : @geom.Rect,
  label_width : Double,
  label_height : Double,
  pad : Double,
) -> LabelRectNudge {
  match rect_overlap_amount(label_rect, other_rect) {
    Some(overlap) => {
      let other_center : @geom.Point = {
        x: (other_rect.llx + other_rect.urx) / 2.0,
        y: (other_rect.lly + other_rect.ury) / 2.0,
      }
      if overlap.overlap_x < overlap.overlap_y {
        let dir = if label_pos.x < other_center.x { -1.0 } else { 1.0 }
        let shift = overlap.overlap_x + pad
        let new_pos : @geom.Point = {
          x: label_pos.x + dir * shift,
          y: label_pos.y,
        }
        {
          label_pos: new_pos,
          label_rect: rect_from_center(new_pos, label_width, label_height, pad),
        }
      } else {
        let dir = if label_pos.y < other_center.y { -1.0 } else { 1.0 }
        let shift = overlap.overlap_y + pad
        let new_pos : @geom.Point = {
          x: label_pos.x,
          y: label_pos.y + dir * shift,
        }
        {
          label_pos: new_pos,
          label_rect: rect_from_center(new_pos, label_width, label_height, pad),
        }
      }
    }
    None => { label_pos, label_rect }
  }
}

///|
fn edge_tail_point(edge_layout : DotLayoutEdge) -> @geom.Point? {
  match edge_layout.splines.get(0) {
    Some(spline) =>
      match spline.start {
        Some(point) => Some(point)
        None =>
          if spline.points.length() > 0 { Some(spline.points[0]) } else { None }
      }
    None => None
  }
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
fn bezier_point_fma(
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
fn sample_spline_points(
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
fn spline_label_pos_with_samples(
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
fn spline_label_pos_at_samples(
  samples : Array[@geom.Point],
  axis_value : Double,
  axis_is_x : Bool,
) -> PointWithTangent? {
  if samples.length() == 0 {
    return None
  }
  polyline_point_at_axis(samples, axis_value, axis_is_x)
}
