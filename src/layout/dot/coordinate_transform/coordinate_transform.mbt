///|
/// Pure coordinate transform kernels for rankdir mapping, bbox rotation, and
/// translation of points/splines. These helpers are independent of
/// DotLayoutGraph recursion.

type RankDir = @rankdir.RankDir

///|
/// Graphviz parity: rankdir coordinate transform aligned to
/// refs/graphviz/lib/common/postproc.c (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
pub fn transform_point(
  point : @geom.Point,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point {
  match rankdir {
    RankDir::TB => point
    RankDir::BT => { x: point.x, y: bbox.lly + bbox.ury - point.y }
    RankDir::LR => { x: bbox.lly + bbox.ury - point.y, y: point.x }
    RankDir::RL => { x: point.y, y: point.x }
  }
}

///|
pub fn transform_optional_point(
  point : @geom.Point?,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Point? {
  match point {
    Some(value) => Some(transform_point(value, bbox, rankdir))
    None => None
  }
}

///|
pub fn transform_spline(
  spline : @geom.Spline,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(transform_point(point, bbox, rankdir))
  }
  {
    start: transform_optional_point(spline.start, bbox, rankdir),
    end: transform_optional_point(spline.end, bbox, rankdir),
    points,
  }
}

///|
pub fn shift_point(point : @geom.Point, dx : Double, dy : Double) -> @geom.Point {
  { x: point.x + dx, y: point.y + dy }
}

///|
pub fn shift_optional_point(
  point : @geom.Point?,
  dx : Double,
  dy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(shift_point(value, dx, dy))
    None => None
  }
}

///|
pub fn shift_spline(
  spline : @geom.Spline,
  dx : Double,
  dy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(shift_point(point, dx, dy))
  }
  {
    start: shift_optional_point(spline.start, dx, dy),
    end: shift_optional_point(spline.end, dx, dy),
    points,
  }
}

///|
/// Graphviz parity: bbox rotation aligned to refs/graphviz/lib/common/postproc.c
/// (translate_bb/map_point).
/// Do not change behavior without updating fixtures/tests.
pub fn transform_bbox_with_root(
  bbox : @geom.Rect,
  root_bbox : @geom.Rect,
  rankdir : RankDir,
) -> @geom.Rect {
  if rankdir == RankDir::TB {
    return bbox
  }
  let points : Array[@geom.Point] = [
    { x: bbox.llx, y: bbox.lly },
    { x: bbox.llx, y: bbox.ury },
    { x: bbox.urx, y: bbox.lly },
    { x: bbox.urx, y: bbox.ury },
  ]
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  let mut first = true
  for point in points {
    let mapped = transform_point(point, root_bbox, rankdir)
    if first {
      min_x = mapped.x
      max_x = mapped.x
      min_y = mapped.y
      max_y = mapped.y
      first = false
    } else {
      if mapped.x < min_x { min_x = mapped.x }
      if mapped.x > max_x { max_x = mapped.x }
      if mapped.y < min_y { min_y = mapped.y }
      if mapped.y > max_y { max_y = mapped.y }
    }
  }
  { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
}

