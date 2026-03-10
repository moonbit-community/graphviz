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
fn build_route_base(
  edge : @cgraph.Edge,
  is_flat_edge? : Bool = false,
  parallel_offset? : Double = 0.0,
  tail_rank? : Int = 0,
  head_rank? : Int = 1,
  tail_pos? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_pos? : @geom.Point = @edge_spline.point(30.0, 0.0),
  tail_anchor? : @geom.Point = @edge_spline.point(5.0, 0.0),
  head_anchor? : @geom.Point = @edge_spline.point(25.0, 0.0),
  tail_port? : @cgraph.Port? = None,
  head_port? : @cgraph.Port? = None,
  orig_tail_name? : String = edge.tail().name(),
  orig_head_name? : String = edge.head().name(),
  tail_clip_enabled? : Bool = false,
  head_clip_enabled? : Bool = false,
  has_vnodes? : Bool = false,
  vnodes? : Array[String] = [],
  has_side_anchor? : Bool = false,
) -> EdgeRouteBase {
  let zero = @edge_spline.point(0.0, 0.0)
  let size = @node_primitives.node_size_from_points(10.0, 10.0)
  {
    edge,
    parallel_offset,
    swap_ends: false,
    orig_tail_name,
    orig_head_name,
    tail_name: edge.tail().name(),
    head_name: edge.head().name(),
    tail_port,
    head_port,
    tail_node: edge.tail(),
    head_node: edge.head(),
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
    tail_rank,
    head_rank,
    is_flat_edge,
    is_flat_adjacent: false,
    vnodes,
    has_vnodes,
    use_pathplan: false,
    route_include_tail: false,
    route_include_head: false,
    arrow_len_override: None,
    is_dotted: false,
    same_outer_cluster: true,
    diff_local_cluster: false,
    same_local_cluster: true,
    out_tail_anchor: tail_anchor,
    out_head_anchor: head_anchor,
    out_tail_clip: tail_anchor,
    out_head_clip: head_anchor,
    out_tail_pos: tail_pos,
    out_head_pos: head_pos,
    out_tail_size: size,
    out_head_size: size,
    rankdir: @rankdir.RankDir::TB,
    layout_rankdir: @rankdir.RankDir::TB,
    has_side_anchor,
  }
}

///|
fn normalize_id_groups(groups : Array[Array[Int]]) -> Array[Array[Int]] {
  let normalized = groups.copy()
  for ids in normalized {
    ids.sort()
  }
  normalized.sort_by((a, b) => {
    let a0 = a.get(0).unwrap_or_default()
    let b0 = b.get(0).unwrap_or_default()
    cmp_int(a0, b0)
  })
  normalized
}

///|
fn spline_with_start_x(start_x : Double) -> @geom.Spline {
  {
    start: None,
    end: None,
    points: [
      @edge_spline.point(start_x, 0.0),
      @edge_spline.point(start_x + 1.0, 0.0),
      @edge_spline.point(start_x + 2.0, 0.0),
      @edge_spline.point(start_x + 3.0, 0.0),
    ],
  }
}

