///|
fn require_simplex_test_size(
  sizes : Map[String, @node_primitives.NodeSize],
  name : String,
) -> @node_primitives.NodeSize raise {
  match sizes.get(name) {
    Some(value) => value
    None => fail("missing size for \{name}")
  }
}

///|
fn build_simplex_test_input(
  use_vnodes_for_xpos : Bool,
) -> XPositionPipelineInput {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  let x_base_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  x_base_sizes["a"] = @node_primitives.node_size_from_points(10.0, 10.0)
  x_base_sizes["b"] = @node_primitives.node_size_from_points(12.0, 8.0)
  let vnode_name = "\{@edge_identity.EDGE_VNODE_PREFIX}0_1"
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes[vnode_name] = @node_primitives.vnode_size_from_widths_with_h(
    4.0, 6.0, 2.0,
  )
  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks[vnode_name] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes["edge0"] = [vnode_name]
  {
    use_vnodes_for_xpos,
    x_base_sizes,
    x_groups,
    vnode_sizes,
    vnode_creation_order: [vnode_name],
    vnode_ranks,
    edge_vnodes,
    graph,
    nodes: [a, b],
    edges: [],
    edge_tail: [],
    edge_head: [],
    edge_out_order: Map::new(),
    nlist_order: ["a", "b", vnode_name],
    gdnlist_order: ["a", "b", vnode_name],
    cluster_keys: Map::new(),
    nodesep_pt: 12.0,
    has_edge_labels: false,
    output_sizes: x_base_sizes,
    flat_label_edges: [],
  }
}

///|
test "constraint graph reorder puts slack nodes first and preserves rank mapping" {
  let graph = @network_simplex.new_graph()
  let index : Map[String, Int] = Map::new()
  index["a"] = @network_simplex.add_node(graph, "a")
  index["ln"] = @network_simplex.add_node(
    graph,
    "ln",
    kind=@network_simplex.NodeKind::Slack,
  )
  index["b"] = @network_simplex.add_node(graph, "b")
  index["rn"] = @network_simplex.add_node(
    graph,
    "rn",
    kind=@network_simplex.NodeKind::Slack,
  )
  @network_simplex.set_node_rank(graph, index["a"], 10)
  @network_simplex.set_node_rank(graph, index["ln"], -1)
  @network_simplex.set_node_rank(graph, index["b"], 20)
  @network_simplex.set_node_rank(graph, index["rn"], -2)
  ignore(@network_simplex.add_edge(graph, index["a"], index["b"], 3, 5))

  let order = build_constraint_reorder({ graph, index, nlist_order: ["a", "b"] })
  assert_eq(order, [3, 1, 2, 0])

  let reordered = reorder_constraint_graph({ graph, index, order })
  assert_eq(reordered.index.get("rn"), Some(0))
  assert_eq(reordered.index.get("ln"), Some(1))
  assert_eq(reordered.index.get("b"), Some(2))
  assert_eq(reordered.index.get("a"), Some(3))
  assert_true(reordered.graph.nodes[0].kind == @network_simplex.NodeKind::Slack)
  assert_eq(reordered.graph.nodes[0].rank, -2)
  assert_true(reordered.graph.nodes[1].kind == @network_simplex.NodeKind::Slack)
  assert_eq(reordered.graph.nodes[1].rank, -1)
  assert_true(
    reordered.graph.nodes[2].kind == @network_simplex.NodeKind::Normal,
  )
  assert_eq(reordered.graph.nodes[2].rank, 20)
  assert_true(
    reordered.graph.nodes[3].kind == @network_simplex.NodeKind::Normal,
  )
  assert_eq(reordered.graph.nodes[3].rank, 10)
  assert_eq(reordered.graph.edges.length(), 1)
  assert_eq(reordered.graph.edges[0].tail, 3)
  assert_eq(reordered.graph.edges[0].head, 2)
}

