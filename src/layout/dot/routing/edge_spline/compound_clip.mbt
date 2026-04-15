// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Compound and bbox clipping owner for edge splines: intersect Bezier
/// segments with cluster boxes and adjust short compound exits.
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
  for i in 1..<=3 {
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
  for i in 1..<=3 {
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
  let split = bezier_split(points, 0.5)
  let t = find_vertical(split.left, tmin, mid, xcoord, ymin, ymax)
  if t >= 0.0 {
    return t
  }
  find_vertical(split.right, mid, tmax, xcoord, ymin, ymax)
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
  let split = bezier_split(points, 0.5)
  let t = find_horizontal(split.left, tmin, mid, ycoord, xmin, xmax)
  if t >= 0.0 {
    return t
  }
  find_horizontal(split.right, mid, tmax, ycoord, xmin, xmax)
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
      let split = bezier_split(orig, t)
      tmin = t
      best = Some(split.left)
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
fn point_in_rect(point : @geom.Point, rect : @geom.Rect) -> Bool {
  point.x >= rect.llx &&
  point.x <= rect.urx &&
  point.y >= rect.lly &&
  point.y <= rect.ury
}

///|
fn line_rect_intersection_from_inside(
  inside : @geom.Point,
  outside : @geom.Point,
  rect : @geom.Rect,
) -> @geom.Point {
  let c_round = (value : Double) => {
    if value >= 0.0 {
      (value + 0.5).floor()
    } else {
      (value - 0.5).ceil()
    }
  }
  if outside.x < rect.llx {
    let x = rect.llx
    let y = inside.y +
      c_round((x - inside.x) * (inside.y - outside.y) / (inside.x - outside.x))
    if y >= rect.lly && y <= rect.ury {
      return @geom.Point::{ x, y }
    }
  }
  if outside.x > rect.urx {
    let x = rect.urx
    let y = inside.y +
      c_round((x - inside.x) * (inside.y - outside.y) / (inside.x - outside.x))
    if y >= rect.lly && y <= rect.ury {
      return @geom.Point::{ x, y }
    }
  }
  if outside.y < rect.lly {
    let y = rect.lly
    let x = inside.x +
      c_round((y - inside.y) * (inside.x - outside.x) / (inside.y - outside.y))
    if x >= rect.llx && x <= rect.urx {
      return @geom.Point::{ x, y }
    }
  }
  if outside.y > rect.ury {
    let y = rect.ury
    let x = inside.x +
      c_round((y - inside.y) * (inside.x - outside.x) / (inside.y - outside.y))
    if x >= rect.llx && x <= rect.urx {
      return @geom.Point::{ x, y }
    }
  }
  inside
}

///|
fn adjust_tail_cluster_compound_segment(
  points : Array[@geom.Point],
  end_point : @geom.Point?,
  include_tail : Bool,
  include_head : Bool,
  tail_cluster_bbox : @geom.Rect?,
) -> Array[@geom.Point] {
  if include_tail || !include_head || points.length() != 4 {
    return points
  }
  let tail_rect = match tail_cluster_bbox {
    Some(rect) => rect
    None => return points
  }
  let ep = match end_point {
    Some(point) => point
    None => return points
  }
  let p0 = points[0]
  if !point_in_rect(p0, tail_rect) || point_in_rect(ep, tail_rect) {
    return points
  }
  let p3 = points[3]
  // Keep longer compound exits unchanged to match Graphviz's bezier control
  // points; only retune very short exits that collapse near the tail cluster.
  if point_dist(p0, p3) > 7.0 {
    return points
  }
  let p = if point_in_rect(p3, tail_rect) {
    line_rect_intersection_from_inside(p3, ep, tail_rect)
  } else {
    p0
  }
  let c2 : @geom.Point = { x: (p.x + ep.x) / 2.0, y: (p.y + ep.y) / 2.0 }
  let c3 : @geom.Point = { x: (c2.x + ep.x) / 2.0, y: (c2.y + ep.y) / 2.0 }
  let c1 : @geom.Point = { x: (c2.x + p.x) / 2.0, y: (c2.y + p.y) / 2.0 }
  [p, c1, c2, c3]
}