///|
fn build_layout_edge(
  edge : @cgraph.Edge,
  spline_start_x : Double,
  label_pos? : @geom.Point? = None,
  head_label_pos? : @geom.Point? = None,
  tail_label_pos? : @geom.Point? = None,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutEdge {
  {
    edge,
    splines: [spline_with_start_x(spline_start_x)],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
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
fn sample_regular_pass_input(
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  vnode_sizes : Map[String, @node_primitives.NodeSize],
  rank_y : Map[Int, Double],
) -> RegularPassInput {
  {
    spline_mode: 0,
    ranks,
    sizes: Map::new(),
    positions: Map::new(),
    vnode_positions,
    vnode_info: {
      vnode_ranks,
      vnode_sizes,
      vnodes_by_rank: Map::new(),
      edge_vnodes: Map::new(),
      vnode_clusters: Map::new(),
    },
    rank_y,
    rank_ht1: Map::new(),
    rank_ht2: Map::new(),
    x_groups: Map::new(),
    nodesep_pt: 0.0,
    ranksep_pt: 0.0,
    label_edge_counts: Map::new(),
    head_port_metrics: {
      head_port_counts: Map::new(),
      head_port_min_dist: Map::new(),
      head_port_max_dist: Map::new(),
    },
    routing_context: {
      order_index: Map::new(),
      path_order_index: Map::new(),
      path_adjacency: @routesplines.build_path_adjacency([], Map::new(), [], []),
      pathplan_sizes: Map::new(),
      pathplan_vnode_mval_sizes: Map::new(),
      path_cluster_keys: Map::new(),
      path_vnode_clusters: Map::new(),
      parallel_offsets: Map::new(),
      cluster_bboxes: Map::new(),
    },
    enable_complex_tuning: false,
  }
}

///|
test "edge route type classifies regular flat and self edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let regular_edge = graph.edge(graph.node("a"), graph.node("b"))
  let self_edge = graph.edge(graph.node("n"), graph.node("n"))
  let explicit_port = Some(@cgraph.Port::{ name: Some("p"), compass: None })

  let regular = build_route_base(regular_edge)
  let flat = build_route_base(regular_edge, is_flat_edge=true)
  let self_noport = build_route_base(
    self_edge,
    orig_tail_name="n",
    orig_head_name="n",
  )
  let self_port = build_route_base(
    self_edge,
    tail_port=explicit_port,
    orig_tail_name="n",
    orig_head_name="n",
  )

  assert_eq(edge_route_type(regular), ROUTE_EDGE_REGULAR)
  assert_eq(edge_route_type(flat), ROUTE_EDGE_FLAT)
  assert_eq(edge_route_type(self_noport), ROUTE_EDGE_SELF_NOPORT)
  assert_eq(edge_route_type(self_port), ROUTE_EDGE_SELF_PORT)
  assert_eq(edge_route_graph_type(ROUTE_EDGE_REGULAR), ROUTE_GRAPH_MAIN)
  assert_eq(edge_route_graph_type(ROUTE_EDGE_FLAT), ROUTE_GRAPH_AUX)
}

///|
test "edge_port_cmp_info flips flat edge ports when node order is reversed" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let explicit_tail = Some(@cgraph.Port::{ name: Some("tail"), compass: None })
  let explicit_head = Some(@cgraph.Port::{ name: Some("head"), compass: None })
  let order_index : Map[String, Int] = { "a": 2, "b": 0 }
  let base = build_route_base(
    edge,
    is_flat_edge=true,
    tail_pos=@edge_spline.point(0.0, 0.0),
    head_pos=@edge_spline.point(10.0, 0.0),
    tail_anchor=@edge_spline.point(1.0, 2.0),
    head_anchor=@edge_spline.point(13.0, 4.0),
    tail_port=explicit_tail,
    head_port=explicit_head,
  )

  let info = edge_port_cmp_info(base, ROUTE_EDGE_FLAT, order_index)

  assert_true(info.tail_defined)
  assert_true(info.head_defined)
  assert_point_close(info.tail_pos, @edge_spline.point(3.0, 4.0))
  assert_point_close(info.head_pos, @edge_spline.point(1.0, 2.0))
}

///|
test "sorted_edges_for_routing prioritizes self edges then flat edges then regular edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let regular_edge = graph.edge(graph.node("a"), graph.node("b"))
  let flat_edge = graph.edge(graph.node("c"), graph.node("d"))
  let self_edge = graph.edge(graph.node("s"), graph.node("s"))
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[regular_edge.id()] = build_route_base(
    regular_edge,
    tail_rank=0,
    head_rank=3,
  )
  base_cache[flat_edge.id()] = build_route_base(
    flat_edge,
    is_flat_edge=true,
    tail_rank=0,
    head_rank=0,
  )
  base_cache[self_edge.id()] = build_route_base(
    self_edge,
    orig_tail_name="s",
    orig_head_name="s",
  )

  let ordered = sorted_edges_for_routing(
    [regular_edge, self_edge, flat_edge],
    base_cache,
    Map::new(),
  )

  assert_eq(ordered.map(fn(edge) { edge.id() }), [
    self_edge.id(),
    flat_edge.id(),
    regular_edge.id(),
  ])
}

