///|
fn require_size(
  sizes : Map[String, @node_primitives.NodeSize],
  name : String,
) -> @node_primitives.NodeSize raise {
  match sizes.get(name) {
    Some(value) => value
    None => fail("missing size for \{name}")
  }
}

///|
fn require_index(index : Map[String, Int], name : String) -> Int raise {
  match index.get(name) {
    Some(value) => value
    None => fail("missing index for \{name}")
  }
}

///|
fn make_port(name : String, compass : @cgraph.Compass) -> @cgraph.Port {
  { name: Some(name), compass: Some(compass) }
}

///|
fn build_base_sizes() -> Map[String, @node_primitives.NodeSize] {
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths_with_h(3.0, 4.0, 10.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths_with_h(6.0, 7.0, 12.0)
  sizes["c"] = @node_primitives.vnode_size_from_widths_with_h(5.0, 8.0, 8.0)
  sizes["d"] = @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 9.0)
  sizes["e"] = @node_primitives.vnode_size_from_widths_with_h(4.0, 5.0, 11.0)
  sizes
}

///|
fn build_x_pipeline_input(use_vnodes_for_xpos : Bool) -> XPositionPipelineInput {
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
test "compress_width_minlen_pt respects ratio rankdir swap and clamp" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("size", "2,3!")

  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::TB), None)

  graph.set_attr("ratio", " compress ")
  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::TB), Some(144))
  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::LR), Some(216))

  graph.set_attr("size", "1000000,1000000")
  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::TB), Some(65535))
}

///|
test "compute_rank_positions applies edge-label spacing only on odd ranks" {
  let sizes = build_base_sizes()
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["d", "e"]
  groups[1] = ["a", "b", "c"]

  let positions = compute_rank_positions([0, 1], groups, sizes, 12.0, true)

  assert_eq(positions.get("d"), Some(0.0))
  assert_eq(positions.get("e"), Some(19.0))
  assert_eq(positions.get("a"), Some(0.0))
  assert_eq(positions.get("b"), Some(15.0))
  assert_eq(positions.get("c"), Some(32.0))
}

///|
test "segment_slack_minlen splits positive and negative port deltas" {
  let tail_port = Some(make_port("tail", @cgraph.Compass::E))
  let head_port = Some(make_port("head", @cgraph.Compass::W))
  let offset_by_key : Map[String, Double] = Map::new()
  offset_by_key["a|tail:e"] = 3.0
  offset_by_key["b|head:w"] = 9.0
  offset_by_key["c|tail:e"] = 11.0
  offset_by_key["d|head:w"] = 7.0
  let edge_port_offset = (name : String, port : @cgraph.Port?) => {
    let key = "\{name}|\{@edge_identity.port_key(port)}"
    offset_by_key.get(key).unwrap_or_default()
  }

  let positive = segment_slack_minlen(
    { tail: "a", head: "b", weight: 1, tail_port, head_port },
    edge_port_offset,
  )
  let negative = segment_slack_minlen(
    { tail: "c", head: "d", weight: 1, tail_port, head_port },
    edge_port_offset,
  )

  assert_eq(positive, (6, 0))
  assert_eq(negative, (0, 4))
}

