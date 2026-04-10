// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "edge_midpoint_for_layout matches straight-edge midpoint selection" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let edge_layout = layout_edge(edge, straight_spline())

  let polyline_mid = match edge_midpoint_for_layout(edge_layout, false) {
    Some(point) => point
    None => fail("expected polyline midpoint")
  }
  let spline_mid = match edge_midpoint_for_layout(edge_layout, true) {
    Some(point) => point
    None => fail("expected spline midpoint")
  }

  assert_point_close(polyline_mid, @edge_spline.point(4.5, 0.0), eps=0.01)
  assert_point_close(spline_mid, @edge_spline.point(4.5, 0.0), eps=0.01)
}

///|
test "edge_midpoint_for_layout returns the collapsed endpoint when tail and head coincide" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let same = @edge_spline.point(4.0, 4.0)
  let collapsed_spline : @geom.Spline = {
    start: Some(same),
    end: Some(same),
    points: [
      same,
      @edge_spline.point(6.0, 8.0),
      @edge_spline.point(8.0, 6.0),
      same,
    ],
  }
  let edge_layout = layout_edge(edge, collapsed_spline)

  assert_eq(edge_midpoint_for_layout(edge_layout, false), Some(same))
  assert_eq(edge_midpoint_for_layout(edge_layout, true), Some(same))
}