///|
test "recover_slack_key_for_edge uses parallel keys only for unlabeled undirected edges" {
  let undir = @cgraph.Graph::new(@cgraph.GraphKind::Undirected, strict=false)
  let undir_edge = undir.edge(undir.node("a"), undir.node("b"))

  let directed = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let labeled_edge = directed.edge(directed.node("a"), directed.node("b"))
  labeled_edge.set_attr("label", "mid")

  let expected_parallel_key = "parallel|" +
    @edge_ops.edge_parallel_key("a", "b", None, None)
  let expected_vnode_key = "vnode|" +
    @edge_identity.edge_vnode_key(labeled_edge)

  assert_eq(recover_slack_key_for_edge(undir_edge), expected_parallel_key)
  assert_eq(recover_slack_key_for_edge(labeled_edge), expected_vnode_key)
}

///|
test "recover plan picks center-most edge but routing plan pins multi-edge groups to first ordered edge" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_a = graph.edge(a, b)
  let edge_b = graph.edge(a, b)
  let edge_c = graph.edge(a, b)
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[edge_a.id()] = build_route_base(edge_a, parallel_offset=2.0)
  base_cache[edge_b.id()] = build_route_base(edge_b, parallel_offset=-1.0)
  base_cache[edge_c.id()] = build_route_base(edge_c, parallel_offset=1.0)

  let selected = recover_regular_selection([edge_a, edge_b, edge_c], base_cache)
  let recover_key = recover_slack_key_for_edge(edge_a)
  let group_key = @edge_identity.edge_vnode_key(edge_a)
  assert_eq(selected.get(recover_key), Some(edge_c.id()))

  let plan = build_regular_recover_routing_plan(
    [edge_a, edge_b, edge_c],
    base_cache,
  )
  assert_eq(
    plan.regular_parallel_groups
    .get(group_key)
    .map(fn(edges) { edges.map(fn(edge) { edge.id() }) }),
    Some([edge_a.id(), edge_b.id(), edge_c.id()]),
  )
  assert_eq(
    plan.recover_edge_id_for_routing.get(recover_key),
    Some(edge_a.id()),
  )
}

///|
test "vnode_is_merged stays false for duplicate parallel neighbors but true for distinct neighbors" {
  let duplicate_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let duplicate_a = duplicate_graph.node("a")
  let duplicate_b = duplicate_graph.node("b")
  let duplicate_1 = duplicate_graph.edge(duplicate_a, duplicate_b)
  let duplicate_2 = duplicate_graph.edge(duplicate_a, duplicate_b)
  let duplicate_vnodes : Map[String, Array[String]] = Map::new()
  duplicate_vnodes[@edge_identity.edge_vnode_key(duplicate_1)] = ["v"]
  duplicate_vnodes[@edge_identity.edge_vnode_key(duplicate_2)] = ["v"]
  let duplicate_adjacency = @routesplines.build_path_adjacency(
    [duplicate_1, duplicate_2],
    duplicate_vnodes,
    [],
    [],
  )

  let merged_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let merged_a = merged_graph.node("a")
  let merged_b = merged_graph.node("b")
  let merged_c = merged_graph.node("c")
  let merged_d = merged_graph.node("d")
  let merged_1 = merged_graph.edge(merged_a, merged_b)
  let merged_2 = merged_graph.edge(merged_c, merged_d)
  let merged_vnodes : Map[String, Array[String]] = Map::new()
  merged_vnodes[@edge_identity.edge_vnode_key(merged_1)] = ["v"]
  merged_vnodes[@edge_identity.edge_vnode_key(merged_2)] = ["v"]
  let merged_adjacency = @routesplines.build_path_adjacency(
    [merged_1, merged_2],
    merged_vnodes,
    [],
    [],
  )

  assert_false(vnode_is_merged("v", duplicate_adjacency))
  assert_true(vnode_is_merged("v", merged_adjacency))
}