///|
test "build_constraint_segment_pass updates same-rank invis ordering constraints and skips intercluster edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let inside = graph.edge(b, a)
  inside.set_attr("style", "invis")
  inside.set_attr("minlen", "2")
  inside.set_attr("weight", "7")
  let cross = graph.edge(a, c, name="cross")
  cross.set_attr("minlen", "5")
  cross.set_attr("weight", "11")

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["b"] = [0]
  edge_out_order["a"] = [1]

  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 0 }
  let cluster_keys : Map[String, String] = {
    "a": "cluster0",
    "b": "cluster0",
    "c": "cluster1",
  }
  let order_in_rank : Map[String, Int] = { "a": 0, "b": 1, "c": 2 }
  let rank_adj_constraints : Map[String, ConstraintEdge] = {
    "a|b": {
      tail: "a",
      head: "b",
      minlen: 12,
      weight: 3,
      tail_port: None,
      head_port: None,
    },
  }

  let output = build_constraint_segment_pass({
    edges: [inside, cross],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["b", "a", "c"],
    ranks,
    cluster_keys,
    edge_vnodes: Map::new(),
    order_in_rank,
    nodesep_pt: 10.0,
    sizes: build_base_sizes(),
    skip_intercluster: true,
    rank_adj_constraints,
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
  })

  let merged = match rank_adj_constraints.get("a|b") {
    Some(value) => value
    None => fail("missing merged same-rank constraint")
  }

  assert_eq(merged.tail, "a")
  assert_eq(merged.head, "b")
  assert_eq(merged.minlen, 40)
  assert_eq(merged.weight, 7)
  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 0)
}

///|
test "build_constraint_segment_pass adds synthetic ordering ports on same-rank labeled vnode chains" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ordering", "out")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("label", "mid")
  edge.set_attr("weight", "3")
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}flat_0"

  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [0]
  let ranks : Map[String, Int] = { "a": 0, "b": 0 }
  ranks[vnode] = 0
  let order_in_rank : Map[String, Int] = { "a": 0, "b": 2 }
  order_in_rank[vnode] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [vnode]

  let output = build_constraint_segment_pass({
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["a", vnode, "b"],
    ranks,
    cluster_keys: Map::new(),
    edge_vnodes,
    order_in_rank,
    nodesep_pt: 10.0,
    sizes: build_base_sizes(),
    skip_intercluster: false,
    rank_adj_constraints: Map::new(),
    edge_has_mid_label: _ => true,
    edge_degree_increment: _ => 1,
  })

  let head_segments = match output.segments_by_tail.get("a") {
    Some(value) => value
    None => fail("missing first vnode segment")
  }
  let tail_segments = match output.segments_by_tail.get(vnode) {
    Some(value) => value
    None => fail("missing second vnode segment")
  }

  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 2)

  assert_eq(head_segments.length(), 1)
  assert_eq(head_segments[0].tail, "a")
  assert_eq(head_segments[0].head, vnode)
  assert_eq(head_segments[0].weight, 6)
  assert_eq(@edge_identity.port_key(head_segments[0].tail_port), "e")
  assert_eq(@edge_identity.port_key(head_segments[0].head_port), "w")

  assert_eq(tail_segments.length(), 1)
  assert_eq(tail_segments[0].tail, vnode)
  assert_eq(tail_segments[0].head, "b")
  assert_eq(tail_segments[0].weight, 6)
  assert_eq(@edge_identity.port_key(tail_segments[0].tail_port), "")
  assert_eq(@edge_identity.port_key(tail_segments[0].head_port), "")
}

///|
test "build_constraint_segment_pass reverses descending vnode chains and scales sparse segment weights" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("weight", "3")

  let vnode0 = "\{@edge_identity.EDGE_VNODE_PREFIX}desc_0"
  let vnode1 = "\{@edge_identity.EDGE_VNODE_PREFIX}desc_1"
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  edge_out_order["a"] = [0]
  let ranks : Map[String, Int] = { "a": 2, "b": 0 }
  ranks[vnode0] = 1
  ranks[vnode1] = 1
  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [vnode0, vnode1]

  let output = build_constraint_segment_pass({
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    edge_out_order,
    nlist_order: ["a", vnode0, vnode1, "b"],
    ranks,
    cluster_keys: Map::new(),
    edge_vnodes,
    order_in_rank: Map::new(),
    nodesep_pt: 10.0,
    sizes: build_base_sizes(),
    skip_intercluster: false,
    rank_adj_constraints: Map::new(),
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
  })

  let first_segments = match output.segments_by_tail.get("a") {
    Some(value) => value
    None => fail("missing first descending segment")
  }
  let middle_segments = match output.segments_by_tail.get(vnode1) {
    Some(value) => value
    None => fail("missing middle descending segment")
  }
  let last_segments = match output.segments_by_tail.get(vnode0) {
    Some(value) => value
    None => fail("missing last descending segment")
  }

  assert_eq(output.flat_minlen_constraints.length(), 0)
  assert_eq(output.segments_by_tail.length(), 3)

  assert_eq(first_segments.length(), 1)
  assert_eq(first_segments[0].tail, "a")
  assert_eq(first_segments[0].head, vnode1)
  assert_eq(first_segments[0].weight, 6)

  assert_eq(middle_segments.length(), 1)
  assert_eq(middle_segments[0].tail, vnode1)
  assert_eq(middle_segments[0].head, vnode0)
  assert_eq(middle_segments[0].weight, 12)

  assert_eq(last_segments.length(), 1)
  assert_eq(last_segments[0].tail, vnode0)
  assert_eq(last_segments[0].head, "b")
  assert_eq(last_segments[0].weight, 6)
}

