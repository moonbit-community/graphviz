// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
