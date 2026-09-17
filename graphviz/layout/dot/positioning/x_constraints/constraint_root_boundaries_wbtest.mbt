// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "root links follow containment and precede sibling separation and compression" {
  let graph = @network_simplex.new_graph()
  let left = @cluster_identity.cluster_left_boundary_name("cluster_a")
  let right = @cluster_identity.cluster_right_boundary_name("cluster_a")
  let sibling = @cluster_identity.cluster_left_boundary_name("cluster_b")
  let index : Map[String, Int] = Map([])
  for name in [left, right, sibling, "n"] {
    index[name] = @network_simplex.add_node(graph, name)
  }
  let edge = (tail, head, weight) => ConstraintEdge::{
    tail,
    head,
    minlen: 8,
    weight,
    tail_port: None,
    head_port: None,
  }
  add_root_boundary_constraints(
    {
      graph,
      index,
      root_ln_targets: [left, sibling, "n"],
      root_rn_targets: [right, "n"],
      sizes: Map([]),
      root_margin: 8.0,
      compress_width_minlen: Some(200),
      root_compress_weight: 1000,
    },
    extra_edges=[
      edge(left, "n", 0),
      edge("n", right, 0),
      edge(left, right, 128),
      edge(right, sibling, 0),
    ],
  )
  assert_eq(graph.edges.length(), 10)
  assert_eq(graph.edges[0].tail, index[left])
  assert_eq(graph.edges[0].head, index["n"])
  assert_eq(graph.edges[2].weight, 128)
  assert_eq(graph.edges[3].tail, 4)
  assert_eq(graph.edges[3].head, index[left])
  assert_eq(graph.edges[3].minlen, 8)
  assert_eq(graph.edges[5].tail, index[right])
  assert_eq(graph.edges[5].head, 5)
  assert_eq(graph.edges[5].minlen, 8)
  assert_eq(graph.edges[6].tail, index[right])
  assert_eq(graph.edges[6].head, index[sibling])
  assert_eq(graph.edges[7].tail, 4)
  assert_eq(graph.edges[7].head, index["n"])
  assert_eq(graph.edges[8].tail, index["n"])
  assert_eq(graph.edges[8].head, 5)
  assert_eq(graph.edges[9].tail, 4)
  assert_eq(graph.edges[9].head, 5)
  assert_eq(graph.edges[9].minlen, 200)
}

///|
test "append_missing_rank_boundary_targets adds leftmost and rightmost nodes once per non-empty rank" {
  let groups : Map[Int, Array[String]] = Map([])
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
  let plain_index : Map[String, Int] = Map([])
  plain_index["a"] = @network_simplex.add_node(plain_graph, "a")
  plain_index["b"] = @network_simplex.add_node(plain_graph, "b")
  let sizes : Map[String, @node_primitives.NodeSize] = Map([])
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
  let compress_index : Map[String, Int] = Map([])
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
