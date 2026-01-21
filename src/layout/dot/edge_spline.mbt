///|
const ARROW_LENGTH : Double = 10.0
///|
const ARR_MOD_INV : Int = 1 << 5
///|
const ARR_MOD_LEFT : Int = 1 << 6
///|
const ARR_MOD_RIGHT : Int = 1 << 7

///|
priv struct Triangle {
  p0 : @geom.Point
  p1 : @geom.Point
  p2 : @geom.Point
}

///|
fn point(x : Double, y : Double) -> @geom.Point {
  @geom.Point::{ x, y }
}

///|
fn point_add(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x + b.x, a.y + b.y)
}

///|
fn point_sub(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x - b.x, a.y - b.y)
}

///|
fn point_scale(a : @geom.Point, s : Double) -> @geom.Point {
  point(a.x * s, a.y * s)
}

///|
fn point_dist2(a : @geom.Point, b : @geom.Point) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy
}

///|
fn point_lerp(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  point_add(a, point_scale(point_sub(b, a), t))
}

///|
fn clip_spline_to_rect(
  points : Array[@geom.Point],
  center : @geom.Point,
  half_w : Double,
  half_h : Double,
  left_inside : Bool,
) -> Array[@geom.Point] {
  let inside = (p : @geom.Point) => {
    let dx = p.x - center.x
    let dy = p.y - center.y
    Double::abs(dx) <= half_w && Double::abs(dy) <= half_h
  }
  bezier_clip(points, inside, left_inside)
}

///|
fn bezier_split(
  points : Array[@geom.Point],
  t : Double,
) -> (@geom.Point, Array[@geom.Point], Array[@geom.Point]) {
  let p0 = points[0]
  let p1 = points[1]
  let p2 = points[2]
  let p3 = points[3]
  let p01 = point_lerp(p0, p1, t)
  let p12 = point_lerp(p1, p2, t)
  let p23 = point_lerp(p2, p3, t)
  let p012 = point_lerp(p01, p12, t)
  let p123 = point_lerp(p12, p23, t)
  let p0123 = point_lerp(p012, p123, t)
  let left : Array[@geom.Point] = [p0, p01, p012, p0123]
  let right : Array[@geom.Point] = [p0123, p123, p23, p3]
  (p0123, left, right)
}

///|
fn bezier_clip(
  points : Array[@geom.Point],
  inside : (@geom.Point) -> Bool,
  left_inside : Bool,
) -> Array[@geom.Point] {
  let mut low = 0.0
  let mut high = 1.0
  let mut pt = if left_inside { points[0] } else { points[3] }
  let mut opt = pt
  let mut seg = points
  let mut best = points
  let mut found = false
  while true {
    opt = pt
    let t = (high + low) / 2.0
    let (next, left, right) = bezier_split(points, t)
    pt = next
    seg = if left_inside { right } else { left }
    if inside(pt) {
      if left_inside {
        low = t
      } else {
        high = t
      }
      best = seg
      found = true
    } else {
      if left_inside {
        high = t
      } else {
        low = t
      }
    }
    if Double::abs(opt.x - pt.x) <= 0.5 && Double::abs(opt.y - pt.y) <= 0.5 {
      break
    }
  }
  if found { best } else { seg }
}

///|
fn miter_shape(
  base_left : @geom.Point,
  p : @geom.Point,
  base_right : @geom.Point,
  penwidth : Double,
) -> Triangle {
  if (base_left.x == p.x && base_left.y == p.y) || (base_right.x == p.x && base_right.y == p.y) {
    return Triangle::{ p0: p, p1: p, p2: p }
  }
  let dx_a = p.x - base_left.x
  let dy_a = p.y - base_left.y
  let hypot_a = @math.hypot(dx_a, dy_a)
  let cos_alpha = dx_a / hypot_a
  let sin_alpha = dy_a / hypot_a
  let alpha = if dy_a > 0.0 {
    @math.acos(cos_alpha)
  } else {
    -@math.acos(cos_alpha)
  }
  let p1 = point(
    p.x - penwidth / 2.0 * sin_alpha,
    p.y + penwidth / 2.0 * cos_alpha,
  )
  let dx_b = base_right.x - p.x
  let dy_b = base_right.y - p.y
  let hypot_b = @math.hypot(dx_b, dy_b)
  let cos_beta = dx_b / hypot_b
  let beta = if dy_b > 0.0 {
    @math.acos(cos_beta)
  } else {
    -@math.acos(cos_beta)
  }
  let beta_rev = beta - @math.PI
  let mut theta = beta_rev - alpha
  if theta <= -@math.PI {
    theta = theta + 2.0 * @math.PI
  }
  let stroke_miterlimit = 4.0
  let normalized_miter_length = 1.0 / @math.sin(theta / 2.0)
  let sin_beta = dy_b / hypot_b
  let sin_beta_minus_pi = -sin_beta
  let cos_beta_minus_pi = -cos_beta
  let p2 = point(
    p.x + penwidth / 2.0 * sin_beta_minus_pi,
    p.y - penwidth / 2.0 * cos_beta_minus_pi,
  )
  if normalized_miter_length > stroke_miterlimit {
    let p_bevel = point((p1.x + p2.x) / 2.0, (p1.y + p2.y) / 2.0)
    Triangle::{ p0: p_bevel, p1: p1, p2: p2 }
  } else {
    let l = penwidth / 2.0 / @math.tan(theta / 2.0)
    let p3 = point(p1.x + l * cos_alpha, p1.y + l * sin_alpha)
    Triangle::{ p0: p3, p1: p1, p2: p2 }
  }
}