///|
test "recover_slack_vnodes centers normal vnodes and right-aligns the label rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = {
    "v1": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
    "v2": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
  }
  let vnode_positions : Map[String, @geom.Point] = Map::new()
  let empty_edge_vnodes : Map[String, Array[String]] = Map::new()
  let adjacency = @routesplines.build_path_adjacency(
    [],
    empty_edge_vnodes,
    [],
    [],
  )

  recover_slack_vnodes(
    {
      edge,
      ordered_vnodes: ["v1", "v2"],
      boxes: [
        { llx: 0.0, lly: 4.0, urx: 10.0, ury: 6.0 },
        { llx: 2.0, lly: 0.0, urx: 8.0, ury: 2.0 },
      ],
      ranks: { "a": 0, "b": 3 },
      vnode_ranks: { "v1": 1, "v2": 2 },
      rank_y: { 1: 5.0, 2: 1.0 },
      vnode_positions,
      vnode_sizes,
      adjacency,
    },
    (_edge, _ranks) => Some(2),
  )

  assert_eq(vnode_positions.get("v1"), Some(@edge_spline.point(5.0, 5.0)))
  assert_eq(vnode_positions.get("v2"), Some(@edge_spline.point(8.0, 1.0)))
  assert_eq(vnode_sizes.get("v1").map(fn(size) { size.left_pt }), Some(5.0))
  assert_eq(vnode_sizes.get("v1").map(fn(size) { size.right_pt }), Some(5.0))
  assert_eq(vnode_sizes.get("v2").map(fn(size) { size.left_pt }), Some(6.0))
  assert_eq(vnode_sizes.get("v2").map(fn(size) { size.right_pt }), Some(1.0))
}

///|
test "collect_parallel_remap_edge_ids keeps plain and sameport duplicate groups separate" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let plain_1 = graph.edge(a, b)
  let plain_2 = graph.edge(a, b)
  let sameport_1 = graph.edge(a, b)
  let sameport_2 = graph.edge(a, b)
  let labeled = graph.edge(a, b)
  let same_rank = graph.edge(a, c)
  let self_edge = graph.edge(c, c)
  sameport_1.set_attr("samehead", "g")
  sameport_2.set_attr("samehead", "g")
  labeled.set_attr("label", "mid")

  let ranks : Map[String, Int] = { "a": 0, "b": 2, "c": 0 }
  let groups = normalize_id_groups(
    collect_parallel_remap_edge_ids(
      [plain_1, plain_2, sameport_1, sameport_2, labeled, same_rank, self_edge],
      ranks,
    ),
  )

  assert_eq(groups, [
    [plain_1.id(), plain_2.id()],
    [sameport_1.id(), sameport_2.id()],
  ])
}

///|
test "collect_parallel_remap_edge_ids drops duplicate classes once directions are mixed" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward_1 = graph.edge(a, b)
  let forward_2 = graph.edge(a, b)
  let reverse = graph.edge(b, a)

  let ranks : Map[String, Int] = { "a": 0, "b": 2 }
  let groups = collect_parallel_remap_edge_ids(
    [forward_1, forward_2, reverse],
    ranks,
  )

  assert_eq(groups, [])
}

///|
test "build_parallel_remap_assignments requires complete groups and reverses source slots" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)

  let ranks : Map[String, Int] = { "a": 0, "b": 2 }
  let incomplete = collect_complete_parallel_remap_groups({
    edges: [edge_1, edge_2, edge_3],
    ranks,
    has_layout: edge_id => edge_id != edge_2.id(),
  })
  assert_eq(incomplete, [])

  let assignments = build_parallel_remap_assignments({
    edges: [edge_1, edge_2, edge_3],
    ranks,
    has_layout: _ => true,
  })

  assert_eq(
    assignments.map(fn(assignment) {
      "\{assignment.target_edge_id}->\{assignment.source_edge_id}"
    }),
    [
      "\{edge_1.id()}->\{edge_3.id()}",
      "\{edge_2.id()}->\{edge_2.id()}",
      "\{edge_3.id()}->\{edge_1.id()}",
    ],
  )
}

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
test "remap_port_label_pos respects attr gating fallback and head-tail spline selection" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let splines = [spline_with_start_x(1.0), spline_with_start_x(9.0)]
  let fallback = Some(@edge_spline.point(77.0, 0.0))

  assert_eq(
    remap_port_label_pos({
      edge,
      splines,
      label_attr: "headlabel",
      is_head: true,
      fallback,
      edge_port_label_pos_fn: _ => Some(@edge_spline.point(0.0, 0.0)),
    }),
    None,
  )

  edge.set_attr("headlabel", "h")
  assert_eq(
    remap_port_label_pos({
      edge,
      splines: [],
      label_attr: "headlabel",
      is_head: true,
      fallback,
      edge_port_label_pos_fn: _ => Some(@edge_spline.point(0.0, 0.0)),
    }),
    fallback,
  )

  let tail = remap_port_label_pos({
    edge,
    splines,
    label_attr: "headlabel",
    is_head: false,
    fallback,
    edge_port_label_pos_fn: input => Some(input.spline.points[0]),
  })
  let head = remap_port_label_pos({
    edge,
    splines,
    label_attr: "headlabel",
    is_head: true,
    fallback,
    edge_port_label_pos_fn: input => Some(input.spline.points[0]),
  })

  assert_eq(tail, Some(@edge_spline.point(1.0, 0.0)))
  assert_eq(head, Some(@edge_spline.point(9.0, 0.0)))
}