///|
test "constraint node setup delays cluster boundaries and seeds base positions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let boundary = @cluster_identity.cluster_left_boundary_name("cluster0")
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0_0"
  let base_positions : Map[String, Double] = Map::new()
  base_positions["a"] = 10.0
  base_positions[vnode] = 30.0
  let constraint_graph = @network_simplex.new_graph()

  let setup = build_constraint_nodes_setup({
    graph: constraint_graph,
    nodes: [a, b],
    extra_nodes: [{ name: boundary, rank: 9 }, { name: vnode, rank: 7 }],
    nlist_order: [vnode, "a", boundary],
    base_positions,
  })

  assert_eq(setup.index.get(boundary), None)
  assert_eq(setup.late_extra_nodes.length(), 1)
  assert_eq(setup.late_extra_nodes[0].name, boundary)

  let vnode_idx = require_index(setup.index, vnode)
  let a_idx = require_index(setup.index, "a")
  let b_idx = require_index(setup.index, "b")
  assert_true(
    constraint_graph.nodes[vnode_idx].kind == @network_simplex.NodeKind::Virtual,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, vnode_idx), 30)
  assert_true(
    constraint_graph.nodes[a_idx].kind == @network_simplex.NodeKind::Normal,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, a_idx), 10)
  assert_true(
    constraint_graph.nodes[b_idx].kind == @network_simplex.NodeKind::Normal,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, b_idx), 0)

  append_late_constraint_nodes({
    graph: constraint_graph,
    index: setup.index,
    late_extra_nodes: setup.late_extra_nodes,
  })

  let boundary_idx = require_index(setup.index, boundary)
  assert_true(
    constraint_graph.nodes[boundary_idx].kind ==
    @network_simplex.NodeKind::Slack,
  )
  assert_eq(@network_simplex.node_rank(constraint_graph, boundary_idx), 0)
}

///|
test "add_constraint_edge_if_present only emits edges with both endpoints" {
  let graph = @network_simplex.new_graph()
  let index : Map[String, Int] = Map::new()
  index["a"] = @network_simplex.add_node(graph, "a")
  index["b"] = @network_simplex.add_node(graph, "b")

  add_constraint_edge_if_present(graph, index, {
    tail: "a",
    head: "b",
    minlen: 4,
    weight: 7,
    tail_port: None,
    head_port: None,
  })
  add_constraint_edge_if_present(graph, index, {
    tail: "a",
    head: "missing",
    minlen: 9,
    weight: 9,
    tail_port: None,
    head_port: None,
  })

  assert_eq(graph.edges.length(), 1)
  assert_eq(graph.edges[0].tail, index["a"])
  assert_eq(graph.edges[0].head, index["b"])
  assert_eq(graph.edges[0].minlen, 4)
  assert_eq(graph.edges[0].weight, 7)
}

