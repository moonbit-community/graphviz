///|
type NodeSize = @dot_shared.NodeSize

///|
type RankDir = @dot_shared.RankDir

///|
const RECORD_BORDER_PT : Double = @dot_shared.RECORD_BORDER_PT

///|
fn port_is_explicit(port : @cgraph.Port?) -> Bool {
  @dot_shared.port_is_explicit(port)
}

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
fn is_record_shape(node : @cgraph.Node) -> Bool {
  match node.get_attr("shape") {
    Some(value) =>
      match value.to_lower() {
        "record" | "mrecord" => true
        _ => false
      }
    None => false
  }
}

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
pub fn point(x : Double, y : Double) -> @geom.Point {
  @geom.Point::{ x, y }
}

///|
pub fn point_add(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x + b.x, a.y + b.y)
}

///|
pub fn point_sub(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  point(a.x - b.x, a.y - b.y)
}

///|
pub fn point_scale(a : @geom.Point, s : Double) -> @geom.Point {
  point(a.x * s, a.y * s)
}

///|
pub fn point_dist2(a : @geom.Point, b : @geom.Point) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  dx * dx + dy * dy
}

///|
///|
pub fn point_lerp(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
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
pub fn arrow_length_for_edge(edge : @cgraph.Edge) -> Double {
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
fn dedup_consecutive(points : Array[@geom.Point]) -> Array[@geom.Point] {
  if points.length() == 0 {
    return points
  }
  let out : Array[@geom.Point] = []
  out.push(points[0])
  for i in 1..<points.length() {
    if points[i] != points[i - 1] {
      out.push(points[i])
    }
  }
  out
}

///|
pub fn segment_length(a : @geom.Point, b : @geom.Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  @math.hypot(dx, dy)
}

///|
pub fn polyline_length(points : Array[@geom.Point]) -> Double {
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
///|
fn point_norm(a : @geom.Point) -> @geom.Point {
  let d = a.x * a.x + a.y * a.y
  if d > 0.000001 {
    let len = Double::sqrt(d)
    point(a.x / len, a.y / len)
  } else {
    a
  }
}

///|
pub fn point_dist(a : @geom.Point, b : @geom.Point) -> Double {
  @math.hypot(a.x - b.x, a.y - b.y)
}

///|
fn point_segment_distance(
  pt : @geom.Point,
  a : @geom.Point,
  b : @geom.Point,
) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  if dx == 0.0 && dy == 0.0 {
    return point_dist(pt, a)
  }
  let t = ((pt.x - a.x) * dx + (pt.y - a.y) * dy) / (dx * dx + dy * dy)
  let clamped =
    if t < 0.0 {
    0.0
  } else if t > 1.0 {
    1.0
  } else {
    t
  }
  let proj = point(a.x + dx * clamped, a.y + dy * clamped)
  point_dist(pt, proj)
}

///|
fn point_distance_to_polyline(
  pt : @geom.Point,
  points : Array[@geom.Point],
  start : Int,
  end : Int,
) -> Double {
  if end - start <= 1 {
    return point_dist(pt, points[start])
  }
  let mut min_dist = 1.0e30
  let mut idx = start
  while idx + 1 < end {
    let d = point_segment_distance(pt, points[idx], points[idx + 1])
    if d < min_dist {
      min_dist = d
    }
    idx = idx + 1
  }
  min_dist
}

///|
fn bezier_within_polyline(
  p0 : @geom.Point,
  c1 : @geom.Point,
  c2 : @geom.Point,
  p3 : @geom.Point,
  points : Array[@geom.Point],
  start : Int,
  end : Int,
  bound_eps : Double,
) -> Bool {
  if bound_eps <= 0.0 {
    return true
  }
  let inpn = end - start
  let samples =
    if inpn <= 2 {
    [0.25, 0.5, 0.75]
  } else if inpn <= 4 {
    [0.2, 0.4, 0.6, 0.8]
  } else {
    [0.125, 0.25, 0.5, 0.75, 0.875]
  }
  for t in samples {
    let p = route_bezier_point(p0, c1, c2, p3, t)
    if point_distance_to_polyline(p, points, start, end) > bound_eps {
      return false
    }
  }
  true
}

///|
///|
///|
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
const ROUTE_SPLINE_EPS1 : Double = 0.001

///|
const ROUTE_SPLINE_EPS2 : Double = 0.000001

///|
const ROUTE_SOLVER_EPS : Double = 0.0000001

///|
fn approx_zero(value : Double) -> Bool {
  Double::abs(value) < ROUTE_SOLVER_EPS
}

///|
fn solve1(coeff : Array[Double], roots : Array[Double]) -> Int {
  let a = coeff[1]
  let b = coeff[0]
  if approx_zero(a) {
    if approx_zero(b) {
      return 4
    }
    return 0
  }
  roots[0] = -b / a
  1
}

///|
fn solve2(coeff : Array[Double], roots : Array[Double]) -> Int {
  let a = coeff[2]
  let b = coeff[1]
  let c = coeff[0]
  if approx_zero(a) {
    return solve1(coeff, roots)
  }
  let b_over_2a = b / (2.0 * a)
  let c_over_a = c / a
  let disc = b_over_2a * b_over_2a - c_over_a
  if disc < 0.0 {
    return 0
  } else if disc > 0.0 {
    let root0 = -b_over_2a + Double::sqrt(disc)
    roots[0] = root0
    roots[1] = -2.0 * b_over_2a - root0
    return 2
  }
  roots[0] = -b_over_2a
  1
}

///|
fn solve3(coeff : Array[Double], roots : Array[Double]) -> Int {
  let a = coeff[3]
  let b = coeff[2]
  let c = coeff[1]
  let d = coeff[0]
  if approx_zero(a) {
    return solve2(coeff, roots)
  }
  let b_over_3a = b / (3.0 * a)
  let c_over_a = c / a
  let d_over_a = d / a
  let p0 = b_over_3a * b_over_3a
  let q = 2.0 * b_over_3a * p0 - b_over_3a * c_over_a + d_over_a
  let p = c_over_a / 3.0 - p0
  let disc = q * q + 4.0 * p * p * p
  let mut rootn = 0
  if disc < 0.0 {
    let r = 0.5 * Double::sqrt(-disc + q * q)
    let theta = @math.atan2(Double::sqrt(-disc), -q)
    let temp = 2.0 * @math.cbrt(r)
    roots[0] = temp * @math.cos(theta / 3.0)
    roots[1] = temp * @math.cos((theta + @math.PI * 2.0) / 3.0)
    roots[2] = temp * @math.cos((theta - @math.PI * 2.0) / 3.0)
    rootn = 3
  } else {
    let alpha = 0.5 * (Double::sqrt(disc) - q)
    let beta = -q - alpha
    roots[0] = @math.cbrt(alpha) + @math.cbrt(beta)
    if disc > 0.0 {
      rootn = 1
    } else {
      roots[1] = -0.5 * roots[0]
      roots[2] = roots[1]
      rootn = 3
    }
  }
  let mut idx = 0
  while idx < rootn {
    roots[idx] = roots[idx] - b_over_3a
    idx = idx + 1
  }
  rootn
}

///|
fn points_to_coeff(
  v0 : Double,
  v1 : Double,
  v2 : Double,
  v3 : Double,
  coeff : Array[Double],
) -> Unit {
  coeff[3] = v3 + 3.0 * v1 - (v0 + 3.0 * v2)
  coeff[2] = 3.0 * v0 + 3.0 * v2 - 6.0 * v1
  coeff[1] = 3.0 * (v1 - v0)
  coeff[0] = v0
}

///|
fn add_root(root : Double, roots : Array[Double], rootn : Int) -> Int {
  if root >= 0.0 && root <= 1.0 {
    roots[rootn] = root
    return rootn + 1
  }
  rootn
}

///|
fn spline_intersects_line(
  p0 : @geom.Point,
  c1 : @geom.Point,
  c2 : @geom.Point,
  p3 : @geom.Point,
  l0 : @geom.Point,
  l1 : @geom.Point,
  roots : Array[Double],
) -> Int {
  let xcoeff0 = l0.x
  let xcoeff1 = l1.x - l0.x
  let ycoeff0 = l0.y
  let ycoeff1 = l1.y - l0.y
  let scoeff : Array[Double] = Array::make(4, 0.0)
  let xroots : Array[Double] = Array::make(3, 0.0)
  let yroots : Array[Double] = Array::make(3, 0.0)
  let mut rootn = 0
  if xcoeff1 == 0.0 {
    if ycoeff1 == 0.0 {
      points_to_coeff(p0.x, c1.x, c2.x, p3.x, scoeff)
      scoeff[0] = scoeff[0] - xcoeff0
      let xrootn = solve3(scoeff, xroots)
      points_to_coeff(p0.y, c1.y, c2.y, p3.y, scoeff)
      scoeff[0] = scoeff[0] - ycoeff0
      let yrootn = solve3(scoeff, yroots)
      if xrootn == 4 {
        if yrootn == 4 {
          return 4
        }
        let mut j = 0
        while j < yrootn {
          rootn = add_root(yroots[j], roots, rootn)
          j = j + 1
        }
      } else if yrootn == 4 {
        let mut i = 0
        while i < xrootn {
          rootn = add_root(xroots[i], roots, rootn)
          i = i + 1
        }
      } else {
        let mut i = 0
        while i < xrootn {
          let mut j = 0
          while j < yrootn {
            if xroots[i] == yroots[j] {
              rootn = add_root(xroots[i], roots, rootn)
            }
            j = j + 1
          }
          i = i + 1
        }
      }
      return rootn
    }
    points_to_coeff(p0.x, c1.x, c2.x, p3.x, scoeff)
    scoeff[0] = scoeff[0] - xcoeff0
    let xrootn = solve3(scoeff, xroots)
    if xrootn == 4 {
      return 4
    }
    let mut i = 0
    while i < xrootn {
      let tv = xroots[i]
      if tv >= 0.0 && tv <= 1.0 {
        points_to_coeff(p0.y, c1.y, c2.y, p3.y, scoeff)
        let mut sv =
          scoeff[0] + tv * (scoeff[1] + tv * (scoeff[2] + tv * scoeff[3]))
        sv = (sv - ycoeff0) / ycoeff1
        if sv >= 0.0 && sv <= 1.0 {
          rootn = add_root(tv, roots, rootn)
        }
      }
      i = i + 1
    }
    return rootn
  }
  let rat = ycoeff1 / xcoeff1
  points_to_coeff(
    p0.y - rat * p0.x,
    c1.y - rat * c1.x,
    c2.y - rat * c2.x,
    p3.y - rat * p3.x,
    scoeff,
  )
  scoeff[0] = scoeff[0] + rat * xcoeff0 - ycoeff0
  let xrootn = solve3(scoeff, xroots)
  if xrootn == 4 {
    return 4
  }
  let mut i = 0
  while i < xrootn {
    let tv = xroots[i]
    if tv >= 0.0 && tv <= 1.0 {
      points_to_coeff(p0.x, c1.x, c2.x, p3.x, scoeff)
      let mut sv =
        scoeff[0] + tv * (scoeff[1] + tv * (scoeff[2] + tv * scoeff[3]))
      sv = (sv - xcoeff0) / xcoeff1
      if sv >= 0.0 && sv <= 1.0 {
        rootn = add_root(tv, roots, rootn)
      }
    }
    i = i + 1
  }
  rootn
}

///|
fn spline_is_inside(
  barriers : Array[(@geom.Point, @geom.Point)],
  p0 : @geom.Point,
  c1 : @geom.Point,
  c2 : @geom.Point,
  p3 : @geom.Point,
) -> Bool {
  let roots : Array[Double] = Array::make(4, 0.0)
  let trace_spline = @sys.get_env_var("DOT_TRACE_SPLINE") is Some(_)
  for edge in barriers {
    let (l0, l1) = edge
    let rootn = spline_intersects_line(p0, c1, c2, p3, l0, l1, roots)
    if rootn == 4 {
      continue
    }
    let mut i = 0
    while i < rootn {
      let t = roots[i]
      if t < ROUTE_SPLINE_EPS2 || t > 1.0 - ROUTE_SPLINE_EPS2 {
        i = i + 1
        continue
      }
      let ip = route_bezier_point(p0, c1, c2, p3, t)
      if point_dist2(ip, l0) < ROUTE_SPLINE_EPS1 ||
        point_dist2(ip, l1) < ROUTE_SPLINE_EPS1 {
        i = i + 1
        continue
      }
      if trace_spline {
        println(
          "splinefit reject t=\{t} line=\{l0.x},\{l0.y} -> \{l1.x},\{l1.y} ip=\{ip.x},\{ip.y}",
        )
      }
      return false
    }
  }
  true
}

///|
fn route_spline_recursive_range(
  points : Array[@geom.Point],
  start : Int,
  end : Int,
  ev0 : @geom.Point,
  ev1 : @geom.Point,
  out : Array[@geom.Point],
  allow_spline_fit : Bool,
  min_len_ratio : Double,
  bound_eps : Double,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> Bool {
  let inpn = end - start
  if inpn < 2 {
    return true
  }
  let ts : Array[Double] = []
  ts.push(0.0)
  for i in 1..<inpn {
    let prev = points[start + i - 1]
    let next = points[start + i]
    ts.push(ts[i - 1] + point_dist(next, prev))
  }
  let total = ts[inpn - 1]
  let p0 = points[start]
  let p3 = points[end - 1]
  if total <= 0.0 {
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
  for i in 0..<inpn {
    let t = ts[i]
    let a0 = point_scale(ev0, bezier_b1(t))
    let a1 = point_scale(ev1, bezier_b2(t))
    c00 = c00 + point_dot(a0, a0)
    c01 = c01 + point_dot(a0, a1)
    c11 = c11 + point_dot(a1, a1)
    let tmp = point_sub(
      points[start + i],
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
  let forceflag = inpn == 2
  if allow_spline_fit || forceflag {
    let mut min_x = p0.x
    let mut max_x = p0.x
    let mut min_y = p0.y
    let mut max_y = p0.y
    for i in 0..<inpn {
      let point = points[start + i]
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
    let min_len = total * min_len_ratio
    let mut a = 4.0
    let mut first = true
    let has_barriers = route_barriers.length() > 0
    let trace_spline = @sys.get_env_var("DOT_TRACE_SPLINE") is Some(_)
    if trace_spline && has_barriers && inpn == 4 {
      let parts : Array[String] = []
      for i in 0..<inpn {
        let p = points[start + i]
        parts.push("\{p.x},\{p.y}")
      }
      let joined = parts.join(" ")
      println("splinefit points inpn=4 \{joined}")
    }
    while true {
      let c1_try = point_add(p0, point_scale(v0, a / 3.0))
      let c2_try = point_sub(p3, point_scale(v1, a / 3.0))
      if trace_spline && has_barriers && first {
        println("splinefit inpn=\{inpn} a=\{a}")
        if inpn == 3 {
          println(
            "splinefit pts p0=\{p0.x},\{p0.y} c1=\{c1_try.x},\{c1_try.y} c2=\{c2_try.x},\{c2_try.y} p3=\{p3.x},\{p3.y}",
          )
        }
        if inpn == 4 {
          println(
            "splinefit pts4 p0=\{p0.x},\{p0.y} c1=\{c1_try.x},\{c1_try.y} c2=\{c2_try.x},\{c2_try.y} p3=\{p3.x},\{p3.y}",
          )
        }
      }
      let control_len = polyline_length([p0, c1_try, c2_try, p3])
      if first && control_len + shortcut_eps < min_len {
        break
      }
      first = false
      if allow_spline_fit {
        if has_barriers {
          if spline_is_inside(route_barriers, p0, c1_try, c2_try, p3) {
            if trace_spline {
              println("splinefit ok a=\{a} inpn=\{inpn}")
            }
            out.push(c1_try)
            out.push(c2_try)
            out.push(p3)
            return true
          }
        } else if bound_eps <= 0.0 {
          out.push(c1_try)
          out.push(c2_try)
          out.push(p3)
          return true
        }
        if !has_barriers {
          let mut bounds_ok =
            c1_try.x >= min_x - bound_eps &&
            c1_try.x <= max_x + bound_eps &&
            c1_try.y >= min_y - bound_eps &&
            c1_try.y <= max_y + bound_eps &&
            c2_try.x >= min_x - bound_eps &&
            c2_try.x <= max_x + bound_eps &&
            c2_try.y >= min_y - bound_eps &&
            c2_try.y <= max_y + bound_eps
          if bounds_ok && bound_eps > 0.0 {
            let dist_c1 = point_distance_to_polyline(c1_try, points, start, end)
            let dist_c2 = point_distance_to_polyline(c2_try, points, start, end)
            if dist_c1 > bound_eps || dist_c2 > bound_eps {
              bounds_ok = false
            }
            if bounds_ok &&
              !bezier_within_polyline(
                p0,
                c1_try,
                c2_try,
                p3,
                points,
                start,
                end,
                bound_eps,
              ) {
              bounds_ok = false
            }
          }
          if bounds_ok {
            out.push(c1_try)
            out.push(c2_try)
            out.push(p3)
            return true
          }
        }
      } else if forceflag {
        out.push(c1_try)
        out.push(c2_try)
        out.push(p3)
        return true
      }
      if a < 0.005 {
        if forceflag {
          out.push(c1_try)
          out.push(c2_try)
          out.push(p3)
          return true
        }
        break
      }
      if a > 0.01 {
        a = a / 2.0
      } else {
        a = 0.0
      }
    }
  }
  let c1 = point_add(p0, point_scale(v0, 1.0 / 3.0))
  let c2 = point_sub(p3, point_scale(v1, 1.0 / 3.0))
  let mut maxi = -1
  let mut maxd = -1.0
  for i in 1..<(inpn - 1) {
    let t = ts[i]
    let p = route_bezier_point(p0, c1, c2, p3, t)
    let d = point_dist(p, points[start + i])
    if d > maxd {
      maxd = d
      maxi = i
    }
  }
  if maxi <= 0 || maxi >= inpn - 1 {
    if inpn <= 2 {
      let fallback = polyline_to_bezier([p0, p3])
      for i in 1..<fallback.length() {
        out.push(fallback[i])
      }
      return true
    }
    maxi = inpn / 2
  }
  let split_idx = start + maxi
  let splitv1 = point_norm(point_sub(points[split_idx], points[split_idx - 1]))
  let splitv2 = point_norm(point_sub(points[split_idx + 1], points[split_idx]))
  let splitv = point_norm(point_add(splitv1, splitv2))
  if !route_spline_recursive_range(
    points,
    start,
    split_idx + 1,
    ev0,
    splitv,
    out,
    allow_spline_fit,
    min_len_ratio,
    bound_eps,
    route_barriers,
  ) {
    return false
  }
  if !route_spline_recursive_range(
    points,
    split_idx,
    end,
    splitv,
    ev1,
    out,
    allow_spline_fit,
    min_len_ratio,
    bound_eps,
    route_barriers,
  ) {
    return false
  }
  true
}

///|
fn route_spline_recursive(
  points : Array[@geom.Point],
  ev0 : @geom.Point,
  ev1 : @geom.Point,
  out : Array[@geom.Point],
  allow_spline_fit : Bool,
  min_len_ratio : Double,
  bound_eps : Double,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> Bool {
  route_spline_recursive_range(
    points,
    0,
    points.length(),
    ev0,
    ev1,
    out,
    allow_spline_fit,
    min_len_ratio,
    bound_eps,
    route_barriers,
  )
}
///|
fn route_polyline_to_bezier(
  points : Array[@geom.Point],
  start_slope : @geom.Point,
  end_slope : @geom.Point,
  allow_spline_fit : Bool,
  min_len_ratio : Double,
  bound_eps : Double,
  route_barriers? : Array[(@geom.Point, @geom.Point)] = [],
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
      route_barriers,
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
pub fn port_side_rect(
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
pub fn port_side_count(
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
pub fn endpoint_slope_for_anchor(
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
pub fn edge_spline_for_polyline(
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
pub fn edge_spline_for_points(
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
  route_barriers? : Array[(@geom.Point, @geom.Point)] = [],
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
  let polyline = compact_polyline(points)
  let compacted = compact_polyline(polyline)
  let allow_spline_fit = !force_segmented
  let route_points = compacted
  let tail_dir =
    if tail_slope.x == 0.0 && tail_slope.y == 0.0 {
    point(0.0, 0.0)
  } else {
    tail_slope
  }
  let head_dir =
    if head_slope.x == 0.0 && head_slope.y == 0.0 {
    point(0.0, 0.0)
  } else {
    head_slope
  }
  let min_len_ratio = 1.0
  let bound_eps = 0.0
  let bezier =
    route_polyline_to_bezier(
      route_points,
      tail_dir,
      head_dir,
      allow_spline_fit,
      min_len_ratio,
      bound_eps,
      route_barriers=route_barriers,
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
  let arrow_clip_eps =
    if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
    ARROW_CLIP_EPS_CLUSTER
  } else {
    ARROW_CLIP_EPS
  }
  let (clipped, start_point, end_point) =
    if include_tail || include_head {
    clip_spline_arrows(
      spline_points,
      arrow_len,
      include_tail,
      include_head,
      arrow_clip_eps,
    )
  } else {
    (spline_points, None, None)
  }
  { start: start_point, end: end_point, points: dedup_consecutive(clipped) }
}

///|
pub fn edge_spline_for_line(
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
        let offset = point(perp.x * curve_offset, perp.y * curve_offset)
        let tail_shift = point_add(tail_seed, offset)
        let head_shift = point_add(head_seed, offset)
        linear_bezier(tail_shift, head_shift)
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
