// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "finalize_edge_spline reverses output and applies dotted anchor bias" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let base = build_emit_base(
    edge,
    swap_ends=true,
    is_dotted=true,
    same_outer_cluster=false,
    out_tail_anchor=@edge_spline.point(0.0, 10.0),
    out_head_anchor=@edge_spline.point(30.0, 20.0),
  )
  let result = edge_spline_result_for_bezier(
    straight_spline_with_markers(),
    straight_bezier_points(),
    2.0,
    true,
  )

  let spline = finalize_edge_spline(base, result)

  assert_eq(spline.start, Some(@edge_spline.point(31.0, 0.0)))
  assert_eq(spline.end, Some(@edge_spline.point(-1.0, 0.0)))
  assert_point_close(spline.points[0], @edge_spline.point(30.0, 0.0))
  assert_point_close(spline.points[1], @edge_spline.point(20.0, 7.0))
  assert_point_close(spline.points[2], @edge_spline.point(10.0, 14.0))
  assert_point_close(spline.points[3], @edge_spline.point(0.0, 0.0))
}

///|
test "edge_sameport_direct_flags swaps samehead and sametail semantics with swapped routing" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("samehead", "group")

  let normal = edge_sameport_direct_flags(edge, false)
  assert_false(normal.tail_direct)
  assert_true(normal.head_direct)

  let swapped = edge_sameport_direct_flags(edge, true)
  assert_true(swapped.tail_direct)
  assert_false(swapped.head_direct)
}

///|
test "edge_render_clip_flags keeps direct sameport endpoint unclipped" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("samehead", "group")
  let base = build_emit_base(
    edge,
    tail_clip_enabled=false,
    head_clip_enabled=false,
  )

  let clip_flags = edge_render_clip_flags(base)

  assert_true(clip_flags.tail_clip_enabled)
  assert_false(clip_flags.head_clip_enabled)
}

///|
test "edge_render_clip_flags preserves explicit no-clip attrs" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("tailclip", "false")
  edge.set_attr("headclip", "0")
  let base = build_emit_base(
    edge,
    tail_clip_enabled=false,
    head_clip_enabled=false,
  )

  let clip_flags = edge_render_clip_flags(base)

  assert_false(clip_flags.tail_clip_enabled)
  assert_false(clip_flags.head_clip_enabled)
}

///|
test "rebuild_spline_for_render keeps short raw beziers unchanged" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let base = build_emit_base(
    edge,
    tail_clip_enabled=false,
    head_clip_enabled=false,
  )
  let raw_bezier = short_bezier_points()
  let original = edge_spline_result_for_bezier(
    { start: None, end: None, points: raw_bezier },
    raw_bezier,
    5.0,
    false,
  )

  let rebuilt = rebuild_spline_for_render(base, original)

  assert_eq(rebuilt.spline.points, raw_bezier)
  assert_eq(rebuilt.raw_bezier, raw_bezier)
  assert_eq(rebuilt.label_pad_boost, 5.0)
  assert_false(rebuilt.apply_dotted_adjustment)
}