///|
test "build_reverse_merge_metadata folds reversed duplicates into forward reps" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  forward.set_attr("weight", "2")
  let reversed = graph.edge(b, a, name="rev")
  reversed.set_attr("weight", "3")

  let metadata = build_reverse_merge_metadata({
    edges: [forward, reversed],
    edge_tail: ["a", "a"],
    edge_head: ["b", "b"],
    edge_excluded_from_reverse_merge: _edge => false,
  })

  assert_eq(metadata.merged_edge_weight_bonus.get(0), Some(3))
  assert_eq(metadata.merged_edge_skip.get(1), Some(true))
  assert_eq(metadata.merged_edge_skip.get(0), None)
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
  let with_vnodes = build_x_position_solve_input(build_x_pipeline_input(true))
  let without_vnodes = build_x_position_solve_input(
    build_x_pipeline_input(false),
  )
  let vnode_name = "\{@edge_identity.EDGE_VNODE_PREFIX}0_1"

  assert_eq(with_vnodes.rank_keys, [0])
  assert_eq(with_vnodes.ranks.get("a"), Some(0))
  assert_eq(with_vnodes.ranks.get("b"), Some(0))
  assert_eq(with_vnodes.extra_nodes.length(), 1)
  assert_eq(with_vnodes.extra_nodes[0].name, vnode_name)
  assert_eq(with_vnodes.extra_nodes[0].rank, 1)
  let vnode_size = require_size(with_vnodes.sizes, vnode_name)
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
  let solve_input = build_x_position_solve_input(build_x_pipeline_input(false))

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
fn require_constraint_edge_by_nodes(
  edges : Array[ConstraintEdge],
  tail : String,
  head : String,
) -> ConstraintEdge raise {
  for edge in edges {
    if edge.tail == tail && edge.head == head {
      return edge
    }
  }
  fail("missing constraint edge \{tail}->\{head}")
}

///|
test "append_missing_rank_boundary_targets adds leftmost and rightmost nodes once per non-empty rank" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[2] = ["c", "d", "e"]

  let root_ln_targets = ["a"]
  let root_rn_targets = ["e"]
  append_missing_rank_boundary_targets(
    [0, 1, 2],
    groups,
    root_ln_targets,
    root_rn_targets,
  )

  assert_eq(root_ln_targets, ["a", "c"])
  assert_eq(root_rn_targets, ["e", "b"])
}