///|
fn arrow_type_normal0(
  p_in : @geom.Point,
  u : @geom.Point,
  penwidth : Double,
  flag : Int,
) -> (@geom.Point, Array[@geom.Point]) {
  let mut arrowwidth = 0.35
  if penwidth > 4.0 {
    arrowwidth = arrowwidth * penwidth / 4.0
  }
  let v = point(-u.y * arrowwidth, u.x * arrowwidth)
  let mut p = p_in
  let mut q = point(p.x + u.x, p.y + u.y)
  let mut delta_base = point(0.0, 0.0)
  let origin = point(0.0, 0.0)
  let v_inv = point(-v.x, -v.y)
  let normal_left = if (flag & ARR_MOD_RIGHT) != 0 { origin } else { v_inv }
  let normal_right = if (flag & ARR_MOD_LEFT) != 0 { origin } else { v }
  let base_left = if (flag & ARR_MOD_INV) != 0 { normal_right } else { normal_left }
  let base_right = if (flag & ARR_MOD_INV) != 0 { normal_left } else { normal_right }
  let normal_tip = point(-u.x, -u.y)
  let inv_tip = u
  let p_tip = if (flag & ARR_MOD_INV) != 0 { inv_tip } else { normal_tip }
  let mut delta_tip = point(0.0, 0.0)
  if u.x != 0.0 || u.y != 0.0 {
    let cos_phi = p_tip.x / @math.hypot(p_tip.x, p_tip.y)
    let sin_phi = p_tip.y / @math.hypot(p_tip.x, p_tip.y)
    let phi = if p_tip.y > 0.0 {
      @math.acos(cos_phi)
    } else {
      -@math.acos(cos_phi)
    }
    if (flag & ARR_MOD_LEFT) != 0 {
      let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
      let p1 = line_join_shape.p1
      let dx = p1.x - p_tip.x
      let dy = p1.y - p_tip.y
      let hypot_p = @math.hypot(dx, dy)
      let cos_alpha = dx / hypot_p
      let alpha = if dy > 0.0 { @math.acos(cos_alpha) } else { -@math.acos(cos_alpha) }
      let gamma = alpha - phi
      let delta_tip_length = hypot_p * @math.cos(gamma)
      delta_tip = point(delta_tip_length * cos_phi, delta_tip_length * sin_phi)
    } else if (flag & ARR_MOD_RIGHT) != 0 {
      let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
      let p2 = line_join_shape.p2
      let dx = p2.x - p_tip.x
      let dy = p2.y - p_tip.y
      let hypot_p = @math.hypot(dx, dy)
      let cos_alpha = dx / hypot_p
      let alpha = if dy > 0.0 { @math.acos(cos_alpha) } else { -@math.acos(cos_alpha) }
      let gamma = alpha - phi
      let delta_tip_length = hypot_p * @math.cos(gamma)
      delta_tip = point(delta_tip_length * cos_phi, delta_tip_length * sin_phi)
    } else {
      let line_join_shape = miter_shape(base_left, p_tip, base_right, penwidth)
      let p3 = line_join_shape.p0
      delta_tip = point_sub(p3, p_tip)
    }
    delta_base = point(penwidth / 2.0 * cos_phi, penwidth / 2.0 * sin_phi)
  }
  let a : Array[@geom.Point] = [
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
  ]
  if (flag & ARR_MOD_INV) != 0 {
    p = point_add(p, delta_base)
    q = point_add(q, delta_base)
    a[0] = p
    a[4] = p
    a[1] = point_sub(p, v)
    a[2] = q
    a[3] = point_add(p, v)
    q = point_add(q, delta_tip)
  } else {
    p = point_sub(p, delta_tip)
    q = point_sub(q, delta_tip)
    a[0] = q
    a[4] = q
    a[1] = point_sub(q, v)
    a[2] = p
    a[3] = point_add(q, v)
    q = point_sub(q, delta_base)
  }
  (q, a)
}

