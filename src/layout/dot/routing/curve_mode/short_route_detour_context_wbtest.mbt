///|
test "needs_record_port_detour depends on rankdir axis and explicit record ports" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  tail.set_attr("shape", "record")
  let head = graph.node("head")

  let tb_needed = needs_record_port_detour({
    using_pathplan: false,
    is_flat_edge: false,
    tail_node: tail,
    head_node: head,
    tail_port: explicit_compass_port(@cgraph.Compass::E),
    head_port: None,
    tail_slope_line: @edge_spline.point(1.0, 0.0),
    head_slope_line: @edge_spline.point(0.0, 0.0),
    layout_rankdir: RankDir::TB,
  })
  let tb_not_needed = needs_record_port_detour({
    using_pathplan: false,
    is_flat_edge: false,
    tail_node: tail,
    head_node: head,
    tail_port: explicit_compass_port(@cgraph.Compass::E),
    head_port: None,
    tail_slope_line: @edge_spline.point(0.0, 1.0),
    head_slope_line: @edge_spline.point(0.0, 0.0),
    layout_rankdir: RankDir::TB,
  })
  let lr_needed = needs_record_port_detour({
    using_pathplan: false,
    is_flat_edge: false,
    tail_node: tail,
    head_node: head,
    tail_port: explicit_compass_port(@cgraph.Compass::E),
    head_port: None,
    tail_slope_line: @edge_spline.point(0.0, 1.0),
    head_slope_line: @edge_spline.point(0.0, 0.0),
    layout_rankdir: RankDir::LR,
  })

  assert_true(tb_needed)
  assert_false(tb_not_needed)
  assert_true(lr_needed)
}

///|
test "flat_detour_candidate_flags distinguishes no-arrow and top-single-arrow cases" {
  let no_arrow = flat_detour_candidate_flags({
    using_pathplan: false,
    is_flat_edge: true,
    has_explicit_port: false,
    label_width_pt: 0.0,
    tail_port_side: 0,
    head_port_side: 0,
    layout_rankdir: RankDir::TB,
    route_include_tail: false,
    route_include_head: false,
  })
  let top_single_arrow = flat_detour_candidate_flags({
    using_pathplan: false,
    is_flat_edge: true,
    has_explicit_port: true,
    label_width_pt: 0.0,
    tail_port_side: PORT_SIDE_TOP,
    head_port_side: PORT_SIDE_TOP,
    layout_rankdir: RankDir::TB,
    route_include_tail: false,
    route_include_head: true,
  })
  let blocked = flat_detour_candidate_flags({
    using_pathplan: false,
    is_flat_edge: true,
    has_explicit_port: true,
    label_width_pt: 4.0,
    tail_port_side: PORT_SIDE_TOP,
    head_port_side: PORT_SIDE_TOP,
    layout_rankdir: RankDir::TB,
    route_include_tail: false,
    route_include_head: true,
  })

  assert_true(no_arrow.no_arrow)
  assert_false(no_arrow.top_single_arrow)
  assert_false(top_single_arrow.no_arrow)
  assert_true(top_single_arrow.top_single_arrow)
  assert_false(blocked.no_arrow)
  assert_false(blocked.top_single_arrow)
}

///|
test "short_route_detour_context zeroes implicit-port slopes before deriving flags" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")

  let context = short_route_detour_context({
    using_pathplan: false,
    is_flat_edge: true,
    tail_node: tail,
    head_node: head,
    tail_port: None,
    head_port: None,
    tail_slope: @edge_spline.point(3.0, 1.0),
    head_slope: @edge_spline.point(-2.0, 5.0),
    layout_rankdir: RankDir::TB,
    has_explicit_port: false,
    label_width_pt: 0.0,
    tail_port_side: 0,
    head_port_side: 0,
    route_include_tail: false,
    route_include_head: false,
  })

  assert_eq(context.tail_slope_line, @edge_spline.point(0.0, 0.0))
  assert_eq(context.head_slope_line, @edge_spline.point(0.0, 0.0))
  assert_false(context.needs_record_detour)
  assert_true(context.flat_no_arrow_candidate)
  assert_false(context.flat_top_compass_single_arrow_candidate)
}
