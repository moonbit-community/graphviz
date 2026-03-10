///|
test "recover_pathplan_slack consumes segment vnodes in rank direction and only recovers once per key" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let base = build_route_base(edge, tail_rank=3, head_rank=1, has_vnodes=true)
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = {
    "v1": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
    "v2": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
  }
  let input = sample_regular_pass_input(
    { "a": 3, "b": 1 },
    { "v1": 2, "v2": 1 },
    Map::new(),
    vnode_sizes,
    { 2: 20.0, 1: 10.0 },
  )
  let spline_result : EdgeSplineResult = {
    spline: { start: None, end: None, points: [] },
    label_pad_boost: 0.0,
    using_pathplan: true,
    pathplan_boxes: [],
    pathplan_points: [],
    raw_bezier: [],
    pathplan_segments: [
      {
        points: [],
        barriers: [],
        boxes: [{ llx: 0.0, lly: 0.0, urx: 10.0, ury: 4.0 }],
        vnodes: ["v1", "v2"],
      },
    ],
    apply_dotted_adjustment: false,
  }
  let recover_key = recover_slack_key_for_edge(edge)
  let recover_edge_id_by_key : Map[String, Int] = Map::new()
  recover_edge_id_by_key[recover_key] = edge.id()
  let recovered_slack_keys : Map[String, Bool] = Map::new()
  let recovered_orders : Array[String] = []
  let callbacks : RoutingCallbacks = {
    recover_slack_vnodes_fn: recover_input => {
      recovered_orders.push(recover_input.ordered_vnodes.join(","))
    },
    build_edge_layout_fn: layout_input => {
      build_layout_edge(layout_input.base.edge, 0.0)
    },
    self_edge_label_height_fn: (_edge, _rankdir) => 0.0,
    self_edge_label_width_fn: (_edge, _rankdir) => 0.0,
    edge_port_label_pos_fn: _ => None,
  }

  recover_pathplan_slack({
    edge,
    base,
    spline_result,
    input,
    recover_edge_id_by_key,
    recovered_slack_keys,
    callbacks,
  })
  recover_pathplan_slack({
    edge,
    base,
    spline_result,
    input,
    recover_edge_id_by_key,
    recovered_slack_keys,
    callbacks,
  })

  assert_eq(recovered_orders, ["v2,v1"])
  assert_eq(recovered_slack_keys.get(recover_key), Some(true))
}

///|
test "recover_pathplan_slack falls back to limited pathplan boxes when segments are absent" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let base = build_route_base(
    edge,
    tail_rank=0,
    head_rank=2,
    has_vnodes=true,
    vnodes=["v1", "v2"],
    tail_clip_enabled=true,
    head_clip_enabled=true,
  )
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = {
    "v1": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
    "v2": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
  }
  let input = sample_regular_pass_input(
    { "a": 0, "b": 2 },
    { "v1": 1, "v2": 2 },
    Map::new(),
    vnode_sizes,
    { 1: 10.0, 2: 20.0 },
  )
  let spline_result : EdgeSplineResult = {
    spline: spline_with_start_x(0.0),
    label_pad_boost: 0.0,
    using_pathplan: true,
    pathplan_boxes: [
      { llx: -4.0, lly: -4.0, urx: 12.0, ury: 4.0 },
      { llx: 18.0, lly: -4.0, urx: 34.0, ury: 4.0 },
    ],
    pathplan_points: [
      @edge_spline.point(0.0, 0.0),
      @edge_spline.point(15.0, 0.0),
      @edge_spline.point(30.0, 0.0),
    ],
    raw_bezier: straight_bezier_points(),
    pathplan_segments: [],
    apply_dotted_adjustment: false,
  }
  let expected_boxes = @routesplines.limit_boxes_for_spline(
    spline_result.pathplan_boxes,
    spline_result.raw_bezier,
    fallback_polyline=spline_result.pathplan_points,
  )
  let recover_key = recover_slack_key_for_edge(edge)
  let recovered_slack_keys : Map[String, Bool] = Map::new()
  let recovered_orders : Array[String] = []
  let recovered_box_counts : Array[Int] = []
  let callbacks : RoutingCallbacks = {
    recover_slack_vnodes_fn: recover_input => {
      recovered_orders.push(recover_input.ordered_vnodes.join(","))
      recovered_box_counts.push(recover_input.boxes.length())
    },
    build_edge_layout_fn: layout_input => {
      build_layout_edge(layout_input.base.edge, 0.0)
    },
    self_edge_label_height_fn: (_edge, _rankdir) => 0.0,
    self_edge_label_width_fn: (_edge, _rankdir) => 0.0,
    edge_port_label_pos_fn: _ => None,
  }

  recover_pathplan_slack({
    edge,
    base,
    spline_result,
    input,
    recover_edge_id_by_key: Map::new(),
    recovered_slack_keys,
    callbacks,
  })

  assert_eq(recovered_orders, ["v1,v2"])
  assert_eq(recovered_box_counts, [expected_boxes.length()])
  assert_eq(recovered_slack_keys.get(recover_key), Some(true))
}

///|
test "collect_parallel_reuse_siblings only expands from the first grouped edge with a bezier" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)
  let regular_parallel_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  regular_parallel_groups[@edge_identity.edge_vnode_key(edge_1)] = [
    edge_1, edge_2, edge_3,
  ]

  let leader_siblings = collect_parallel_reuse_siblings(
    edge_1,
    straight_bezier_points(),
    regular_parallel_groups,
  )
  let follower_siblings = collect_parallel_reuse_siblings(
    edge_2,
    straight_bezier_points(),
    regular_parallel_groups,
  )
  let empty_bezier_siblings = collect_parallel_reuse_siblings(
    edge_1,
    [],
    regular_parallel_groups,
  )

  assert_eq(leader_siblings.map(fn(edge) { edge.id() }), [
    edge_2.id(),
    edge_3.id(),
  ])
  assert_eq(follower_siblings.length(), 0)
  assert_eq(empty_bezier_siblings.length(), 0)
}