///|
fn arrow_length_normal(
  lenfact : Double,
  arrowsize : Double,
  penwidth : Double,
  flag : Int,
) -> Double {
  let p = point(0.0, 0.0)
  let u = point(lenfact * arrowsize * ARROW_LENGTH, 0.0)
  let (q, a) = arrow_type_normal0(p, u, penwidth, flag)
  let base1 = a[1]
  let base2 = a[3]
  let tip = a[2]
  let full_length = q.x
  let nominal_length = Double::abs(base1.x - tip.x)
  let nominal_base_width = base2.y - base1.y
  let full_base_width = nominal_base_width * full_length / nominal_length
  let overlap_at_base = penwidth / 2.0
  let length_where_width_is_penwidth = full_length * penwidth / full_base_width
  let overlap_at_tip = length_where_width_is_penwidth
  let overlap = if (flag & ARR_MOD_INV) != 0 { overlap_at_tip } else { overlap_at_base }
  full_length - overlap
}

///|
fn arrow_length_for_edge(edge : @cgraph.Edge) -> Double {
  let arrowsize = match edge.get_attr("arrowsize") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  let penwidth = match edge.get_attr("penwidth") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
  if arrowsize <= 0.0 || penwidth <= 0.0 {
    return 0.0
  }
  arrow_length_normal(1.0, arrowsize, penwidth, 0)
}

///|
fn node_penwidth_pt(node : @cgraph.Node) -> Double {
  match node.get_attr("penwidth") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
}

///|
fn arrow_end_clip(
  points : Array[@geom.Point],
  arrow_len : Double,
) -> (Array[@geom.Point], @geom.Point) {
  let end_point = points[3]
  if arrow_len <= 0.0 {
    return (points, end_point)
  }
  let sp = [end_point, points[2], points[1], points[0]]
  let len2 = arrow_len * arrow_len
  let clipped = bezier_clip(
    sp,
    (p) => point_dist2(p, end_point) <= len2,
    true,
  )
  let new_points : Array[@geom.Point] = [clipped[3], clipped[2], clipped[1], clipped[0]]
  (new_points, end_point)
}

///|
fn arrow_start_clip(
  points : Array[@geom.Point],
  arrow_len : Double,
) -> (Array[@geom.Point], @geom.Point) {
  let start_point = points[0]
  if arrow_len <= 0.0 {
    return (points, start_point)
  }
  let sp = [points[3], points[2], points[1], start_point]
  let len2 = arrow_len * arrow_len
  let clipped = bezier_clip(
    sp,
    (p) => point_dist2(p, start_point) <= len2,
    false,
  )
  let new_points : Array[@geom.Point] = [clipped[3], clipped[2], clipped[1], clipped[0]]
  (new_points, start_point)
}

///|
fn straight_bezier(
  tail : @geom.Point,
  head : @geom.Point,
) -> Array[@geom.Point] {
  [tail, tail, head, head]
}

///|
fn nudge_endpoints(
  tail : @geom.Point,
  head : @geom.Point,
) -> (@geom.Point, @geom.Point) {
  if head.y < tail.y {
    (point(tail.x, tail.y - 1.0), point(head.x, head.y + 1.0))
  } else if head.y > tail.y {
    (point(tail.x, tail.y + 1.0), point(head.x, head.y - 1.0))
  } else if head.x > tail.x {
    (point(tail.x + 1.0, tail.y), point(head.x - 1.0, head.y))
  } else if head.x < tail.x {
    (point(tail.x - 1.0, tail.y), point(head.x + 1.0, head.y))
  } else {
    (tail, head)
  }
}

///|
fn orthogonal_polyline_points(
  tail : @geom.Point,
  head : @geom.Point,
  rankdir : RankDir,
) -> Array[@geom.Point] {
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let mid_y = (tail.y + head.y) / 2.0
      [tail, point(tail.x, mid_y), point(head.x, mid_y), head]
    }
    RankDir::LR | RankDir::RL => {
      let mid_x = (tail.x + head.x) / 2.0
      [tail, point(mid_x, tail.y), point(mid_x, head.y), head]
    }
  }
}

///|
fn compact_polyline(points : Array[@geom.Point]) -> Array[@geom.Point] {
  let result : Array[@geom.Point] = []
  for point in points {
    if result.length() == 0 || result[result.length() - 1] != point {
      result.push(point)
    }
  }
  result
}

///|
fn segment_length(a : @geom.Point, b : @geom.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  @math.hypot(dx, dy)
}

///|
fn polyline_length(points : Array[@geom.Point]) -> Double {
  let mut total = 0.0
  if points.length() < 2 {
    return total
  }
  for i in 0..<(points.length() - 1) {
    total = total + segment_length(points[i], points[i + 1])
  }
  total
}

