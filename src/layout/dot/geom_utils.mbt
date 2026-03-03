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
