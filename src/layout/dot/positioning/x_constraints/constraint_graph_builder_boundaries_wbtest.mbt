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

  let vnode_idx = require_constraint_builder_index(setup.index, vnode)
  let a_idx = require_constraint_builder_index(setup.index, "a")
  let b_idx = require_constraint_builder_index(setup.index, "b")
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

  let boundary_idx = require_constraint_builder_index(setup.index, boundary)
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