///|
fn trim_polyline_start(points : Array[@geom.Point], trim_len : Double) -> Array[@geom.Point] {
  if trim_len <= 0.0 || points.length() < 2 {
    return points
  }
  let total_len = polyline_length(points)
  if trim_len >= total_len {
    return points
  }
  let out : Array[@geom.Point] = []
  let mut remaining = trim_len
  let mut index = 0
  while index + 1 < points.length() {
    let a = points[index]
    let b = points[index + 1]
    let seg_len = segment_length(a, b)
    if seg_len <= 0.0 {
      index = index + 1
      continue
    }
    if remaining < seg_len {
      let t = remaining / seg_len
      let start = point_lerp(a, b, t)
      out.push(start)
      for j in (index + 1)..<points.length() {
        out.push(points[j])
      }
      return out
    }
    remaining = remaining - seg_len
    index = index + 1
  }
  points
}

///|
fn trim_polyline_end(points : Array[@geom.Point], trim_len : Double) -> Array[@geom.Point] {
  if trim_len <= 0.0 || points.length() < 2 {
    return points
  }
  let total_len = polyline_length(points)
  if trim_len >= total_len {
    return points
  }
  let mut remaining = trim_len
  let mut index = points.length() - 1
  while index > 0 {
    let a = points[index - 1]
    let b = points[index]
    let seg_len = segment_length(a, b)
    if seg_len <= 0.0 {
      index = index - 1
      continue
    }
    if remaining < seg_len {
      let t = remaining / seg_len
      let end_point = point_lerp(b, a, t)
      let out : Array[@geom.Point] = []
      for j in 0..<index {
        out.push(points[j])
      }
      out.push(end_point)
      return out
    }
    remaining = remaining - seg_len
    index = index - 1
  }
  points
}

///|
fn polyline_to_bezier(points : Array[@geom.Point]) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  if points.length() < 2 {
    return out
  }
  out.push(points[0])
  for i in 0..<(points.length() - 1) {
    let p0 = points[i]
    let p1 = points[i + 1]
    let c1 = point_lerp(p0, p1, 1.0 / 3.0)
    let c2 = point_lerp(p0, p1, 2.0 / 3.0)
    out.push(c1)
    out.push(c2)
    out.push(p1)
  }
  out
}

///|
fn edge_spline_for_polyline(
  edge : @cgraph.Edge,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  rankdir : RankDir,
  orthogonal : Bool,
  include_tail : Bool,
  include_head : Bool,
) -> @geom.Spline {
  let (tail, head) = if tail_clip == head_clip {
    (tail_clip, point(head_clip.x + 1.0, head_clip.y))
  } else {
    (tail_clip, head_clip)
  }
  let raw_points = if orthogonal {
    orthogonal_polyline_points(tail, head, rankdir)
  } else {
    [tail, head]
  }
  let arrow_len = if include_tail || include_head {
    arrow_length_for_edge(edge)
  } else {
    0.0
  }
  let mut polyline = compact_polyline(raw_points)
  if include_tail {
    polyline = trim_polyline_start(polyline, arrow_len)
  }
  if include_head {
    polyline = trim_polyline_end(polyline, arrow_len)
  }
  let points = polyline_to_bezier(compact_polyline(polyline))
  let start_point = if include_tail { Some(tail) } else { None }
  let end_point = if include_head { Some(head) } else { None }
  { start: start_point, end: end_point, points }
}

///|
fn edge_spline_for_line(
  edge : @cgraph.Edge,
  tail_center : @geom.Point,
  head_center : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
  include_tail : Bool,
  include_head : Bool,
) -> @geom.Spline {
  let (tail_seed, head_seed) = nudge_endpoints(tail_center, head_center)
  let mut points = straight_bezier(tail_seed, head_seed)
  let tail_penwidth = node_penwidth_pt(edge.tail())
  let head_penwidth = node_penwidth_pt(edge.head())
  points = clip_spline_to_rect(
    points,
    tail_center,
    tail_size.width_pt / 2.0 + tail_penwidth / 2.0,
    tail_size.height_pt / 2.0 + tail_penwidth / 2.0,
    true,
  )
  points = clip_spline_to_rect(
    points,
    head_center,
    head_size.width_pt / 2.0 + head_penwidth / 2.0,
    head_size.height_pt / 2.0 + head_penwidth / 2.0,
    false,
  )
  let mut start_point : @geom.Point? = None
  let mut end_point : @geom.Point? = None
  let arrow_len = if include_tail || include_head {
    arrow_length_for_edge(edge)
  } else {
    0.0
  }
  if include_tail {
    let (clipped, start) = arrow_start_clip(points, arrow_len)
    points = clipped
    start_point = Some(start)
  }
  if include_head {
    let (clipped, end) = arrow_end_clip(points, arrow_len)
    points = clipped
    end_point = Some(end)
  }
  { start: start_point, end: end_point, points }
}
