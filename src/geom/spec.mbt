///|
/// 2D point in points (1/72 inch).
pub(all) struct Point {
  x : Double
  y : Double
} derive(Show, Eq)

///|
/// Size in points (1/72 inch).
pub(all) struct Size {
  width : Double
  height : Double
} derive(Show, Eq)

///|
/// Axis-aligned rectangle in points.
/// Invariant: llx <= urx and lly <= ury.
pub(all) struct Rect {
  llx : Double
  lly : Double
  urx : Double
  ury : Double
} derive(Show, Eq)

///|
/// Polyline path in points.
pub(all) struct Polyline {
  points : Array[Point]
} derive(Show, Eq)

///|
/// Cubic Bezier control points in points.
/// Invariant: points.length() >= 4 and (points.length() - 1) % 3 == 0.
pub(all) struct Bezier {
  points : Array[Point]
} derive(Show, Eq)

///|
/// Edge spline representation with optional clip points.
/// Invariant: points.length() >= 4 and (points.length() - 1) % 3 == 0.
pub(all) struct Spline {
  start : Point?
  end : Point?
  points : Array[Point]
} derive(Show, Eq)
