///|
/// Shared geometry scaling helpers used by postprocess and routing ratio paths.

///|
pub fn scale_point(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  { x: point.x * sx, y: point.y * sy }
}

///|
pub fn scale_point_rounded(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  let scaled = scale_point(point, sx, sy)
  { x: scaled.x.round(), y: scaled.y.round() }
}

///|
pub fn scale_optional_point(
  point : @geom.Point?,
  sx : Double,
  sy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(scale_point(value, sx, sy))
    None => None
  }
}
