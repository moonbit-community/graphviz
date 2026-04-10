// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "port_label_pos_from_points rotates the tangent direction by angle and distance" {
  let pos = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(4.0, 2.0),
    90.0,
    2.0,
    3.0,
    @node_geometry.GRAPHVIZ_PI,
  )

  assert_point_close(pos, @edge_spline.point(1.0, 8.0), eps=0.001)
}

///|
test "port_label_pos_from_points follows edge-local angle and distance scale" {
  let horizontal = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(5.0, 2.0),
    90.0,
    2.0,
    3.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  assert_point_close(horizontal, @edge_spline.point(1.0, 8.0), eps=0.001)

  let vertical = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(1.0, 6.0),
    0.0,
    0.5,
    4.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  assert_point_close(vertical, @edge_spline.point(1.0, 4.0), eps=0.001)
}
