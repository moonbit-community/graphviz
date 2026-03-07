///|
fn build_init_rank_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  ignore(add_edge(graph, a, c, 1, 1))
  ignore(add_edge(graph, b, c, 3, 1))
  graph
}

///|
fn build_feasible_tree_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  ignore(add_edge(graph, a, b, 2, 1))
  ignore(add_edge(graph, b, c, 1, 1))
  ignore(add_edge(graph, a, c, 4, 1))
  graph
}

///|
fn build_tb_balance_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  ignore(add_edge(graph, a, b, 1, 1))
  ignore(add_edge(graph, b, c, 1, 1))
  ignore(add_edge(graph, a, c, 4, 1))
  graph
}

///|
fn collect_node_ranks(graph : NsGraph) -> Array[Int] {
  let ranks : Array[Int] = []
  for i in 0..<graph.nodes.length() {
    ranks.push(node_rank(graph, i))
  }
  ranks
}

///|
test "init_rank uses the maximum incoming minlen constraint" {
  let graph = build_init_rank_graph()
  ignore(init_graph(graph))
  init_rank(graph)

  assert_eq(collect_node_ranks(graph), [0, 0, 3])
}

///|
test "normalize_ranks_for_test shifts the minimum rank to zero" {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  set_node_rank(graph, a, -3)
  set_node_rank(graph, b, -1)
  set_node_rank(graph, c, 2)

  let max_rank = normalize_ranks_for_test(graph)

  assert_eq(max_rank, 5)
  assert_eq(collect_node_ranks(graph), [0, 2, 5])
}

///|
test "build_feasible_tree selects a tight spanning tree" {
  let graph = build_feasible_tree_graph()

  guard build_feasible_tree(graph) else {
    fail("expected feasible tree to exist")
  }
  assert_eq(graph.tree_edges.length(), graph.nodes.length() - 1)
  for edge_idx in graph.tree_edges {
    assert_eq(edge_slack(graph, edge_idx), 0)
  }
  for node_idx in 1..<graph.nodes.length() {
    guard graph.nodes[node_idx].par_edge != NONE_EDGE else {
      fail("expected node \{node_idx} to receive a parent edge")
    }
  }
}

///|
test "network_simplex TB balance moves a node to the sparsest feasible rank" {
  let graph = build_tb_balance_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::TB)

  assert_eq(collect_node_ranks(graph), [0, 2, 4])
}
