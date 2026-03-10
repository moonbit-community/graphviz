///|
fn assert_bbox_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn assert_bbox_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_bbox_close(actual.x, expected.x, eps~)
  assert_bbox_close(actual.y, expected.y, eps~)
}

///|
test "bbox spline clipping trims straight bezier at the first boundary hit" {
  let points : Array[@geom.Point] = [
    point(0.0, 0.0),
    point(3.0, 0.0),
    point(6.0, 0.0),
    point(9.0, 0.0),
  ]
  let end_bbox : @geom.Rect = { llx: 5.0, lly: -1.0, urx: 7.0, ury: 1.0 }
  let start_bbox : @geom.Rect = { llx: 0.0, lly: -1.0, urx: 4.0, ury: 1.0 }

  let end_clipped = clip_spline_end_to_bbox(points, end_bbox)
  let start_clipped = clip_spline_start_to_bbox(points, start_bbox)

  assert_eq(end_clipped.length(), 4)
  assert_bbox_point_close(end_clipped[0], point(0.0, 0.0))
  assert_bbox_point_close(end_clipped[1], point(1.6666667, 0.0), eps=0.01)
  assert_bbox_point_close(end_clipped[2], point(3.3333333, 0.0), eps=0.01)
  assert_bbox_point_close(end_clipped[3], point(5.0, 0.0), eps=0.01)

  assert_eq(start_clipped.length(), 4)
  assert_bbox_point_close(start_clipped[0], point(4.0, 0.0), eps=0.01)
  assert_bbox_point_close(start_clipped[1], point(5.6666667, 0.0), eps=0.01)
  assert_bbox_point_close(start_clipped[2], point(7.3333333, 0.0), eps=0.01)
  assert_bbox_point_close(start_clipped[3], point(9.0, 0.0))
}