///|
test "build_x_position_solve_input toggles vnode overlays and extra nodes" {
  let with_vnodes = build_x_position_solve_input(build_simplex_test_input(true))
  let without_vnodes = build_x_position_solve_input(
    build_simplex_test_input(false),
  )
  let vnode_name = "\{@edge_identity.EDGE_VNODE_PREFIX}0_1"

  assert_eq(with_vnodes.rank_keys, [0])
  assert_eq(with_vnodes.ranks.get("a"), Some(0))
  assert_eq(with_vnodes.ranks.get("b"), Some(0))
  assert_eq(with_vnodes.extra_nodes.length(), 1)
  assert_eq(with_vnodes.extra_nodes[0].name, vnode_name)
  assert_eq(with_vnodes.extra_nodes[0].rank, 1)
  let vnode_size = require_simplex_test_size(with_vnodes.sizes, vnode_name)
  assert_eq(vnode_size.left_pt, 4.0)
  assert_eq(vnode_size.right_pt, 6.0)
  assert_eq(vnode_size.height_pt, 2.0)
  assert_eq(with_vnodes.edge_vnodes.get("edge0"), Some([vnode_name]))

  assert_eq(without_vnodes.extra_nodes.length(), 0)
  assert_true(without_vnodes.sizes.get(vnode_name) is None)
  assert_eq(without_vnodes.edge_vnodes.length(), 0)
}

///|
test "should_capture_xpos_snapshot follows env value and graph name matching" {
  let env_key = "DOT_CAPTURE_XPOS_CONSTRAINTS"
  let original = @sys.get_env_var(env_key)
  let named = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    name="capture-me",
    strict=false,
  )
  let anonymous = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)

  @sys.unset_env_var(env_key)
  let absent_named = should_capture_xpos_snapshot(named)
  let absent_anonymous = should_capture_xpos_snapshot(anonymous)

  @sys.set_env_var(env_key, "")
  let empty_named = should_capture_xpos_snapshot(named)

  @sys.set_env_var(env_key, "1")
  let one_named = should_capture_xpos_snapshot(named)
  let one_anonymous = should_capture_xpos_snapshot(anonymous)

  @sys.set_env_var(env_key, "capture-me")
  let exact_named = should_capture_xpos_snapshot(named)
  let exact_anonymous = should_capture_xpos_snapshot(anonymous)

  @sys.set_env_var(env_key, "other-graph")
  let mismatch_named = should_capture_xpos_snapshot(named)

  match original {
    Some(value) => @sys.set_env_var(env_key, value)
    None => @sys.unset_env_var(env_key)
  }

  assert_false(absent_named)
  assert_false(absent_anonymous)
  assert_true(empty_named)
  assert_true(one_named)
  assert_true(one_anonymous)
  assert_true(exact_named)
  assert_false(exact_anonymous)
  assert_false(mismatch_named)
}

///|
test "compute_x_positions_with_prepared_constraints solves minimal input and captures reordered snapshot" {
  let solve_input = build_x_position_solve_input(
    build_simplex_test_input(false),
  )

  xpos_constraint_snapshot.val = None
  let without_snapshot = compute_x_positions_with_prepared_constraints(
    solve_input,
    0.0,
    1000,
    (segment, _) => segment_slack_minlen(segment, (_, _) => 0.0),
    _ => false,
    _ => 1,
    false,
  )
  let uncaptured_snapshot = xpos_constraint_snapshot.val

  xpos_constraint_snapshot.val = None
  let with_snapshot = compute_x_positions_with_prepared_constraints(
    solve_input,
    0.0,
    1000,
    (segment, _) => segment_slack_minlen(segment, (_, _) => 0.0),
    _ => false,
    _ => 1,
    true,
  )
  let captured_snapshot = match xpos_constraint_snapshot.val {
    Some(value) => value
    None => fail("expected xpos constraint snapshot")
  }
  xpos_constraint_snapshot.val = None

  assert_eq(without_snapshot.get("a"), Some(0.0))
  assert_eq(without_snapshot.get("b"), Some(23.0))
  assert_eq(with_snapshot.get("a"), Some(0.0))
  assert_eq(with_snapshot.get("b"), Some(23.0))
  assert_true(uncaptured_snapshot is None)

  assert_eq(captured_snapshot.nodes.length(), 2)
  assert_eq(captured_snapshot.nodes[0].name, Some("b"))
  assert_eq(captured_snapshot.nodes[0].rank, 23)
  assert_eq(captured_snapshot.nodes[0].order, 1)
  assert_eq(captured_snapshot.nodes[0].left_pt, 6.0)
  assert_eq(captured_snapshot.nodes[0].right_pt, 6.0)
  assert_eq(captured_snapshot.nodes[0].height_pt, 8.0)
  assert_eq(captured_snapshot.nodes[1].name, Some("a"))
  assert_eq(captured_snapshot.nodes[1].rank, 0)
  assert_eq(captured_snapshot.nodes[1].order, 0)
  assert_eq(captured_snapshot.nodes[1].left_pt, 5.0)
  assert_eq(captured_snapshot.nodes[1].right_pt, 5.0)
  assert_eq(captured_snapshot.nodes[1].height_pt, 10.0)

  assert_eq(captured_snapshot.edges.length(), 1)
  assert_eq(captured_snapshot.edges[0].tail, 1)
  assert_eq(captured_snapshot.edges[0].head, 0)
  assert_eq(captured_snapshot.edges[0].minlen, 23)
  assert_eq(captured_snapshot.edges[0].weight, 0)
}

