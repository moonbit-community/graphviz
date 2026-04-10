// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "edge_spline_for_bezier_points offsets only interior control points when clipping and arrows are disabled" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)

  let anchor_size = @node_primitives.node_size_from_points(10.0, 10.0)
  let spline = edge_spline_for_bezier_points(
    edge,
    [point(0.0, 0.0), point(2.0, 1.0), point(4.0, 1.5), point(6.0, 2.0)],
    point(0.0, 0.0),
    point(6.0, 2.0),
    anchor_size,
    anchor_size,
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
    parallel_offset=3.0,
  )

  assert_eq(spline.start, None)
  assert_eq(spline.end, None)
  assert_eq(spline.points.length(), 4)
  assert_point_close(spline.points[0], point(0.0, 0.0))
  assert_point_close(spline.points[1], point(5.0, 1.0))
  assert_point_close(spline.points[2], point(7.0, 1.5))
  assert_point_close(spline.points[3], point(6.0, 2.0))
}
