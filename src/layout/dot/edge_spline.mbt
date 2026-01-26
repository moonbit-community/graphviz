///|
const ARROW_LENGTH : Double = 10.0

///|
const ARR_MOD_INV : Int = 1 << 5

///|
const ARR_MOD_LEFT : Int = 1 << 6

///|
const ARR_MOD_RIGHT : Int = 1 << 7

///|
const BEZIER_CLIP_EPS : Double = 0.5

///|
const ARROW_CLIP_EPS : Double = 0.5

///|
const ARROW_CLIP_EPS_CLUSTER : Double = 0.005

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
///|
fn point_lerp(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  point_add(a, point_scale(point_sub(b, a), t))
}

///|
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
  bezier_clip_eps(points, inside, left_inside, BEZIER_CLIP_EPS)
}

///|
fn bezier_clip_eps(
  points : Array[@geom.Point],
  inside : (@geom.Point) -> Bool,
  left_inside : Bool,
  eps : Double,
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
    } else if left_inside {
      high = t
    } else {
      low = t
    }
    if Double::abs(opt.x - pt.x) <= eps && Double::abs(opt.y - pt.y) <= eps {
      break
    }
  }
  if found {
    best
  } else {
    seg
  }
}

///|
fn miter_shape(
  base_left : @geom.Point,
  p : @geom.Point,
  base_right : @geom.Point,
  penwidth : Double,
) -> Triangle {
  if (base_left.x == p.x && base_left.y == p.y) ||
    (base_right.x == p.x && base_right.y == p.y) {
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
    Triangle::{ p0: p_bevel, p1, p2 }
  } else {
    let l = penwidth / 2.0 / @math.tan(theta / 2.0)
    let p3 = point(p1.x + l * cos_alpha, p1.y + l * sin_alpha)
    Triangle::{ p0: p3, p1, p2 }
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
  let base_left = if (flag & ARR_MOD_INV) != 0 {
    normal_right
  } else {
    normal_left
  }
  let base_right = if (flag & ARR_MOD_INV) != 0 {
    normal_left
  } else {
    normal_right
  }
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
      let alpha = if dy > 0.0 {
        @math.acos(cos_alpha)
      } else {
        -@math.acos(cos_alpha)
      }
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
      let alpha = if dy > 0.0 {
        @math.acos(cos_alpha)
      } else {
        -@math.acos(cos_alpha)
      }
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
  let overlap = if (flag & ARR_MOD_INV) != 0 {
    overlap_at_tip
  } else {
    overlap_at_base
  }
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
priv enum ClipShape {
  None
  Rect
  Ellipse
}

///|
fn node_penwidth_pt(node : @cgraph.Node) -> Double {
  match node.get_attr("penwidth") {
    Some(value) => parse_double(value, 1.0)
    None => 1.0
  }
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
///|
///|
fn clip_shape_kind(node : @cgraph.Node, port : @cgraph.Port?) -> ClipShape {
  if port_is_explicit(port) && is_record_shape(node) {
    return ClipShape::Rect
  }
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" => ClipShape::Ellipse
    "box" | "rect" | "rectangle" | "record" | "mrecord" | "plaintext" | "plain" =>
      ClipShape::Rect
    "none" => ClipShape::None
    "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      ClipShape::Ellipse
    _ => ClipShape::None
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
  dx * dx + dy * dy <= 1.0
}

///|
fn point_inside_shape(
  point : @geom.Point,
  center : @geom.Point,
  size : NodeSize,
  shape : ClipShape,
) -> Bool {
  match shape {
    ClipShape::Rect => point_inside_rect(point, center, size)
    ClipShape::Ellipse => point_inside_ellipse(point, center, size)
    ClipShape::None => false
  }
}

///|
fn clip_spline_start(
  points : Array[@geom.Point],
  center : @geom.Point,
  size : NodeSize,
  shape : ClipShape,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  match shape {
    ClipShape::None => return points
    _ => ()
  }
  let inside = (p : @geom.Point) => point_inside_shape(p, center, size, shape)
  let mut start = 0
  while start + 3 < points.length() && inside(points[start + 3]) {
    start += 3
  }
  if start + 3 >= points.length() || !inside(points[start]) {
    return points
  }
  let segment : Array[@geom.Point] = [
    points[start],
    points[start + 1],
    points[start + 2],
    points[start + 3],
  ]
  let clipped = bezier_clip(segment, inside, true)
  let out = points.copy()
  out[start] = clipped[0]
  out[start + 1] = clipped[1]
  out[start + 2] = clipped[2]
  out[start + 3] = clipped[3]
  out
}

///|
fn clip_spline_end(
  points : Array[@geom.Point],
  center : @geom.Point,
  size : NodeSize,
  shape : ClipShape,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  match shape {
    ClipShape::None => return points
    _ => ()
  }
  let inside = (p : @geom.Point) => point_inside_shape(p, center, size, shape)
  let mut end = points.length() - 4
  while end > 0 && inside(points[end]) {
    end -= 3
  }
  if end + 3 >= points.length() || !inside(points[end + 3]) {
    return points
  }
  let segment : Array[@geom.Point] = [
    points[end],
    points[end + 1],
    points[end + 2],
    points[end + 3],
  ]
  let clipped = bezier_clip(segment, inside, false)
  let out = points.copy()
  out[end] = clipped[0]
  out[end + 1] = clipped[1]
  out[end + 2] = clipped[2]
  out[end + 3] = clipped[3]
  out
}

///|
fn cmp_double(a : Double, b : Double) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn count_vert_cross(points : Array[@geom.Point], xcoord : Double) -> Int {
  let mut sign = cmp_double(points[0].x, xcoord)
  let mut crossings = 0
  if sign == 0 {
    crossings = crossings + 1
  }
  for i in 1..=3 {
    let old_sign = sign
    sign = cmp_double(points[i].x, xcoord)
    if sign != old_sign && old_sign != 0 {
      crossings = crossings + 1
    }
  }
  crossings
}

///|
fn count_horz_cross(points : Array[@geom.Point], ycoord : Double) -> Int {
  let mut sign = cmp_double(points[0].y, ycoord)
  let mut crossings = 0
  if sign == 0 {
    crossings = crossings + 1
  }
  for i in 1..=3 {
    let old_sign = sign
    sign = cmp_double(points[i].y, ycoord)
    if sign != old_sign && old_sign != 0 {
      crossings = crossings + 1
    }
  }
  crossings
}

///|
fn find_vertical(
  points : Array[@geom.Point],
  tmin : Double,
  tmax : Double,
  xcoord : Double,
  ymin : Double,
  ymax : Double,
) -> Double {
  if tmin == tmax {
    return tmin
  }
  let no_cross = count_vert_cross(points, xcoord)
  if no_cross == 0 {
    return -1.0
  }
  if no_cross == 1 && Double::abs(points[3].x - xcoord) <= 0.005 {
    if ymin <= points[3].y && points[3].y <= ymax {
      return tmax
    }
    return -1.0
  }
  let mid = (tmin + tmax) / 2.0
  let (_, left, right) = bezier_split(points, 0.5)
  let t = find_vertical(left, tmin, mid, xcoord, ymin, ymax)
  if t >= 0.0 {
    return t
  }
  find_vertical(right, mid, tmax, xcoord, ymin, ymax)
}

///|
fn find_horizontal(
  points : Array[@geom.Point],
  tmin : Double,
  tmax : Double,
  ycoord : Double,
  xmin : Double,
  xmax : Double,
) -> Double {
  if tmin == tmax {
    return tmin
  }
  let no_cross = count_horz_cross(points, ycoord)
  if no_cross == 0 {
    return -1.0
  }
  if no_cross == 1 && Double::abs(points[3].y - ycoord) <= 0.005 {
    if xmin <= points[3].x && points[3].x <= xmax {
      return tmax
    }
    return -1.0
  }
  let mid = (tmin + tmax) / 2.0
  let (_, left, right) = bezier_split(points, 0.5)
  let t = find_horizontal(left, tmin, mid, ycoord, xmin, xmax)
  if t >= 0.0 {
    return t
  }
  find_horizontal(right, mid, tmax, ycoord, xmin, xmax)
}

///|
fn spline_intersect_bbox(
  points : Array[@geom.Point],
  rect : @geom.Rect,
) -> Array[@geom.Point]? {
  let orig = points
  let mut tmin = 2.0
  let mut best : Array[@geom.Point]? = None
  let update = (t : Double) => {
    if t >= 0.0 && t < tmin {
      let (_, left, _) = bezier_split(orig, t)
      tmin = t
      best = Some(left)
    }
  }
  update(find_vertical(orig, 0.0, 1.0, rect.llx, rect.lly, rect.ury))
  update(find_vertical(orig, 0.0, 1.0, rect.urx, rect.lly, rect.ury))
  update(find_horizontal(orig, 0.0, 1.0, rect.lly, rect.llx, rect.urx))
  update(find_horizontal(orig, 0.0, 1.0, rect.ury, rect.llx, rect.urx))
  if tmin < 2.0 {
    best
  } else {
    None
  }
}

///|
fn clip_spline_end_to_bbox(
  points : Array[@geom.Point],
  rect : @geom.Rect,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  let mut idx = 0
  while idx + 3 < points.length() {
    let segment : Array[@geom.Point] = [
      points[idx],
      points[idx + 1],
      points[idx + 2],
      points[idx + 3],
    ]
    match spline_intersect_bbox(segment, rect) {
      Some(clipped) => {
        let out : Array[@geom.Point] = []
        for i in 0..<idx {
          out.push(points[i])
        }
        for point in clipped {
          out.push(point)
        }
        return out
      }
      None => ()
    }
    idx += 3
  }
  points
}

///|
fn reverse_points(points : Array[@geom.Point]) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  let mut idx = points.length()
  while idx > 0 {
    idx = idx - 1
    out.push(points[idx])
  }
  out
}

///|
fn clip_spline_start_to_bbox(
  points : Array[@geom.Point],
  rect : @geom.Rect,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  let reversed = reverse_points(points)
  let clipped = clip_spline_end_to_bbox(reversed, rect)
  reverse_points(clipped)
}

///|
fn clip_spline_to_nodes(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
  tail_clip_center : @geom.Point,
  tail_size : NodeSize,
  head_clip_center : @geom.Point,
  head_size : NodeSize,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
) -> Array[@geom.Point] {
  if points.length() < 4 {
    return points
  }
  let tail_shape = clip_shape_kind(edge.tail(), edge.tail_port())
  let head_shape = clip_shape_kind(edge.head(), edge.head_port())
  let tail_center = tail_clip_center
  let head_center = head_clip_center
  let tail_base_size = tail_size
  let head_base_size = head_size
  let tail_penwidth = node_penwidth_pt(edge.tail())
  let head_penwidth = node_penwidth_pt(edge.head())
  let tail_clip_size = match tail_shape {
    ClipShape::Rect | ClipShape::Ellipse =>
      if tail_penwidth > 0.0 {
      inflate_node_size(tail_base_size, tail_penwidth / 2.0)
    } else {
      tail_base_size
    }
    _ => tail_base_size
  }
  let head_clip_size = match head_shape {
    ClipShape::Rect | ClipShape::Ellipse =>
      if head_penwidth > 0.0 {
      inflate_node_size(head_base_size, head_penwidth / 2.0)
    } else {
      head_base_size
    }
    _ => head_base_size
  }
  let tail_clipped = match tail_shape {
    ClipShape::None => points
    _ => clip_spline_start(points, tail_center, tail_clip_size, tail_shape)
  }
  let head_clipped = match head_shape {
    ClipShape::None => tail_clipped
    _ => clip_spline_end(tail_clipped, head_center, head_clip_size, head_shape)
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
fn arrow_clip_start_segment(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
) -> (Array[@geom.Point], @geom.Point) {
  let start_point = points[0]
  if arrow_len <= 0.0 || points.length() < 4 {
    return (points, start_point)
  }
  let len2 = arrow_len * arrow_len
  let mut start = 0
  if points.length() > 4 && point_dist2(points[start], points[start + 3]) < len2 {
    start += 3
  }
  let segment : Array[@geom.Point] = [
    points[start],
    points[start + 1],
    points[start + 2],
    points[start + 3],
  ]
  let (clipped, _) = arrow_start_clip(segment, arrow_len, eps)
  let out = points.copy()
  out[start] = clipped[0]
  out[start + 1] = clipped[1]
  out[start + 2] = clipped[2]
  out[start + 3] = clipped[3]
  (out, start_point)
}

///|
fn arrow_clip_end_segment(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
) -> (Array[@geom.Point], @geom.Point) {
  let end_point = points[points.length() - 1]
  if arrow_len <= 0.0 || points.length() < 4 {
    return (points, end_point)
  }
  let len2 = arrow_len * arrow_len
  let mut end = points.length() - 4
  if end > 0 && point_dist2(points[end], points[end + 3]) < len2 {
    end -= 3
  }
  let segment : Array[@geom.Point] = [
    points[end],
    points[end + 1],
    points[end + 2],
    points[end + 3],
  ]
  let (clipped, _) = arrow_end_clip(segment, arrow_len, eps)
  let out = points.copy()
  out[end] = clipped[0]
  out[end + 1] = clipped[1]
  out[end + 2] = clipped[2]
  out[end + 3] = clipped[3]
  (out, end_point)
}

///|
fn clip_spline_arrows(
  points : Array[@geom.Point],
  arrow_len : Double,
  include_tail : Bool,
  include_head : Bool,
  eps : Double,
) -> (Array[@geom.Point], @geom.Point?, @geom.Point?) {
  let mut out = points
  let mut start_point : @geom.Point? = None
  let mut end_point : @geom.Point? = None
  if include_tail {
    let (clipped, start) = arrow_clip_start_segment(out, arrow_len, eps)
    out = clipped
    start_point = Some(start)
  }
  if include_head {
    let (clipped, end) = arrow_clip_end_segment(out, arrow_len, eps)
    out = clipped
    end_point = Some(end)
  }
  (out, start_point, end_point)
}

///|
///|
fn arrow_end_clip(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
) -> (Array[@geom.Point], @geom.Point) {
  let end_point = points[3]
  if arrow_len <= 0.0 {
    return (points, end_point)
  }
  let sp = [end_point, points[2], points[1], points[0]]
  let len2 = arrow_len * arrow_len
  let clipped =
    bezier_clip_eps(sp, p => point_dist2(p, end_point) <= len2, true, eps)
  let new_points : Array[@geom.Point] = [
    clipped[3],
    clipped[2],
    clipped[1],
    clipped[0],
  ]
  (new_points, end_point)
}

///|
fn arrow_start_clip(
  points : Array[@geom.Point],
  arrow_len : Double,
  eps : Double,
) -> (Array[@geom.Point], @geom.Point) {
  let start_point = points[0]
  if arrow_len <= 0.0 {
    return (points, start_point)
  }
  let sp = [points[3], points[2], points[1], start_point]
  let len2 = arrow_len * arrow_len
  let clipped =
    bezier_clip_eps(sp, p => point_dist2(p, start_point) <= len2, false, eps)
  let new_points : Array[@geom.Point] = [
    clipped[3],
    clipped[2],
    clipped[1],
    clipped[0],
  ]
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
fn linear_bezier(
  tail : @geom.Point,
  head : @geom.Point,
) -> Array[@geom.Point] {
  let c1 = point_lerp(tail, head, 1.0 / 3.0)
  let c2 = point_lerp(tail, head, 2.0 / 3.0)
  [tail, c1, c2, head]
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
fn trim_polyline_start(
  points : Array[@geom.Point],
  trim_len : Double,
) -> Array[@geom.Point] {
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
fn trim_polyline_end(
  points : Array[@geom.Point],
  trim_len : Double,
) -> Array[@geom.Point] {
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
fn point_dot(a : @geom.Point, b : @geom.Point) -> Double {
  a.x * b.x + a.y * b.y
}

///|
fn point_len(a : @geom.Point) -> Double {
  @math.hypot(a.x, a.y)
}

///|
fn point_norm(a : @geom.Point) -> @geom.Point {
  let len = point_len(a)
  if len <= 0.000001 {
    point(0.0, 0.0)
  } else {
    point(a.x / len, a.y / len)
  }
}

///|
fn point_dist(a : @geom.Point, b : @geom.Point) -> Double {
  @math.hypot(a.x - b.x, a.y - b.y)
}

///|
fn bezier_b0(t : Double) -> Double {
  let tmp = 1.0 - t
  tmp * tmp * tmp
}

///|
fn bezier_b1(t : Double) -> Double {
  let tmp = 1.0 - t
  3.0 * t * tmp * tmp
}

///|
fn bezier_b2(t : Double) -> Double {
  let tmp = 1.0 - t
  3.0 * t * t * tmp
}

///|
fn bezier_b3(t : Double) -> Double {
  t * t * t
}

///|
fn bezier_b01(t : Double) -> Double {
  let tmp = 1.0 - t
  tmp * tmp * (tmp + 3.0 * t)
}

///|
fn bezier_b23(t : Double) -> Double {
  let tmp = 1.0 - t
  t * t * (3.0 * tmp + t)
}

///|
fn route_bezier_point(
  p0 : @geom.Point,
  c1 : @geom.Point,
  c2 : @geom.Point,
  p3 : @geom.Point,
  t : Double,
) -> @geom.Point {
  let b0 = bezier_b0(t)
  let b1 = bezier_b1(t)
  let b2 = bezier_b2(t)
  let b3 = bezier_b3(t)
  point(
    b0 * p0.x + b1 * c1.x + b2 * c2.x + b3 * p3.x,
    b0 * p0.y + b1 * c1.y + b2 * c2.y + b3 * p3.y,
  )
}

///|
fn slice_points_range(
  points : Array[@geom.Point],
  start : Int,
  end : Int,
) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  for i in start..<end {
    out.push(points[i])
  }
  out
}

///|

///|
fn route_spline_recursive(
  points : Array[@geom.Point],
  ev0 : @geom.Point,
  ev1 : @geom.Point,
  out : Array[@geom.Point],
  allow_spline_fit : Bool,
  min_len_ratio : Double,
  bound_eps : Double,
  prev_len : Double?,
  next_len : Double?,
) -> Bool {
  let inpn = points.length()
  if inpn < 2 {
    return true
  }
  let ts : Array[Double] = []
  ts.push(0.0)
  for i in 1..<inpn {
    ts.push(ts[i - 1] + point_dist(points[i], points[i - 1]))
  }
  let total = ts[inpn - 1]
  if total <= 0.0 {
    let p0 = points[0]
    let p3 = points[inpn - 1]
    out.push(point_lerp(p0, p3, 1.0 / 3.0))
    out.push(point_lerp(p0, p3, 2.0 / 3.0))
    out.push(p3)
    return true
  }
  for i in 1..<inpn {
    ts[i] = ts[i] / total
  }
  let mut c00 = 0.0
  let mut c01 = 0.0
  let mut c11 = 0.0
  let mut x0 = 0.0
  let mut x1 = 0.0
  let p0 = points[0]
  let p3 = points[inpn - 1]
  for i in 0..<inpn {
    let t = ts[i]
    let a0 = point_scale(ev0, bezier_b1(t))
    let a1 = point_scale(ev1, bezier_b2(t))
    c00 = c00 + point_dot(a0, a0)
    c01 = c01 + point_dot(a0, a1)
    c11 = c11 + point_dot(a1, a1)
    let tmp = point_sub(
      points[i],
      point_add(point_scale(p0, bezier_b01(t)), point_scale(p3, bezier_b23(t))),
    )
    x0 = x0 + point_dot(a0, tmp)
    x1 = x1 + point_dot(a1, tmp)
  }
  let det01 = c00 * c11 - c01 * c01
  let mut scale0 = 0.0
  let mut scale3 = 0.0
  if Double::abs(det01) >= 0.000001 {
    let det0x = c00 * x1 - c01 * x0
    let detx1 = x0 * c11 - x1 * c01
    scale0 = detx1 / det01
    scale3 = det0x / det01
  }
  if Double::abs(det01) < 0.000001 || scale0 <= 0.0 || scale3 <= 0.0 {
    let d01 = point_dist(p0, p3) / 3.0
    scale0 = d01
    scale3 = d01
  }
  let v0 = point_scale(ev0, scale0)
  let v1 = point_scale(ev1, scale3)
  let fit_scale = 4.0
  let forceflag = inpn == 2
  if allow_spline_fit || forceflag {
    let mut min_x = points[0].x
    let mut max_x = points[0].x
    let mut min_y = points[0].y
    let mut max_y = points[0].y
    for point in points {
      if point.x < min_x {
        min_x = point.x
      }
      if point.x > max_x {
        max_x = point.x
      }
      if point.y < min_y {
        min_y = point.y
      }
      if point.y > max_y {
        max_y = point.y
      }
    }
    let shortcut_eps = 0.001
    let mut scale = fit_scale
    let mut first = true
    while true {
      let c1_try = point_add(p0, point_scale(v0, scale / 3.0))
      let c2_try = point_sub(p3, point_scale(v1, scale / 3.0))
      if first {
        let control_len = polyline_length([p0, c1_try, c2_try, p3])
        let min_len = total * min_len_ratio
        if control_len + shortcut_eps < min_len {
          break
        }
      }
      let bounds_ok =
        c1_try.x >= min_x - bound_eps &&
        c1_try.x <= max_x + bound_eps &&
        c1_try.y >= min_y - bound_eps &&
        c1_try.y <= max_y + bound_eps &&
        c2_try.x >= min_x - bound_eps &&
        c2_try.x <= max_x + bound_eps &&
        c2_try.y >= min_y - bound_eps &&
        c2_try.y <= max_y + bound_eps
      if bounds_ok {
        out.push(c1_try)
        out.push(c2_try)
        out.push(p3)
        return true
      }
      if scale < 0.005 {
        if forceflag {
          out.push(c1_try)
          out.push(c2_try)
          out.push(p3)
          return true
        }
        break
      }
      if scale > 0.01 {
        scale = scale / 2.0
      } else {
        scale = 0.0
      }
      first = false
    }
  }
  let c1 = point_add(p0, point_scale(v0, 1.0 / 3.0))
  let c2 = point_sub(p3, point_scale(v1, 1.0 / 3.0))
  let mut maxi = -1
  let mut maxd = -1.0
  for i in 1..<(inpn - 1) {
    let t = ts[i]
    let p = route_bezier_point(p0, c1, c2, p3, t)
    let d = point_dist(p, points[i])
    if d > maxd {
      maxd = d
      maxi = i
    }
  }
  if maxi <= 0 || maxi >= inpn - 1 {
    if inpn <= 2 {
      let fallback = polyline_to_bezier(points)
      for i in 1..<fallback.length() {
        out.push(fallback[i])
      }
      return true
    }
    maxi = inpn / 2
  }
  let splitv1 = point_norm(point_sub(points[maxi], points[maxi - 1]))
  let splitv2 = point_norm(point_sub(points[maxi + 1], points[maxi]))
  let splitv = point_norm(point_add(splitv1, splitv2))
  let left = slice_points_range(points, 0, maxi + 1)
  let right = slice_points_range(points, maxi, inpn)
  let left_len = point_dist(points[maxi], points[maxi - 1])
  let right_len = point_dist(points[maxi + 1], points[maxi])
  let left_path_len = polyline_length(slice_points_range(points, 0, maxi + 1))
  let left_next = if right_len > 0.0 {
    match next_len {
      Some(next) =>
        if left_path_len < ARROW_LENGTH && next > right_len {
          Some(next)
        } else {
          Some(right_len)
        }
      None => Some(right_len)
    }
  } else {
    next_len
  }
  let right_prev = match prev_len {
    Some(_) => if left_len > 0.0 { Some(left_len) } else { prev_len }
    None => if left_len > 0.0 { Some(left_len) } else { None }
  }
  if !route_spline_recursive(
    left,
    ev0,
    splitv,
    out,
    allow_spline_fit,
    min_len_ratio,
    bound_eps,
    prev_len,
    left_next,
  ) {
    return false
  }
  if !route_spline_recursive(
    right,
    splitv,
    ev1,
    out,
    allow_spline_fit,
    min_len_ratio,
    bound_eps,
    right_prev,
    next_len,
  ) {
    return false
  }
  true
}
///|
fn route_polyline_to_bezier(
  points : Array[@geom.Point],
  start_slope : @geom.Point,
  end_slope : @geom.Point,
  allow_spline_fit : Bool,
  min_len_ratio : Double,
  bound_eps : Double,
) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  if points.length() < 2 {
    return out
  }
  out.push(points[0])
  let ev0 = point_norm(start_slope)
  let ev1 = point_norm(end_slope)
  let _ok =
    route_spline_recursive(
      points,
      ev0,
      ev1,
      out,
      allow_spline_fit,
      min_len_ratio,
      bound_eps,
      None,
      None,
    )
  out
}

///|
fn compass_angle(compass : @cgraph.Compass) -> Double? {
  match compass {
    @cgraph.Compass::N => Some(@math.PI * 0.5)
    @cgraph.Compass::NE => Some(@math.PI * 0.25)
    @cgraph.Compass::E => Some(0.0)
    @cgraph.Compass::SE => Some(-@math.PI * 0.25)
    @cgraph.Compass::S => Some(-@math.PI * 0.5)
    @cgraph.Compass::SW => Some(-@math.PI * 0.75)
    @cgraph.Compass::W => Some(@math.PI)
    @cgraph.Compass::NW => Some(@math.PI * 0.75)
    @cgraph.Compass::C => None
  }
}

///|
fn invflip_angle(angle : Double, rankdir : RankDir) -> Double {
  match rankdir {
    RankDir::TB => angle
    RankDir::BT => -angle
    RankDir::LR => angle - @math.PI * 0.5
    RankDir::RL => {
      if angle == @math.PI {
        -@math.PI * 0.5
      } else if angle == @math.PI * 0.75 {
        -@math.PI * 0.25
      } else if angle == @math.PI * 0.5 {
        0.0
      } else if angle == 0.0 {
        @math.PI * 0.5
      } else if angle == -@math.PI * 0.25 {
        @math.PI * 0.75
      } else if angle == -@math.PI * 0.5 {
        @math.PI
      } else {
        angle
      }
    }
  }
}

///|
fn compass_vector(compass : @cgraph.Compass, rankdir : RankDir) -> @geom.Point? {
  match compass_angle(compass) {
    Some(angle) => {
      let theta = invflip_angle(angle, rankdir)
      Some(point(@math.cos(theta), @math.sin(theta)))
    }
    None => None
  }
}

///|
fn axis_direction(dir : @geom.Point) -> @geom.Point {
  let abs_dx = Double::abs(dir.x)
  let abs_dy = Double::abs(dir.y)
  if abs_dx <= 0.000001 && abs_dy <= 0.000001 {
    point(0.0, 0.0)
  } else if abs_dx >= abs_dy {
    let sign = if dir.x >= 0.0 { 1.0 } else { -1.0 }
    point(sign, 0.0)
  } else {
    let sign = if dir.y >= 0.0 { 1.0 } else { -1.0 }
    point(0.0, sign)
  }
}

///|
fn rotate_dir_for_rankdir(
  dir : @geom.Point,
  rankdir : RankDir,
) -> @geom.Point {
  match rankdir {
    RankDir::TB => dir
    RankDir::BT => point(dir.x, -dir.y)
    RankDir::LR => point(-dir.y, dir.x)
    RankDir::RL => point(dir.y, -dir.x)
  }
}

///|
fn port_side_direction(
  port_rect : @geom.Rect,
  anchor : @geom.Point,
  node_pos : @geom.Point,
  node_size : NodeSize,
  target : @geom.Point,
  rankdir : RankDir,
) -> @geom.Point? {
  let mid_x = (port_rect.llx + port_rect.urx) / 2.0
  let mid_y = (port_rect.lly + port_rect.ury) / 2.0
  let eps = if RECORD_BORDER_PT > 0.01 {
    RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let node_rect = port_side_rect(node_pos, node_size)
  let candidates : Array[(@geom.Point, @geom.Point)] = []
  if Double::abs(port_rect.llx - node_rect.llx) <= eps {
    candidates.push((point(port_rect.llx, mid_y), point(-1.0, 0.0)))
  }
  if Double::abs(port_rect.urx - node_rect.urx) <= eps {
    candidates.push((point(port_rect.urx, mid_y), point(1.0, 0.0)))
  }
  if Double::abs(port_rect.lly - node_rect.lly) <= eps {
    candidates.push((point(mid_x, port_rect.lly), point(0.0, -1.0)))
  }
  if Double::abs(port_rect.ury - node_rect.ury) <= eps {
    candidates.push((point(mid_x, port_rect.ury), point(0.0, 1.0)))
  }
  if candidates.length() == 0 || candidates.length() == 4 {
    return None
  }
  let target_rel = point_sub(target, anchor)
  let target_rot = rotate_dir_for_rankdir(target_rel, rankdir)
  let mut best_dir = point(0.0, 0.0)
  let mut best_dist = 0.0
  let mut seen = false
  for pair in candidates {
    let (pos, dir) = pair
    let cand_rel = point_sub(pos, anchor)
    let cand_rot = rotate_dir_for_rankdir(cand_rel, rankdir)
    let dist = point_dist2(cand_rot, target_rot)
    if !seen || dist < best_dist {
      best_dist = dist
      best_dir = dir
      seen = true
    }
  }
  if seen { Some(best_dir) } else { None }
}

///|
fn port_side_rect(
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> @geom.Rect {
  let node_half_w = node_size.width_pt / 2.0
  let node_half_h = node_size.height_pt / 2.0
  {
    llx: node_pos.x - node_half_w,
    lly: node_pos.y - node_half_h,
    urx: node_pos.x + node_half_w,
    ury: node_pos.y + node_half_h,
  }
}

///|
fn port_side_count(
  port_rect : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> Int {
  let eps = if RECORD_BORDER_PT > 0.01 {
    RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let node_rect = port_side_rect(node_pos, node_size)
  let mut count = 0
  if Double::abs(port_rect.llx - node_rect.llx) <= eps {
    count = count + 1
  }
  if Double::abs(port_rect.urx - node_rect.urx) <= eps {
    count = count + 1
  }
  if Double::abs(port_rect.lly - node_rect.lly) <= eps {
    count = count + 1
  }
  if Double::abs(port_rect.ury - node_rect.ury) <= eps {
    count = count + 1
  }
  count
}

///|
///|
fn endpoint_slope_for_anchor(
  port : @cgraph.Port?,
  anchor : @geom.Point,
  node_pos : @geom.Point,
  node_size : NodeSize,
  target : @geom.Point,
  rankdir : RankDir,
  tail : Bool,
  port_rect : @geom.Rect?,
) -> @geom.Point {
  if !port_is_explicit(port) {
    return point(0.0, 0.0)
  }
  match port {
    Some(value) =>
      match value.compass {
        Some(compass) =>
          match compass_vector(compass, rankdir) {
            Some(vec) => if tail { vec } else { point(-vec.x, -vec.y) }
            None => point(0.0, 0.0)
          }
        None => {
          match port_rect {
            Some(rect) =>
              match port_side_direction(
                rect,
                anchor,
                node_pos,
                node_size,
                target,
                rankdir,
              ) {
                Some(dir) =>
                  return if tail { dir } else { point(-dir.x, -dir.y) }
                None => ()
              }
            None => ()
          }
          let half_w = node_size.width_pt / 2.0
          let half_h = node_size.height_pt / 2.0
          let left = node_pos.x - half_w
          let right = node_pos.x + half_w
          let bottom = node_pos.y - half_h
          let top = node_pos.y + half_h
          let eps = 0.01
          let mut dir = point(0.0, 0.0)
          if anchor.x <= left + eps {
            dir = point(-1.0, 0.0)
          } else if anchor.x >= right - eps {
            dir = point(1.0, 0.0)
          } else if anchor.y <= bottom + eps {
            dir = point(0.0, -1.0)
          } else if anchor.y >= top - eps {
            dir = point(0.0, 1.0)
          } else {
            dir = axis_direction(point_sub(target, anchor))
          }
          if tail { dir } else { point(-dir.x, -dir.y) }
        }
      }
    None => point(0.0, 0.0)
  }
}


///|
fn edge_spline_for_polyline(
  edge : @cgraph.Edge,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_clip : @geom.Point,
  head_clip : @geom.Point,
  rankdir : RankDir,
  orthogonal : Bool,
  include_tail : Bool,
  include_head : Bool,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
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
  let arrow_len =
    if include_tail || include_head {
      let base = arrow_length_for_edge(edge)
      match arrow_len_override {
        Some(value) =>
          if value > 0.0 && value < base {
          value
        } else {
          base
        }
        None => base
      }
    } else {
      0.0
    }
  let polyline = compact_polyline(raw_points)
  let bezier = polyline_to_bezier(compact_polyline(polyline))
  let clipped =
    clip_spline_to_nodes(
      edge,
      bezier,
      tail_clip_center,
      tail_anchor_size,
      head_clip_center,
      head_anchor_size,
      tail_cluster_bbox=tail_cluster_bbox,
      head_cluster_bbox=head_cluster_bbox,
    )
  let arrow_clip_eps =
    if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
    ARROW_CLIP_EPS_CLUSTER
  } else {
    ARROW_CLIP_EPS
  }
  let (points, start_point, end_point) =
    if include_tail || include_head {
    clip_spline_arrows(
      clipped,
      arrow_len,
      include_tail,
      include_head,
      arrow_clip_eps,
    )
  } else {
    (clipped, None, None)
  }
  { start: start_point, end: end_point, points }
}

///|
fn edge_spline_for_points(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  force_segmented : Bool,
  include_tail : Bool,
  include_head : Bool,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
) -> @geom.Spline {
  if points.length() == 0 {
    return { start: None, end: None, points: [] }
  }
  let arrow_len =
    if include_tail || include_head {
      let base = arrow_length_for_edge(edge)
      match arrow_len_override {
        Some(value) =>
          if value > 0.0 && value < base {
          value
        } else {
          base
        }
        None => base
      }
    } else {
      0.0
    }
  let mut polyline = compact_polyline(points)
  if include_tail {
    polyline = trim_polyline_start(polyline, arrow_len)
  }
  if include_head {
    polyline = trim_polyline_end(polyline, arrow_len)
  }
  let compacted = compact_polyline(polyline)
  let allow_spline_fit = !force_segmented
  let has_explicit_port =
    port_is_explicit(edge.tail_port()) || port_is_explicit(edge.head_port())
  let min_len_ratio = 1.0
  let bound_eps = if has_explicit_port { 0.5 } else { 4.0 }
  let bezier =
    route_polyline_to_bezier(
      compacted,
      tail_slope,
      head_slope,
      allow_spline_fit,
      min_len_ratio,
      bound_eps,
    )
  let spline_points =
    clip_spline_to_nodes(
      edge,
      bezier,
      tail_clip_center,
      tail_anchor_size,
      head_clip_center,
      head_anchor_size,
      tail_cluster_bbox=tail_cluster_bbox,
      head_cluster_bbox=head_cluster_bbox,
    )
  let start_point = if include_tail { Some(points[0]) } else { None }
  let end_point = if include_head {
    Some(points[points.length() - 1])
  } else {
    None
  }
  { start: start_point, end: end_point, points: spline_points }
}

///|
fn edge_spline_for_line(
  edge : @cgraph.Edge,
  tail_center : @geom.Point,
  head_center : @geom.Point,
  tail_clip_center : @geom.Point,
  head_clip_center : @geom.Point,
  tail_anchor_size : NodeSize,
  head_anchor_size : NodeSize,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  include_tail : Bool,
  include_head : Bool,
  rankdir : RankDir,
  curve_offset : Double,
  curve_skew : Double,
  arrow_len_override~ : Double?,
  tail_cluster_bbox~ : @geom.Rect?,
  head_cluster_bbox~ : @geom.Rect?,
) -> @geom.Spline {
  let arrow_len =
    if include_tail || include_head {
      let base = arrow_length_for_edge(edge)
      match arrow_len_override {
        Some(value) =>
          if value > 0.0 && value < base {
          value
        } else {
          base
        }
        None => base
      }
    } else {
      0.0
    }
  let (tail_base, head_base) =
    if point_dist(tail_center, head_center) <= 0.000001 {
    nudge_endpoints(tail_center, head_center)
  } else {
    (tail_center, head_center)
  }
  let tail_seed = tail_base
  let head_seed = head_base
  let mut points =
    if curve_offset > 0.0 {
      let dx = head_seed.x - tail_seed.x
      let dy = head_seed.y - tail_seed.y
      let dist = Double::sqrt(dx * dx + dy * dy)
      if dist <= 0.0 {
        straight_bezier(tail_seed, head_seed)
      } else {
        let inv = 1.0 / dist
        let perp_a = point(-dy * inv, dx * inv)
        let perp_b = point(dy * inv, -dx * inv)
        let perp =
          match rankdir {
            RankDir::TB | RankDir::BT => {
              if dx < 0.0 {
                if perp_a.y >= perp_b.y { perp_a } else { perp_b }
              } else {
                if perp_a.y <= perp_b.y { perp_a } else { perp_b }
              }
            }
            RankDir::LR | RankDir::RL => {
              if dy < 0.0 {
                if perp_a.x >= perp_b.x { perp_a } else { perp_b }
              } else {
                if perp_a.x <= perp_b.x { perp_a } else { perp_b }
              }
            }
          }
        let perp =
          if curve_skew != 1.0 {
            match rankdir {
              RankDir::TB | RankDir::BT => {
                let adjusted = point(perp.x, perp.y * curve_skew)
                let len = Double::sqrt(
                  adjusted.x * adjusted.x + adjusted.y * adjusted.y,
                )
                if len <= 0.0 { perp } else { point(adjusted.x / len, adjusted.y / len) }
              }
              RankDir::LR | RankDir::RL => {
                let adjusted = point(perp.x * curve_skew, perp.y)
                let len = Double::sqrt(
                  adjusted.x * adjusted.x + adjusted.y * adjusted.y,
                )
                if len <= 0.0 { perp } else { point(adjusted.x / len, adjusted.y / len) }
              }
            }
          } else {
            perp
          }
        let c1_weight = 0.6
        let c2_weight = 1.2
        let c1 = point(
          tail_seed.x + dx / 3.0 + perp.x * curve_offset * c1_weight,
          tail_seed.y + dy / 3.0 + perp.y * curve_offset * c1_weight,
        )
        let c2 = point(
          tail_seed.x + dx * 2.0 / 3.0 + perp.x * curve_offset * c2_weight,
          tail_seed.y + dy * 2.0 / 3.0 + perp.y * curve_offset * c2_weight,
        )
        [tail_seed, c1, c2, head_seed]
      }
    } else {
      let use_linear =
        tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_)
      if use_linear {
        linear_bezier(tail_seed, head_seed)
      } else {
        let spline =
          route_polyline_to_bezier(
            [tail_seed, head_seed],
            tail_slope,
            head_slope,
            false,
            1.0,
            4.0,
          )
        if spline.length() > 0 {
          spline
        } else {
          straight_bezier(tail_seed, head_seed)
        }
      }
    }
  points =
    clip_spline_to_nodes(
      edge,
      points,
      tail_clip_center,
      tail_anchor_size,
      head_clip_center,
      head_anchor_size,
      tail_cluster_bbox=tail_cluster_bbox,
      head_cluster_bbox=head_cluster_bbox,
    )
  let arrow_clip_eps =
    if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
    ARROW_CLIP_EPS_CLUSTER
  } else {
    ARROW_CLIP_EPS
  }
  let (clipped, start_point, end_point) =
    if include_tail || include_head {
      clip_spline_arrows(
        points,
        arrow_len,
        include_tail,
        include_head,
        arrow_clip_eps,
      )
    } else {
      (points, None, None)
    }
  points = clipped
  { start: start_point, end: end_point, points }
}
