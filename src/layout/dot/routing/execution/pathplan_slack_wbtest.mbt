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
