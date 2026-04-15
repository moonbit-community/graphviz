// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "curve_point_line_distance handles degenerate and projected segments" {
  let degenerate = curve_point_line_distance(
    @edge_spline.point(3.0, 4.0),
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(0.0, 0.0),
  )
  let projected = curve_point_line_distance(
    @edge_spline.point(5.0, 4.0),
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(10.0, 0.0),
  )

  assert_eq(degenerate, 5.0)
  assert_eq(projected, 4.0)
}

///|
test "segment_intersects_rect ignores endpoint-only touches but detects true crossings" {
  let rect : @geom.Rect = { llx: 2.0, lly: 2.0, urx: 8.0, ury: 8.0 }

  let crossing = segment_intersects_rect(
    @edge_spline.point(0.0, 5.0),
    @edge_spline.point(10.0, 5.0),
    rect,
    0.000001,
  )
  let endpoint_touch = segment_intersects_rect(
    @edge_spline.point(0.0, 5.0),
    @edge_spline.point(2.0, 5.0),
    rect,
    0.000001,
  )
  let outside = segment_intersects_rect(
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(1.0, 1.0),
    rect,
    0.000001,
  )

  assert_true(crossing)
  assert_false(endpoint_touch)
  assert_false(outside)
}

///|
test "simplify_polyline keeps bends above tolerance and drops near-collinear points" {
  let points : Array[@geom.Point] = [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(5.0, 0.2),
    @edge_spline.point(10.0, 0.0),
    @edge_spline.point(15.0, 5.0),
    @edge_spline.point(20.0, 5.0),
  ]

  let simplified = simplify_polyline(points, 0.5)
  let unchanged = simplify_polyline(points, 0.0)

  assert_eq(simplified, [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(10.0, 0.0),
    @edge_spline.point(15.0, 5.0),
    @edge_spline.point(20.0, 5.0),
  ])
  assert_eq(unchanged, points)
}

///|
test "sameport_path_port_box shrinks inward for larger groups" {
  let regular = sameport_path_port_box(
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(2.0, 0.0),
    3,
  )
  let large = sameport_path_port_box(
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(2.0, 0.0),
    5,
  )

  assert_eq(regular, { llx: 1.99, lly: -0.01, urx: 2.01, ury: 0.01 })
  assert_eq(large.lly, -0.005)
  assert_eq(large.ury, 0.005)
  assert_eq(large.urx, 2.0)
  assert_true(Double::abs(large.llx - 1.99) < 0.0000001)
}
