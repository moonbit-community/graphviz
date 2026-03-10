///|
test "short_route_build_context derives linear-flat preferences from invisible and bottom-arrow cases" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)

  let invis_edge = graph.edge(
    graph.node("invis_tail"),
    graph.node("invis_head"),
  )
  invis_edge.set_attr("style", "invis")
  let invis_context = short_route_test_context(
    short_route_test_base(invis_edge),
    false,
  )
  assert_true(invis_context.prefer_linear_flat_invis)
  assert_false(invis_context.prefer_linear_flat_bottom_single_arrow)

  let bottom_edge = graph.edge(
    graph.node("bottom_tail"),
    graph.node("bottom_head"),
    tail_port={ name: None, compass: Some(@cgraph.Compass::S) },
    head_port={ name: None, compass: Some(@cgraph.Compass::S) },
  )
  let bottom_context = short_route_test_context(
    short_route_test_base(
      bottom_edge,
      tail_port=explicit_compass_port(@cgraph.Compass::S),
      head_port=explicit_compass_port(@cgraph.Compass::S),
      tail_port_side=PORT_SIDE_BOTTOM,
      head_port_side=PORT_SIDE_BOTTOM,
      route_include_head=true,
    ),
    true,
  )
  assert_false(bottom_context.prefer_linear_flat_invis)
  assert_true(bottom_context.prefer_linear_flat_bottom_single_arrow)
}

///|
test "build_short_route_spline_with_detour lowers bottom single-arrow fallback lines to node bottoms" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(
    graph.node("tail"),
    graph.node("head"),
    tail_port={ name: None, compass: Some(@cgraph.Compass::S) },
    head_port={ name: None, compass: Some(@cgraph.Compass::S) },
  )
  edge.set_attr("arrowhead", "none")
  let base = short_route_test_base(
    edge,
    tail_port=explicit_compass_port(@cgraph.Compass::S),
    head_port=explicit_compass_port(@cgraph.Compass::S),
    tail_port_side=PORT_SIDE_BOTTOM,
    head_port_side=PORT_SIDE_BOTTOM,
    route_include_head=true,
  )
  let context = short_route_test_context(base, true)
  let spec = short_route_spec_for_anchor_or_pathplan_points({
    points: [],
    using_pathplan: false,
    tail_anchor: base.tail_anchor,
    head_anchor: base.head_anchor,
    tail_clip_enabled: false,
    head_clip_enabled: false,
  })

  let result = build_short_route_spline_with_detour(base, context, spec)

  assert_true(context.prefer_linear_flat_bottom_single_arrow)
  assert_eq(result.raw_bezier, [])
  short_route_assert_points_close(result.spline.points, [
    @edge_spline.point(0.0, -5.0),
    @edge_spline.point(10.0 / 3.0, -5.0),
    @edge_spline.point(20.0 / 3.0, -5.0),
    @edge_spline.point(10.0, -5.0),
  ])
}
