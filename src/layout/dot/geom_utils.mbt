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
fn point_line_distance(
  point : @geom.Point,
  a : @geom.Point,
  b : @geom.Point,
) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  if dx == 0.0 && dy == 0.0 {
    return @math.hypot(point.x - a.x, point.y - a.y)
  }
  let t = ((point.x - a.x) * dx + (point.y - a.y) * dy) / (dx * dx + dy * dy)
  let proj = @geom.Point::{ x: a.x + t * dx, y: a.y + t * dy }
  @math.hypot(point.x - proj.x, point.y - proj.y)
}

///|
fn segment_intersects_rect(
  start : @geom.Point,
  end : @geom.Point,
  rect : @geom.Rect,
  eps : Double,
) -> Bool {
  let dx = end.x - start.x
  let dy = end.y - start.y
  let mut t0 = 0.0
  let mut t1 = 1.0
  let update = (p : Double, q : Double) => {
    if Double::abs(p) < 0.0000001 {
      if q < 0.0 { return false } else { return true }
    }
    let r = q / p
    if p < 0.0 {
      if r > t1 { return false }
      if r > t0 { t0 = r }
    } else {
      if r < t0 { return false }
      if r < t1 { t1 = r }
    }
    true
  }
  if !update(-dx, start.x - rect.llx) { return false }
  if !update(dx, rect.urx - start.x) { return false }
  if !update(-dy, start.y - rect.lly) { return false }
  if !update(dy, rect.ury - start.y) { return false }
  if t1 < 0.0 || t0 > 1.0 {
    return false
  }
  let min_t = if t0 < 0.0 { 0.0 } else { t0 }
  let max_t = if t1 > 1.0 { 1.0 } else { t1 }
  if max_t <= eps || min_t >= 1.0 - eps {
    return false
  }
  true
}

///|
fn detour_polyline_for_rects(
  tail : @geom.Point,
  head : @geom.Point,
  tail_rect : @geom.Rect,
  head_rect : @geom.Rect,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> Array[@geom.Point] {
  let detour_margin = max_double(nodesep_pt * 0.75, 8.0)
  let exit_base = max_double(nodesep_pt * 1.25, 16.0)
  let entry_base = max_double(nodesep_pt * 0.3, 5.71)
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let dy = head.y - tail.y
      let total = Double::abs(dy)
      let exit_turn = if total > 0.0 {
        min_double(exit_base, total / 2.0)
      } else {
        exit_base
      }
      let entry_turn = if total > 0.0 {
        min_double(entry_base, total / 2.0)
      } else {
        entry_base
      }
      let exit_y =
        if dy < 0.0 {
        tail_rect.lly - exit_turn
      } else {
        tail_rect.ury + exit_turn
      }
      let entry_y =
        if dy < 0.0 {
        head_rect.lly - entry_turn
      } else {
        head_rect.ury + entry_turn
      }
      let left_x = min_double(tail_rect.llx, head_rect.llx) - detour_margin
      let right_x = max_double(tail_rect.urx, head_rect.urx) + detour_margin
      let path_len = (detour_x : Double) => {
        Double::abs(tail.y - exit_y) +
        Double::abs(tail.x - detour_x) +
        Double::abs(exit_y - entry_y) +
        Double::abs(head.x - detour_x) +
        Double::abs(head.y - entry_y)
      }
      let detour_x =
        if path_len(left_x) <= path_len(right_x) { left_x } else { right_x }
      [
        tail,
        @edge_spline.point(tail.x, exit_y),
        @edge_spline.point(detour_x, exit_y),
        @edge_spline.point(detour_x, entry_y),
        @edge_spline.point(head.x, entry_y),
        head,
      ]
    }
    RankDir::LR | RankDir::RL => {
      let dx = head.x - tail.x
      let total = Double::abs(dx)
      let exit_turn = if total > 0.0 {
        min_double(exit_base, total / 2.0)
      } else {
        exit_base
      }
      let entry_turn = if total > 0.0 {
        min_double(entry_base, total / 2.0)
      } else {
        entry_base
      }
      let exit_x =
        if dx < 0.0 {
        tail_rect.llx - exit_turn
      } else {
        tail_rect.urx + exit_turn
      }
      let entry_x =
        if dx < 0.0 {
        head_rect.llx - entry_turn
      } else {
        head_rect.urx + entry_turn
      }
      let lower_y = min_double(tail_rect.lly, head_rect.lly) - detour_margin
      let upper_y = max_double(tail_rect.ury, head_rect.ury) + detour_margin
      let path_len = (detour_y : Double) => {
        Double::abs(tail.x - exit_x) +
        Double::abs(tail.y - detour_y) +
        Double::abs(exit_x - entry_x) +
        Double::abs(head.y - detour_y) +
        Double::abs(head.x - entry_x)
      }
      let detour_y =
        if path_len(lower_y) <= path_len(upper_y) { lower_y } else { upper_y }
      [
        tail,
        @edge_spline.point(exit_x, tail.y),
        @edge_spline.point(exit_x, detour_y),
        @edge_spline.point(entry_x, detour_y),
        @edge_spline.point(entry_x, head.y),
        head,
      ]
    }
  }
}

///|
///|
fn simplify_polyline(
  points : Array[@geom.Point],
  tol : Double,
) -> Array[@geom.Point] {
  if tol <= 0.0 || points.length() <= 2 {
    return points
  }
  let last = points.length() - 1
  let keep = Array::make(points.length(), false)
  keep[0] = true
  keep[last] = true
  let stack : Array[(Int, Int)] = []
  stack.push((0, last))
  while stack.length() > 0 {
    let top = stack.length() - 1
    let (start, end) = stack[top]
    let _ = stack.pop()
    if end - start <= 1 {
      continue
    }
    let mut max_dist = -1.0
    let mut max_idx = -1
    let start_point = points[start]
    let end_point = points[end]
    for i in (start + 1)..<end {
      let dist = point_line_distance(points[i], start_point, end_point)
      if dist > max_dist {
        max_dist = dist
        max_idx = i
      }
    }
    if max_idx != -1 && max_dist > tol {
      keep[max_idx] = true
      stack.push((start, max_idx))
      stack.push((max_idx, end))
    }
  }
  let out : Array[@geom.Point] = []
  for i in 0..<points.length() {
    if keep[i] {
      out.push(points[i])
    }
  }
  out
}
