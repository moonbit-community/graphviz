// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
