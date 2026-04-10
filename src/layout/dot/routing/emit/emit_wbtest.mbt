// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn layout_edge(edge : @cgraph.Edge, spline : @geom.Spline) -> DotLayoutEdge {
  {
    edge,
    splines: [spline],
    label_pos: None,
    head_label_pos: Some(@edge_spline.point(100.0, 10.0)),
    tail_label_pos: Some(@edge_spline.point(200.0, 20.0)),
    xlabel_pos: Some(@edge_spline.point(300.0, 30.0)),
  }
}

///|
test "build_self_edge_layout overrides label position from the route" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  let edge = graph.edge(node, node)
  let base = build_emit_base(edge)
  let route : SelfEdgeRoute = {
    points: straight_bezier_points(),
    label_pos: Some(@edge_spline.point(15.0, 9.0)),
  }

  let layout = build_self_edge_layout(base, route, input => {
    layout_edge(input.base.edge, input.spline)
  })

  assert_eq(layout.label_pos, Some(@edge_spline.point(15.0, 9.0)))
  assert_eq(layout.head_label_pos, Some(@edge_spline.point(100.0, 10.0)))
  assert_eq(layout.tail_label_pos, Some(@edge_spline.point(200.0, 20.0)))
  assert_eq(layout.xlabel_pos, Some(@edge_spline.point(300.0, 30.0)))
  assert_eq(layout.splines.length(), 1)
}

///|
test "build_flat_adjacent_layout propagates swap_ends to the final rendered spline" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let normal = build_flat_adjacent_layout(
    build_emit_base(edge),
    straight_bezier_points(),
    input => layout_edge(input.base.edge, input.spline),
  )
  let base = build_emit_base(edge, swap_ends=true)
  let seen_pad = Ref::new(-1.0)
  let seen_dotted = Ref::new(true)

  let layout = build_flat_adjacent_layout(base, straight_bezier_points(), input => {
    seen_pad.val = input.spline_result.label_pad_boost
    seen_dotted.val = input.spline_result.apply_dotted_adjustment
    layout_edge(input.base.edge, input.spline)
  })

  assert_eq(seen_pad.val, 0.0)
  assert_false(seen_dotted.val)
  let swapped_points = layout.splines[0].points
  let normal_points = normal.splines[0].points
  let last = normal_points.length() - 1
  assert_point_close(swapped_points[0], normal_points[last], eps=0.001)
  assert_point_close(swapped_points[last], normal_points[0], eps=0.001)
}

///|
test "build_regular_bezier_layout reuses shared spline-result metadata and raw bezier points" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let base = build_emit_base(edge)
  let shared = edge_spline_result_for_bezier(
    straight_spline_with_markers(),
    straight_bezier_points(),
    5.0,
    true,
  )
  let seen_pad = Ref::new(0.0)
  let seen_dotted = Ref::new(false)
  let seen_raw = Ref::new(short_bezier_points())

  let layout = build_regular_bezier_layout(base, shared, input => {
    seen_pad.val = input.spline_result.label_pad_boost
    seen_dotted.val = input.spline_result.apply_dotted_adjustment
    seen_raw.val = input.spline_result.raw_bezier
    layout_edge(input.base.edge, input.spline)
  })

  assert_eq(seen_pad.val, 5.0)
  assert_true(seen_dotted.val)
  assert_eq(seen_raw.val, straight_bezier_points())
  assert_eq(layout.splines.length(), 1)
  assert_eq(layout.edge.id(), edge.id())
}
