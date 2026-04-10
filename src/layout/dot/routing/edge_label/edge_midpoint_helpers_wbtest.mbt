// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "edge endpoint helpers prefer markers then point fallbacks and return None without splines" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let marker_layout = layout_edge(edge, straight_spline_with_markers())
  let point_layout = layout_edge(edge, straight_spline())
  let empty_layout : DotLayoutEdge = {
    edge,
    splines: [],
    label_pos: None,
    head_label_pos: None,
    tail_label_pos: None,
    xlabel_pos: None,
  }

  assert_eq(
    edge_tail_point_for_layout(marker_layout),
    Some(@edge_spline.point(-1.0, 0.0)),
  )
  assert_eq(
    edge_head_point_for_layout(marker_layout),
    Some(@edge_spline.point(10.0, 0.0)),
  )
  assert_eq(
    edge_tail_point_for_layout(point_layout),
    Some(@edge_spline.point(0.0, 0.0)),
  )
  assert_eq(
    edge_head_point_for_layout(point_layout),
    Some(@edge_spline.point(9.0, 0.0)),
  )
  assert_eq(edge_tail_point_for_layout(empty_layout), None)
  assert_eq(edge_head_point_for_layout(empty_layout), None)
}

///|
test "dotneato_closest_point handles empty point sets and short splines" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let empty_layout : DotLayoutEdge = {
    edge,
    splines: [],
    label_pos: None,
    head_label_pos: None,
    tail_label_pos: None,
    xlabel_pos: None,
  }
  let no_points_layout = layout_edge(edge, {
    start: None,
    end: None,
    points: [],
  })
  let short_layout = layout_edge(edge, {
    start: None,
    end: None,
    points: [
      @edge_spline.point(2.0, 1.0),
      @edge_spline.point(8.0, 5.0),
      @edge_spline.point(12.0, 7.0),
    ],
  })

  assert_eq(
    dotneato_closest_point(empty_layout, @edge_spline.point(5.0, 5.0)),
    None,
  )
  assert_eq(
    dotneato_closest_point(no_points_layout, @edge_spline.point(5.0, 5.0)),
    None,
  )
  assert_eq(
    dotneato_closest_point(short_layout, @edge_spline.point(9.0, 6.0)),
    Some(@edge_spline.point(2.0, 1.0)),
  )
}