///|
test "apply_regular_parallel_reuse_layouts writes sibling layouts only when their bases exist" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)
  let shared = @emit.edge_spline_result_for_bezier(
    spline_with_start_x(12.0),
    straight_bezier_points(),
    0.0,
    false,
  )
  let regular_layout : RegularSplineLayoutResult = {
    edge_layout: build_layout_edge(edge_1, 12.0),
    spline_result: shared,
  }
  let regular_parallel_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  regular_parallel_groups[@edge_identity.edge_vnode_key(edge_1)] = [
    edge_1, edge_2, edge_3,
  ]
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  let edge_2_base = build_route_base(edge_2)
  base_cache[edge_2.id()] = edge_2_base
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  let callbacks : RoutingCallbacks = {
    recover_slack_vnodes_fn: _ => (),
    build_edge_layout_fn: layout_input => {
      build_layout_edge(layout_input.base.edge, layout_input.spline.points[0].x)
    },
    self_edge_label_height_fn: (_edge, _rankdir) => 0.0,
    self_edge_label_width_fn: (_edge, _rankdir) => 0.0,
    edge_port_label_pos_fn: _ => None,
  }
  let expected_layout = @emit.build_regular_bezier_layout(
    edge_2_base,
    shared,
    callbacks.build_edge_layout_fn,
  )

  apply_regular_parallel_reuse_layouts({
    edge: edge_1,
    regular_layout,
    regular_parallel_groups,
    base_cache,
    edges_out_by_id,
    callbacks,
  })

  assert_eq(
    edges_out_by_id
    .get(edge_2.id())
    .map(fn(layout) { layout.splines[0].points[0].x }),
    Some(expected_layout.splines[0].points[0].x),
  )
  assert_true(edges_out_by_id.get(edge_3.id()) is None)
}

///|
test "collect_flat_adjacent_beziers builds one spindle per adjacent same-rank duplicate edge" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[edge_1.id()] = build_route_base(
    edge_1,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
    tail_clip_enabled=true,
    head_clip_enabled=true,
  )
  base_cache[edge_2.id()] = build_route_base(
    edge_2,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
    tail_clip_enabled=true,
    head_clip_enabled=true,
  )

  let output = collect_flat_adjacent_beziers(
    [edge_2, edge_1],
    base_cache,
    { "a": 0, "b": 0 },
    { "a": 0, "b": 1 },
  )

  let bezier_1 = match output.get(edge_1.id()) {
    Some(value) => value
    None => fail("expected first adjacent spindle")
  }
  let bezier_2 = match output.get(edge_2.id()) {
    Some(value) => value
    None => fail("expected second adjacent spindle")
  }
  assert_eq(bezier_1.length(), 4)
  assert_eq(bezier_2.length(), 4)
  assert_point_close(bezier_1[0], @edge_spline.point(0.0, 0.0))
  assert_point_close(bezier_1[1], @edge_spline.point(10.0, -5.0))
  assert_point_close(bezier_1[2], @edge_spline.point(20.0, -5.0))
  assert_point_close(bezier_1[3], @edge_spline.point(30.0, 0.0))
  assert_point_close(bezier_2[0], @edge_spline.point(0.0, 0.0))
  assert_point_close(bezier_2[1], @edge_spline.point(10.0, 5.0))
  assert_point_close(bezier_2[2], @edge_spline.point(20.0, 5.0))
  assert_point_close(bezier_2[3], @edge_spline.point(30.0, 0.0))
}

///|
test "collect_flat_adjacent_beziers filters out labeled ported sameport and unclipped duplicate classes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let labeled_1 = graph.edge(a, b)
  let labeled_2 = graph.edge(a, b)
  labeled_1.set_attr("label", "mid")
  labeled_2.set_attr("label", "mid")
  let ported_1 = graph.edge(a, b, head_port={ name: Some("p"), compass: None })
  let ported_2 = graph.edge(a, b, head_port={ name: Some("p"), compass: None })
  let sameport_1 = graph.edge(a, b)
  let sameport_2 = graph.edge(a, b)
  sameport_1.set_attr("samehead", "g")
  sameport_2.set_attr("samehead", "g")
  let unclipped_1 = graph.edge(a, b)
  let unclipped_2 = graph.edge(a, b)
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  for edge in [labeled_1, labeled_2, ported_1, ported_2, sameport_1, sameport_2] {
    base_cache[edge.id()] = build_route_base(
      edge,
      tail_anchor=@edge_spline.point(0.0, 0.0),
      head_anchor=@edge_spline.point(30.0, 0.0),
      tail_clip_enabled=true,
      head_clip_enabled=true,
    )
  }
  base_cache[unclipped_1.id()] = build_route_base(
    unclipped_1,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
  )
  base_cache[unclipped_2.id()] = build_route_base(
    unclipped_2,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
  )

  let output = collect_flat_adjacent_beziers(
    [
      labeled_1, labeled_2, ported_1, ported_2, sameport_1, sameport_2, unclipped_1,
      unclipped_2,
    ],
    base_cache,
    { "a": 0, "b": 0 },
    { "a": 0, "b": 1 },
  )

  assert_eq(output.length(), 0)
}