///|
test "add_root_boundary_constraints builds slack nodes for plain and compress modes" {
  let plain_graph = @network_simplex.new_graph()
  let plain_index : Map[String, Int] = Map::new()
  plain_index["a"] = @network_simplex.add_node(plain_graph, "a")
  plain_index["b"] = @network_simplex.add_node(plain_graph, "b")
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths_with_h(3.0, 4.0, 8.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths_with_h(5.0, 6.0, 8.0)

  add_root_boundary_constraints({
    graph: plain_graph,
    index: plain_index,
    root_ln_targets: ["a"],
    root_rn_targets: ["b"],
    sizes,
    root_margin: 7.0,
    compress_width_minlen: None,
    root_compress_weight: 128,
  })

  assert_eq(plain_graph.nodes.length(), 4)
  assert_true(plain_graph.nodes[2].kind == @network_simplex.NodeKind::Slack)
  assert_true(plain_graph.nodes[3].kind == @network_simplex.NodeKind::Slack)
  assert_eq(@network_simplex.node_rank(plain_graph, 2), 0)
  assert_eq(@network_simplex.node_rank(plain_graph, 3), 0)
  assert_eq(plain_graph.edges.length(), 2)
  assert_eq(plain_graph.edges[0].tail, 2)
  assert_eq(plain_graph.edges[0].head, plain_index["a"])
  assert_eq(plain_graph.edges[0].minlen, 7)
  assert_eq(plain_graph.edges[1].tail, plain_index["b"])
  assert_eq(plain_graph.edges[1].head, 3)
  assert_eq(plain_graph.edges[1].minlen, 7)

  let compress_graph = @network_simplex.new_graph()
  let compress_index : Map[String, Int] = Map::new()
  compress_index["a"] = @network_simplex.add_node(compress_graph, "a")
  compress_index["b"] = @network_simplex.add_node(compress_graph, "b")

  add_root_boundary_constraints({
    graph: compress_graph,
    index: compress_index,
    root_ln_targets: ["a"],
    root_rn_targets: ["b"],
    sizes,
    root_margin: 2.0,
    compress_width_minlen: Some(20),
    root_compress_weight: 128,
  })

  assert_eq(compress_graph.nodes.length(), 4)
  assert_true(compress_graph.nodes[2].kind == @network_simplex.NodeKind::Slack)
  assert_true(compress_graph.nodes[3].kind == @network_simplex.NodeKind::Slack)
  assert_eq(compress_graph.edges.length(), 3)
  assert_eq(compress_graph.edges[0].tail, 2)
  assert_eq(compress_graph.edges[0].head, compress_index["a"])
  assert_eq(compress_graph.edges[0].minlen, 5)
  assert_eq(compress_graph.edges[1].tail, compress_index["b"])
  assert_eq(compress_graph.edges[1].head, 3)
  assert_eq(compress_graph.edges[1].minlen, 8)
  assert_eq(compress_graph.edges[2].tail, 2)
  assert_eq(compress_graph.edges[2].head, 3)
  assert_eq(compress_graph.edges[2].minlen, 20)
  assert_eq(compress_graph.edges[2].weight, 128)
}

///|
test "build_cluster_constraints adds boundary nodes containment and keepout edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  let c = graph.node("c")

  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 0 }
  let groups : Map[Int, Array[String]] = { 0: ["c", "a", "b"] }
  let sizes : Map[String, @node_primitives.NodeSize] = {
    "a": @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 8.0),
    "b": @node_primitives.vnode_size_from_widths_with_h(4.0, 5.0, 8.0),
    "c": @node_primitives.vnode_size_from_widths_with_h(6.0, 7.0, 8.0),
  }
  let cluster_keys : Map[String, String] = {
    "a": "cluster_0",
    "b": "cluster_0",
  }

  let build = build_cluster_constraints(
    graph,
    [a, b, c],
    [],
    ranks,
    [0],
    groups,
    sizes,
    cluster_keys,
    10.0,
    false,
    Map::new(),
  )

  let left_name = @cluster_identity.cluster_left_boundary_name("cluster_0")
  let right_name = @cluster_identity.cluster_right_boundary_name("cluster_0")
  let extra_node_ranks : Map[String, Int] = Map::new()
  for extra_node in build.extra_nodes {
    extra_node_ranks[extra_node.name] = extra_node.rank
  }

  assert_eq(build.root_ln_targets, [left_name])
  assert_eq(build.root_rn_targets, [right_name])
  assert_eq(extra_node_ranks.get(left_name), Some(9))
  assert_eq(extra_node_ranks.get(right_name), Some(49))
  assert_eq(build.extra_edges.length(), 4)

  let compact = require_constraint_edge_by_nodes(
    build.extra_edges,
    left_name,
    right_name,
  )
  assert_eq(compact.minlen, 1)
  assert_eq(compact.weight, 128)

  let contain_left = require_constraint_edge_by_nodes(
    build.extra_edges,
    left_name,
    "a",
  )
  assert_eq(contain_left.minlen, 10)
  assert_eq(contain_left.weight, 0)

  let contain_right = require_constraint_edge_by_nodes(
    build.extra_edges,
    "b",
    right_name,
  )
  assert_eq(contain_right.minlen, 13)
  assert_eq(contain_right.weight, 0)

  let keepout_left = require_constraint_edge_by_nodes(
    build.extra_edges,
    "c",
    left_name,
  )
  assert_eq(keepout_left.minlen, 15)
  assert_eq(keepout_left.weight, 0)
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
