// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "compound head clipping moves only the arrow when the curve ends outside the cluster" {
  let points = [
    point(0.0, 0.0),
    point(2.0, 0.0),
    point(4.0, 0.0),
    point(6.0, 0.0),
  ]
  let clipped = clip_compound_spline(
    { points, start_point: None, end_point: Some(point(10.0, 0.0)), },
    point(0.0, 0.0),
    point(10.0, 0.0),
    None,
    Some({ llx: 8.0, lly: -2.0, urx: 12.0, ury: 2.0, }),
    0.0,
    10.0,
  )
  @test.assert_eq(clipped.points, points)
  @test.assert_eq(clipped.end_point, Some(point(8.0, 0.0)))
}

///|
test "compound short tail exits use the arrow endpoint to construct the degenerate curve" {
  let clipped = clip_compound_spline(
    {
      points: [
        point(0.0, 12.0),
        point(0.0, 11.0),
        point(0.0, 10.0),
        point(0.0, 9.0),
      ],
      start_point: None,
      end_point: Some(point(0.0, 0.0)),
    },
    point(0.0, 15.0),
    point(0.0, 0.0),
    Some({ llx: -2.0, lly: 8.0, urx: 2.0, ury: 20.0, }),
    None,
    0.0,
    10.0,
  )
  @test.assert_eq(clipped.points, [
    point(0.0, 8.0),
    point(0.0, 6.0),
    point(0.0, 4.0),
    point(0.0, 2.0),
  ])
  @test.assert_eq(clipped.end_point, Some(point(0.0, 0.0)))
}

///|
test "compound target clusters not containing the endpoint leave the spline unchanged" {
  let points = [
    point(0.0, 0.0),
    point(2.0, 0.0),
    point(4.0, 0.0),
    point(6.0, 0.0),
  ]
  let clipped = clip_compound_spline(
    { points, start_point: None, end_point: Some(point(10.0, 0.0)), },
    point(0.0, 0.0),
    point(10.0, 0.0),
    None,
    Some({ llx: 3.0, lly: -2.0, urx: 5.0, ury: 2.0, }),
    0.0,
    10.0,
  )
  @test.assert_eq(clipped.points, points)
  @test.assert_eq(clipped.end_point, Some(point(10.0, 0.0)))
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
fn clip_spline_end_to_bbox(
  points : Array[@geom.Point],
  rect : @geom.Rect,
) -> Array[@geom.Point] {
  find_spline_end_bbox_cut(points, rect).unwrap_or(points)
}

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
  let end_bbox : @geom.Rect = { llx: 5.0, lly: -1.0, urx: 7.0, ury: 1.0, }
  let start_bbox : @geom.Rect = { llx: 0.0, lly: -1.0, urx: 4.0, ury: 1.0, }

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
