///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_close(actual.x, expected.x, eps~)
  assert_close(actual.y, expected.y, eps~)
}

///|
fn sample_size(
  width_pt : Double,
  height_pt : Double,
) -> @node_primitives.NodeSize {
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}

///|
fn straight_bezier_points() -> Array[@geom.Point] {
  [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(10.0, 0.0),
    @edge_spline.point(20.0, 0.0),
    @edge_spline.point(30.0, 0.0),
  ]
}

///|
fn short_bezier_points() -> Array[@geom.Point] {
  [
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(10.0, 0.0),
    @edge_spline.point(20.0, 0.0),
  ]
}

///|
fn straight_spline_with_markers() -> @geom.Spline {
  {
    start: Some(@edge_spline.point(-1.0, 0.0)),
    end: Some(@edge_spline.point(31.0, 0.0)),
    points: straight_bezier_points(),
  }
}

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
fn build_emit_base(
  edge : @cgraph.Edge,
  swap_ends? : Bool = false,
  tail_clip_enabled? : Bool = false,
  head_clip_enabled? : Bool = false,
  is_dotted? : Bool = false,
  same_outer_cluster? : Bool = true,
  out_tail_anchor? : @geom.Point = @edge_spline.point(0.0, 0.0),
  out_head_anchor? : @geom.Point = @edge_spline.point(30.0, 0.0),
) -> EdgeRouteBase {
  let tail_node = edge.tail()
  let head_node = edge.head()
  let tail_pos = @edge_spline.point(0.0, 0.0)
  let head_pos = @edge_spline.point(30.0, 0.0)
  let tail_anchor = @edge_spline.point(5.0, 0.0)
  let head_anchor = @edge_spline.point(25.0, 0.0)
  let zero = @edge_spline.point(0.0, 0.0)
  let size = sample_size(10.0, 10.0)
  {
    edge,
    parallel_offset: 0.0,
    swap_ends,
    orig_tail_name: tail_node.name(),
    orig_head_name: head_node.name(),
    tail_name: tail_node.name(),
    head_name: head_node.name(),
    tail_port: edge.tail_port(),
    head_port: edge.head_port(),
    tail_node,
    head_node,
    tail_pos,
    head_pos,
    tail_size: size,
    head_size: size,
    mid_label_width_pt: 0.0,
    mid_label_height_pt: 0.0,
    tail_record_path_box: None,
    head_record_path_box: None,
    tail_anchor,
    head_anchor,
    head_port_rect: None,
    tail_port_side: 0,
    head_port_side: 0,
    tail_sameport_group_size: 0,
    head_sameport_group_size: 0,
    tail_clip_center: tail_pos,
    tail_clip_size: size,
    head_clip_center: head_pos,
    head_clip_size: size,
    tail_clip_enabled,
    head_clip_enabled,
    tail_clip: tail_anchor,
    head_clip: head_anchor,
    tail_slope: zero,
    head_slope: zero,
    force_segmented: false,
    tail_cluster_bbox: None,
    head_cluster_bbox: None,
    tail_rank: 0,
    head_rank: 1,
    is_flat_edge: false,
    is_flat_adjacent: false,
    vnodes: [],
    has_vnodes: false,
    use_pathplan: false,
    route_include_tail: false,
    route_include_head: false,
    arrow_len_override: None,
    is_dotted,
    same_outer_cluster,
    diff_local_cluster: false,
    same_local_cluster: true,
    out_tail_anchor,
    out_head_anchor,
    out_tail_clip: tail_anchor,
    out_head_clip: head_anchor,
    out_tail_pos: tail_pos,
    out_head_pos: head_pos,
    out_tail_size: size,
    out_head_size: size,
    rankdir: @rankdir.RankDir::TB,
    layout_rankdir: @rankdir.RankDir::TB,
    has_side_anchor: false,
  }
}

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
