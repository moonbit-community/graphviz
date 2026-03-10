///|
/// Shared spline geometry owner: point math, Bezier split/clip helpers,
/// and miter geometry reused across edge spline routing and arrow shapes.

///|
const BEZIER_CLIP_EPS : Double = 0.5

///|
const POLY_GAP_PT : Double = 4.0

///|
const MILLIPOINT : Double = 0.001

///|
const ARROW_CLIP_EPS : Double = 0.5

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
priv struct BezierSplitResult {
  point : @geom.Point
  left : Array[@geom.Point]
  right : Array[@geom.Point]
}

///|

///|
pub fn point_lerp(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  point_add(a, point_scale(point_sub(b, a), t))
}

///|

///|
fn bezier_split(points : Array[@geom.Point], t : Double) -> BezierSplitResult {
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
  { point: p0123, left, right }
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
    let split = bezier_split(points, t)
    pt = split.point
    seg = if left_inside { split.right } else { split.left }
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