///|
test "remap_edge_layout_edge keeps only attrs present on the target edge and falls back per endpoint label" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let source_edge = graph.edge(graph.node("a"), graph.node("b"))
  let target_edge = graph.edge(graph.node("a"), graph.node("b"), name="target")
  target_edge.set_attr("headlabel", "head")
  target_edge.set_attr("taillabel", "tail")
  target_edge.set_attr("xlabel", "x")

  let layout = build_layout_edge(
    source_edge,
    12.0,
    label_pos=Some(@edge_spline.point(1.0, 1.0)),
    head_label_pos=Some(@edge_spline.point(2.0, 2.0)),
    tail_label_pos=Some(@edge_spline.point(3.0, 3.0)),
    xlabel_pos=Some(@edge_spline.point(4.0, 4.0)),
  )

  let remapped = remap_edge_layout_edge(target_edge, layout, input => {
    if input.is_head {
      Some(@edge_spline.point(100.0, input.spline.points[0].x))
    } else {
      None
    }
  })

  assert_eq(remapped.edge.id(), target_edge.id())
  assert_eq(remapped.splines, layout.splines)
  assert_eq(remapped.label_pos, None)
  assert_eq(remapped.head_label_pos, Some(@edge_spline.point(100.0, 12.0)))
  assert_eq(remapped.tail_label_pos, layout.tail_label_pos)
  assert_eq(remapped.xlabel_pos, layout.xlabel_pos)
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
test "remap_parallel_edge_layouts uses a snapshot so reversed remaps do not cascade" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)
  let ranks : Map[String, Int] = { "a": 0, "b": 2 }
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  edges_out_by_id[edge_1.id()] = build_layout_edge(edge_1, 1.0)
  edges_out_by_id[edge_2.id()] = build_layout_edge(edge_2, 20.0)
  edges_out_by_id[edge_3.id()] = build_layout_edge(edge_3, 40.0)

  remap_parallel_edge_layouts({
    edges: [edge_1, edge_2, edge_3],
    ranks,
    edges_out_by_id,
    edge_port_label_pos_fn: _ => None,
  })

  assert_eq(
    edges_out_by_id
    .get(edge_1.id())
    .map(fn(layout) { layout.splines[0].points[0] }),
    Some(@edge_spline.point(40.0, 0.0)),
  )
  assert_eq(
    edges_out_by_id
    .get(edge_2.id())
    .map(fn(layout) { layout.splines[0].points[0] }),
    Some(@edge_spline.point(20.0, 0.0)),
  )
  assert_eq(
    edges_out_by_id
    .get(edge_3.id())
    .map(fn(layout) { layout.splines[0].points[0] }),
    Some(@edge_spline.point(1.0, 0.0)),
  )
}

///|
test "finalize_routed_edges preserves input order for layouts that remain after remap" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, c)
  let edge_3 = graph.edge(b, c)
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  edges_out_by_id[edge_1.id()] = build_layout_edge(edge_1, 10.0)
  edges_out_by_id[edge_3.id()] = build_layout_edge(edge_3, 30.0)

  let output = finalize_routed_edges({
    edges: [edge_2, edge_1, edge_3],
    ranks: { "a": 0, "b": 1, "c": 2 },
    edges_out_by_id,
    edge_port_label_pos_fn: _ => None,
  })

  assert_eq(output.map(fn(layout) { layout.edge.id() }), [
    edge_1.id(),
    edge_3.id(),
  ])
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
