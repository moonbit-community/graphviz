///|
fn point(x : Double, y : Double) -> @geom.Point {
  @edge_spline.point(x, y)
}

///|
fn point_add(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  @edge_spline.point_add(a, b)
}

///|
fn point_sub(a : @geom.Point, b : @geom.Point) -> @geom.Point {
  @edge_spline.point_sub(a, b)
}

///|
fn point_scale(a : @geom.Point, s : Double) -> @geom.Point {
  @edge_spline.point_scale(a, s)
}

///|
fn point_lerp(a : @geom.Point, b : @geom.Point, t : Double) -> @geom.Point {
  @edge_spline.point_lerp(a, b, t)
}

///|
fn libm_atan2(y : Double, x : Double) -> Double {
  @edge_spline.libm_atan2(y, x)
}

///|
fn libm_cos(x : Double) -> Double {
  @edge_spline.libm_cos(x)
}

///|
fn libm_sin(x : Double) -> Double {
  @edge_spline.libm_sin(x)
}

///|
fn libm_fma(x : Double, y : Double, z : Double) -> Double {
  @edge_spline.libm_fma(x, y, z)
}

///|
fn segment_length(a : @geom.Point, b : @geom.Point) -> Double {
  @edge_spline.segment_length(a, b)
}

///|
fn polyline_length(points : Array[@geom.Point]) -> Double {
  @edge_spline.polyline_length(points)
}