///|
test "build_xpos_nlist_order visits clustered ranks in reverse with vnodes first" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"
  cluster_keys["v"] = "cluster0"

  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[1] = ["v", "x"]

  let order = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::TB,
    nlist_order: ["unused"],
    gdnlist_order: ["a", "b", "v", "x"],
    cluster_keys,
    rank_keys: [0, 1],
    groups,
  })

  assert_eq(order, ["v", "b", "a", "x"])
}

///|
test "build_xpos_nlist_order keeps source order for LR and uncluttered fallback" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster0"
  cluster_keys["b"] = "cluster0"
  cluster_keys["v"] = "cluster0"

  let grouped : Map[Int, Array[String]] = Map::new()
  grouped[0] = ["a", "b"]
  grouped[1] = ["v", "x"]

  let lr_order = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::LR,
    nlist_order: ["unused"],
    gdnlist_order: ["a", "b", "v", "x"],
    cluster_keys,
    rank_keys: [0, 1],
    groups: grouped,
  })

  let no_cluster_groups : Map[Int, Array[String]] = Map::new()
  no_cluster_groups[0] = ["m", "n"]
  let source_fallback = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::TB,
    nlist_order: ["m", "n"],
    gdnlist_order: [],
    cluster_keys: Map::new(),
    rank_keys: [0],
    groups: no_cluster_groups,
  })

  assert_eq(lr_order, ["a", "b", "v", "x"])
  assert_eq(source_fallback, ["m", "n"])
}

///|
test "build_xpos_nlist_order processes multiple clusters from reversed source discovery before unclustered leftovers" {
  let vnode_a = "\{@edge_identity.EDGE_VNODE_PREFIX}a"
  let vnode_b = "\{@edge_identity.EDGE_VNODE_PREFIX}b"
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a1"] = "clusterA"
  cluster_keys[vnode_a] = "clusterA"
  cluster_keys["b1"] = "clusterB"
  cluster_keys[vnode_b] = "clusterB"

  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a1", "b1", "u"]
  groups[1] = [vnode_a, vnode_b]

  let order = build_xpos_nlist_order({
    rankdir: @rankdir.RankDir::TB,
    nlist_order: ["unused"],
    gdnlist_order: ["a1", "u", vnode_a, "b1", vnode_b],
    cluster_keys,
    rank_keys: [0, 1],
    groups,
  })

  assert_eq(order, [vnode_b, "b1", vnode_a, "a1", "u"])
}

///|
test "build_vnode_extra_nodes preserves explicit vnode order before fallback entries" {
  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v1"] = 1
  vnode_ranks["v2"] = 2
  vnode_ranks["v3"] = 3

  let extra = build_vnode_extra_nodes(["v2", "missing", "v1"], vnode_ranks)

  assert_eq(extra.length(), 3)
  assert_eq(extra[0].name, "v2")
  assert_eq(extra[0].rank, 2)
  assert_eq(extra[1].name, "v1")
  assert_eq(extra[1].rank, 1)
  assert_eq(extra[2].name, "v3")
  assert_eq(extra[2].rank, 3)
}
