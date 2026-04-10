// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Bezier route domain for edge splines: polyline normalization,
/// route-to-bezier fitting, and line/polyline raw point generation.
fn straight_bezier(
  tail : @geom.Point,
  head : @geom.Point,
) -> Array[@geom.Point] {
  [tail, tail, head, head]
}

///|
fn linear_bezier(tail : @geom.Point, head : @geom.Point) -> Array[@geom.Point] {
  let c1 = point_lerp(tail, head, 1.0 / 3.0)
  let c2 = point_lerp(tail, head, 2.0 / 3.0)
  [tail, c1, c2, head]
}

///|
priv struct TailHeadPoints {
  tail : @geom.Point
  head : @geom.Point
}

///|
fn nudge_endpoints(tail : @geom.Point, head : @geom.Point) -> TailHeadPoints {
  if head.y < tail.y {
    { tail: point(tail.x, tail.y - 1.0), head: point(head.x, head.y + 1.0) }
  } else if head.y > tail.y {
    { tail: point(tail.x, tail.y + 1.0), head: point(head.x, head.y - 1.0) }
  } else if head.x > tail.x {
    { tail: point(tail.x + 1.0, tail.y), head: point(head.x - 1.0, head.y) }
  } else if head.x < tail.x {
    { tail: point(tail.x - 1.0, tail.y), head: point(head.x + 1.0, head.y) }
  } else {
    { tail, head }
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
fn orthogonal_tb_endpoint_dirs(
  tail_center : @geom.Point,
  head_center : @geom.Point,
) -> TailHeadPoints {
  let dx = head_center.x - tail_center.x
  let dy = head_center.y - tail_center.y
  let abs_dx = Double::abs(dx)
  let abs_dy = Double::abs(dy)
  if abs_dx <= 0.000001 {
    if dy >= 0.0 {
      return { tail: point(0.0, 1.0), head: point(0.0, -1.0) }
    } else {
      return { tail: point(0.0, -1.0), head: point(0.0, 1.0) }
    }
  }
  if abs_dy <= 0.000001 {
    if dx >= 0.0 {
      return { tail: point(1.0, 0.0), head: point(-1.0, 0.0) }
    } else {
      return { tail: point(-1.0, 0.0), head: point(1.0, 0.0) }
    }
  }
  if dx >= 0.0 && dy < 0.0 {
    return { tail: point(0.0, -1.0), head: point(-1.0, 0.0) }
  }
  if dx < 0.0 && dy < 0.0 {
    return { tail: point(-1.0, 0.0), head: point(0.0, 1.0) }
  }
  if dx < 0.0 && dy >= 0.0 {
    return { tail: point(0.0, 1.0), head: point(1.0, 0.0) }
  }
  { tail: point(1.0, 0.0), head: point(0.0, -1.0) }
}

///|
fn orthogonal_polyline_points_cardinal(
  edge : @cgraph.Edge,
  tail_center : @geom.Point,
  head_center : @geom.Point,
  rankdir : RankDir,
) -> Array[@geom.Point]? {
  if rankdir != RankDir::TB {
    return None
  }
  if @edge_identity.port_is_explicit(edge.tail_port()) ||
    @edge_identity.port_is_explicit(edge.head_port()) {
    return None
  }
  let endpoint_dirs = orthogonal_tb_endpoint_dirs(tail_center, head_center)
  let tail_vertical = Double::abs(endpoint_dirs.tail.y) > 0.5
  let head_vertical = Double::abs(endpoint_dirs.head.y) > 0.5
  if tail_vertical && !head_vertical {
    let corner = point(tail_center.x, head_center.y)
    return Some(compact_polyline([tail_center, corner, head_center]))
  }
  if !tail_vertical && head_vertical {
    let corner = point(head_center.x, tail_center.y)
    return Some(compact_polyline([tail_center, corner, head_center]))
  }
  Some(orthogonal_polyline_points(tail_center, head_center, rankdir))
}

///|
fn compact_polyline(points : Array[@geom.Point]) -> Array[@geom.Point] {
  let result : Array[@geom.Point] = []
  let collinear_eps = 0.000001
  for point in points {
    if result.length() == 0 {
      result.push(point)
      continue
    }
    if result[result.length() - 1] == point {
      continue
    }
    if result.length() >= 2 {
      let a = result[result.length() - 2]
      let b = result[result.length() - 1]
      let abx = b.x - a.x
      let aby = b.y - a.y
      let bcx = point.x - b.x
      let bcy = point.y - b.y
      let cross = abx * bcy - aby * bcx
      let same_dir = (
          abx * bcx >= 0.0 ||
          Double::abs(abx) <= collinear_eps ||
          Double::abs(bcx) <= collinear_eps
        ) &&
        (
          aby * bcy >= 0.0 ||
          Double::abs(aby) <= collinear_eps ||
          Double::abs(bcy) <= collinear_eps
        )
      if Double::abs(cross) <= collinear_eps && same_dir {
        ignore(result.pop())
      }
    }
    result.push(point)
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
  libm_hypot(dx, dy)
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
/// Graphviz parity: make_polyline duplication in refs/graphviz/lib/pathplan/util.c.
fn polyline_to_bezier_make_polyline(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  let out : Array[@geom.Point] = []
  if points.length() < 2 {
    return out
  }
  out.push(points[0])
  out.push(points[0])
  if points.length() > 2 {
    for i in 1..<(points.length() - 1) {
      let point = points[i]
      out.push(point)
      out.push(point)
      out.push(point)
    }
  }
  let last = points[points.length() - 1]
  out.push(last)
  out.push(last)
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
    let len = libm_sqrt(d)
    point(a.x / len, a.y / len)
  } else {
    a
  }
}

///|
pub fn point_dist(a : @geom.Point, b : @geom.Point) -> Double {
  libm_hypot(a.x - b.x, a.y - b.y)
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
  let clamped = if t < 0.0 { 0.0 } else if t > 1.0 { 1.0 } else { t }
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
  let samples = if inpn <= 2 {
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
    let root0 = -b_over_2a + libm_sqrt(disc)
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
    let r = 0.5 * libm_sqrt(-disc + q * q)
    let theta = libm_atan2(libm_sqrt(-disc), -q)
    let temp = 2.0 * libm_cbrt(r)
    roots[0] = temp * libm_cos(theta / 3.0)
    roots[1] = temp * libm_cos((theta + @math.PI + @math.PI) / 3.0)
    roots[2] = temp * libm_cos((theta - @math.PI - @math.PI) / 3.0)
    rootn = 3
  } else {
    let alpha = 0.5 * (libm_sqrt(disc) - q)
    let beta = -q - alpha
    roots[0] = libm_cbrt(alpha) + libm_cbrt(beta)
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
        let mut sv = scoeff[0] +
          tv * (scoeff[1] + tv * (scoeff[2] + tv * scoeff[3]))
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
      let mut sv = scoeff[0] +
        tv * (scoeff[1] + tv * (scoeff[2] + tv * scoeff[3]))
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
  let has_barriers = route_barriers.length() > 0
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
    let shortcut_eps = ROUTE_SPLINE_EPS1
    let input_len = total * min_len_ratio
    let mut a = 4.0
    let mut first = true
    while true {
      let c1_try = point(p0.x + a * v0.x / 3.0, p0.y + a * v0.y / 3.0)
      let c2_try = point(p3.x - a * v1.x / 3.0, p3.y - a * v1.y / 3.0)
      let control_len = polyline_length([p0, c1_try, c2_try, p3])
      if first && control_len < input_len - shortcut_eps {
        break
      }
      first = false
      if allow_spline_fit {
        if has_barriers {
          if spline_is_inside(route_barriers, p0, c1_try, c2_try, p3) {
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
          let mut bounds_ok = c1_try.x >= min_x - bound_eps &&
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
                p0, c1_try, c2_try, p3, points, start, end, bound_eps,
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
      points, split_idx, end, splitv, ev1, out, allow_spline_fit, min_len_ratio,
      bound_eps, route_barriers,
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
  let _ok = route_spline_recursive(
    points, ev0, ev1, out, allow_spline_fit, min_len_ratio, bound_eps, route_barriers,
  )
  out
}

///|

///|
/// Graphviz parity: segmented route spline matches refs/graphviz/lib/pathplan/route.c + lib/dotgen/dotsplines.c straight_path joins.
/// Do not change behavior without updating fixtures/tests.
fn route_bezier_points(
  points : Array[@geom.Point],
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  force_segmented : Bool,
  route_barriers : Array[(@geom.Point, @geom.Point)],
) -> Array[@geom.Point] {
  let allow_spline_fit = !force_segmented
  let tail_dir = if tail_slope.x == 0.0 && tail_slope.y == 0.0 {
    point(0.0, 0.0)
  } else {
    tail_slope
  }
  let head_dir = if head_slope.x == 0.0 && head_slope.y == 0.0 {
    point(0.0, 0.0)
  } else {
    head_slope
  }
  let mut has_dupes = false
  for i in 1..<points.length() {
    if points[i] == points[i - 1] {
      has_dupes = true
      break
    }
  }
  if has_dupes {
    let segments : Array[Array[@geom.Point]] = []
    let segment_start_dirs : Array[@geom.Point?] = []
    let segment_end_dirs : Array[@geom.Point?] = []
    let mut pending_start_dir : @geom.Point? = None
    let mut start = 0
    let mut i = 1
    while i < points.length() {
      if points[i] == points[i - 1] {
        if i - start >= 2 {
          let seg : Array[@geom.Point] = []
          let mut idx = start
          while idx < i {
            seg.push(points[idx])
            idx = idx + 1
          }
          segments.push(seg)
          segment_start_dirs.push(pending_start_dir)
          segment_end_dirs.push(None)
          pending_start_dir = None
        }
        let dup = points[i]
        let mut j = i + 1
        while j < points.length() && points[j] == dup {
          j = j + 1
        }
        if j < points.length() && segments.length() > 0 {
          let join_raw = point_sub(points[j], dup)
          let join_dir = point_norm(join_raw)
          if join_dir.x != 0.0 || join_dir.y != 0.0 {
            let last_idx = segments.length() - 1
            segment_end_dirs[last_idx] = Some(join_dir)
            pending_start_dir = Some(join_dir)
          }
        }
        start = j
        i = j
      } else {
        i = i + 1
      }
    }
    if points.length() - start >= 2 {
      let seg : Array[@geom.Point] = []
      let mut idx = start
      while idx < points.length() {
        seg.push(points[idx])
        idx = idx + 1
      }
      segments.push(seg)
      segment_start_dirs.push(pending_start_dir)
      segment_end_dirs.push(None)
    }
    let out : Array[@geom.Point] = []
    let mut first = true
    for si in 0..<segments.length() {
      let seg = segments[si]
      let seg_tail_dir = match segment_start_dirs[si] {
        Some(dir) => dir
        None => tail_dir
      }
      let seg_head_dir = match segment_end_dirs[si] {
        Some(dir) => dir
        None => head_dir
      }
      let seg_bezier = route_polyline_to_bezier(
        seg,
        seg_tail_dir,
        seg_head_dir,
        allow_spline_fit,
        1.0,
        0.0,
        route_barriers~,
      )
      if seg_bezier.length() == 0 {
        continue
      }
      if first {
        for p in seg_bezier {
          out.push(p)
        }
        first = false
      } else {
        if out.length() > 0 {
          let last = out[out.length() - 1]
          out.push(last)
          out.push(last)
        }
        let mut start_idx = 0
        if out.length() > 0 && seg_bezier[0] == out[out.length() - 1] {
          start_idx = 1
        }
        let mut idx = start_idx
        while idx < seg_bezier.length() {
          out.push(seg_bezier[idx])
          idx = idx + 1
        }
      }
    }
    return out
  }
  let route_points = compact_polyline(points)
  route_polyline_to_bezier(
    route_points,
    tail_dir,
    head_dir,
    allow_spline_fit,
    1.0,
    0.0,
    route_barriers~,
  )
}

///|
fn line_bezier_points(
  tail_center : @geom.Point,
  head_center : @geom.Point,
  tail_slope : @geom.Point,
  head_slope : @geom.Point,
  rankdir : RankDir,
  curve_offset : Double,
  curve_skew : Double,
  tail_cluster_bbox : @geom.Rect?,
  head_cluster_bbox : @geom.Rect?,
  prefer_linear : Bool,
) -> Array[@geom.Point] {
  let endpoint_base = if point_dist(tail_center, head_center) <= 0.000001 {
    nudge_endpoints(tail_center, head_center)
  } else {
    { tail: tail_center, head: head_center }
  }
  let tail_seed = endpoint_base.tail
  let head_seed = endpoint_base.head
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
      let perp = match rankdir {
        RankDir::TB | RankDir::BT =>
          if dx < 0.0 {
            if perp_a.y >= perp_b.y {
              perp_a
            } else {
              perp_b
            }
          } else if perp_a.y <= perp_b.y {
            perp_a
          } else {
            perp_b
          }
        RankDir::LR | RankDir::RL =>
          if dy < 0.0 {
            if perp_a.x >= perp_b.x {
              perp_a
            } else {
              perp_b
            }
          } else if perp_a.x <= perp_b.x {
            perp_a
          } else {
            perp_b
          }
      }
      let perp = if curve_skew != 1.0 {
        match rankdir {
          RankDir::TB | RankDir::BT => {
            let adjusted = point(perp.x, perp.y * curve_skew)
            let len = Double::sqrt(
              adjusted.x * adjusted.x + adjusted.y * adjusted.y,
            )
            if len <= 0.0 {
              perp
            } else {
              point(adjusted.x / len, adjusted.y / len)
            }
          }
          RankDir::LR | RankDir::RL => {
            let adjusted = point(perp.x * curve_skew, perp.y)
            let len = Double::sqrt(
              adjusted.x * adjusted.x + adjusted.y * adjusted.y,
            )
            if len <= 0.0 {
              perp
            } else {
              point(adjusted.x / len, adjusted.y / len)
            }
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
    // Graphviz parity: selected flat/invisible edges bypass route.c fitting and
    // keep linear control points.
    let use_linear = prefer_linear ||
      tail_cluster_bbox is Some(_) ||
      head_cluster_bbox is Some(_)
    if use_linear {
      linear_bezier(tail_seed, head_seed)
    } else {
      let spline = route_polyline_to_bezier(
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
}
