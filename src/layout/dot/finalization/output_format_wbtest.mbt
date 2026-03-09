///|
fn assert_double_close(
  actual : Double,
  expected : Double,
  eps : Double,
) -> Unit raise {
  let ok = Double::is_close(actual, expected, absolute_tolerance=eps)
  if !ok {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
test "dot format helpers keep graphviz-like numeric strings" {
  assert_eq(trim_trailing_zeros("12.3400"), "12.34")
  assert_eq(trim_trailing_zeros("42"), "42")

  assert_eq(format_fixed(12.345, 2), "12.34")
  assert_eq(format_fixed(-12.345, 2), "-12.34")
  assert_eq(format_fixed_trim(2.5000, 4), "2.5")

  assert_double_close(round_to(1.23456, 3), 1.235, 0.000001)

  assert_eq(format_float(0.0), "0")
  assert_eq(format_float(12.34567), "12.346")
  assert_eq(format_float(123456.0), "1.2346e+05")
  assert_eq(format_float(0.0000123456), "1.2346e-05")
  assert_eq(format_float(-0.0000123456), "-1.2346e-05")

  assert_eq(format_dim(12.0), "12")
  let point : @geom.Point = { x: 12.5, y: -0.25 }
  assert_eq(format_point(point), "12.5,-0.25")

  let rect0 : @geom.Rect = { llx: 0.0, lly: 1.25, urx: 10.0, ury: 20.5 }
  let rect1 : @geom.Rect = { llx: -1.0, lly: -2.0, urx: 3.0, ury: 4.0 }
  assert_eq(format_rect(rect0), "0,1.25,10,20.5")
  assert_eq(format_rects([rect0, rect1]), "0,1.25,10,20.5 -1,-2,3,4")
}
