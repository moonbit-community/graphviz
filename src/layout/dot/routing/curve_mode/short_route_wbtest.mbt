///|
fn explicit_compass_port(compass : @cgraph.Compass) -> @cgraph.Port? {
  Some({ name: None, compass: Some(compass) })
}

///|
fn short_route_assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn short_route_assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  short_route_assert_close(actual.x, expected.x, eps~)
  short_route_assert_close(actual.y, expected.y, eps~)
}

///|
fn short_route_assert_points_close(
  actual : Array[@geom.Point],
  expected : Array[@geom.Point],
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    short_route_assert_point_close(actual[i], expected[i], eps~)
  }
}

///|
fn short_route_test_base(
  edge : @cgraph.Edge,
  tail_anchor? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_anchor? : @geom.Point = @edge_spline.point(10.0, 0.0),
  tail_port? : @cgraph.Port? = None,
  head_port? : @cgraph.Port? = None,
  tail_port_side? : Int = 0,
  head_port_side? : Int = 0,
  route_include_tail? : Bool = false,
  route_include_head? : Bool = false,
  tail_slope? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_slope? : @geom.Point = @edge_spline.point(0.0, 0.0),
) -> EdgeRouteBase {
  let size = @node_primitives.node_size_from_points(10.0, 10.0)
  {
    edge,
    parallel_offset: 0.0,
    swap_ends: false,
    orig_tail_name: edge.tail().name(),
    orig_head_name: edge.head().name(),
    tail_name: edge.tail().name(),
    head_name: edge.head().name(),
    tail_port,
    head_port,
    tail_node: edge.tail(),
    head_node: edge.head(),
    tail_pos: tail_anchor,
    head_pos: head_anchor,
    tail_size: size,
    head_size: size,
    mid_label_width_pt: 0.0,
    mid_label_height_pt: 0.0,
    tail_record_path_box: None,
    head_record_path_box: None,
    tail_anchor,
    head_anchor,
    head_port_rect: None,
    tail_port_side,
    head_port_side,
    tail_sameport_group_size: 0,
    head_sameport_group_size: 0,
    tail_clip_center: tail_anchor,
    tail_clip_size: size,
    head_clip_center: head_anchor,
    head_clip_size: size,
    tail_clip_enabled: false,
    head_clip_enabled: false,
    tail_clip: tail_anchor,
    head_clip: head_anchor,
    tail_slope,
    head_slope,
    force_segmented: false,
    tail_cluster_bbox: None,
    head_cluster_bbox: None,
    tail_rank: 0,
    head_rank: 1,
    is_flat_edge: true,
    is_flat_adjacent: false,
    vnodes: [],
    has_vnodes: false,
    use_pathplan: false,
    route_include_tail,
    route_include_head,
    arrow_len_override: None,
    is_dotted: false,
    same_outer_cluster: true,
    diff_local_cluster: false,
    same_local_cluster: true,
    out_tail_anchor: tail_anchor,
    out_head_anchor: head_anchor,
    out_tail_clip: tail_anchor,
    out_head_clip: head_anchor,
    out_tail_pos: tail_anchor,
    out_head_pos: head_anchor,
    out_tail_size: size,
    out_head_size: size,
    rankdir: RankDir::TB,
    layout_rankdir: RankDir::TB,
    has_side_anchor: false,
  }
}

///|
fn short_route_test_context(
  base : EdgeRouteBase,
  has_explicit_port : Bool,
) -> ShortRouteBuildContext {
  short_route_build_context({
    base,
    positions: Map::new(),
    sizes: Map::new(),
    ranks: Map::new(),
    rank_y: Map::new(),
    rank_ht1: Map::new(),
    rank_ht2: Map::new(),
    ranksep_pt: 12.0,
    route_barriers: [],
    using_pathplan: false,
    has_explicit_port,
    label_width_pt: 0.0,
    nodesep_pt: 12.0,
    force_segmented: false,
    curve_offset: 0.0,
    curve_skew: 1.0,
  })
}

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
