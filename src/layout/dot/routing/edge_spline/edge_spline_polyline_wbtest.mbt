// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "edge_spline_for_polyline clamps orthogonal dual arrows on a single segment while preserving unclipped anchors" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)
  edge.set_attr("dir", "both")

  let anchor_size = @node_primitives.node_size_from_points(10.0, 10.0)
  let spline = edge_spline_for_polyline(
    edge,
    point(0.0, 0.0),
    point(10.0, 0.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(10.0, 0.0),
    @rankdir.RankDir::TB,
    true,
    true,
    true,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    arrow_len_override=Some(6.0),
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )

  assert_eq(spline.start, Some(point(0.0, 0.0)))
  assert_eq(spline.end, Some(point(10.0, 0.0)))
  assert_eq(spline.points.length(), 4)
  assert_point_close(spline.points[0], point(10.0 / 3.0, 0.0))
  assert_point_close(spline.points[1], point(10.0 / 3.0, 0.0))
  assert_point_close(spline.points[2], point(20.0 / 3.0, 0.0))
  assert_point_close(spline.points[3], point(20.0 / 3.0, 0.0))
  assert_true(spline.points[0].x < spline.points[3].x)
}

///|
test "edge_spline_for_polyline uses TB cardinal corner routing when ports are implicit" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)

  let anchor_size = @node_primitives.node_size_from_points(10.0, 10.0)
  let spline = edge_spline_for_polyline(
    edge,
    point(0.0, 0.0),
    point(10.0, -10.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(10.0, -10.0),
    @rankdir.RankDir::TB,
    true,
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )

  assert_eq(spline.start, None)
  assert_eq(spline.end, None)
  assert_eq(spline.points.length(), 7)
  assert_eq(spline.points, [
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, -10.0),
    point(0.0, -10.0),
    point(0.0, -10.0),
    point(10.0, -10.0),
    point(10.0, -10.0),
  ])
}

///|
test "edge_spline_for_polyline falls back to standard orthogonal midpoint routing when a port is explicit" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head, head_port={
    name: Some("p"),
    compass: Some(@cgraph.Compass::E),
  })

  let anchor_size = @node_primitives.node_size_from_points(10.0, 10.0)
  let spline = edge_spline_for_polyline(
    edge,
    point(0.0, 0.0),
    point(10.0, -10.0),
    anchor_size,
    anchor_size,
    point(0.0, 0.0),
    point(10.0, -10.0),
    @rankdir.RankDir::TB,
    true,
    false,
    false,
    tail_clip_enabled=false,
    head_clip_enabled=false,
    arrow_len_override=None,
    tail_cluster_bbox=None,
    head_cluster_bbox=None,
  )

  assert_eq(spline.start, None)
  assert_eq(spline.end, None)
  assert_eq(spline.points.length(), 10)
  assert_eq(spline.points, [
    point(0.0, 0.0),
    point(0.0, 0.0),
    point(0.0, -5.0),
    point(0.0, -5.0),
    point(0.0, -5.0),
    point(10.0, -5.0),
    point(10.0, -5.0),
    point(10.0, -5.0),
    point(10.0, -10.0),
    point(10.0, -10.0),
  ])
}
