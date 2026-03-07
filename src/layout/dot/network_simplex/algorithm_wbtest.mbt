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

///|
fn build_lr_fanout_graph() -> NsGraph {
  let graph = new_graph()
  let slack = add_node(graph, "slack", kind=NodeKind::Slack)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  ignore(add_edge(graph, slack, a, 1, 2))
  ignore(add_edge(graph, slack, b, 1, 2))
  graph
}

///|
fn build_lr_port_label_graph() -> NsGraph {
  let graph = new_graph()
  let s2 = add_node(graph, "s2", kind=NodeKind::Slack)
  let s1 = add_node(graph, "s1", kind=NodeKind::Slack)
  let s0 = add_node(graph, "s0", kind=NodeKind::Slack)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  let d = add_node(graph, "d")
  let e = add_node(graph, "e")
  let f = add_node(graph, "f")
  ignore(add_edge(graph, s2, e, 1, 2))
  ignore(add_edge(graph, s2, f, 1, 2))
  ignore(add_edge(graph, s1, c, 1, 2))
  ignore(add_edge(graph, s1, d, 1, 2))
  ignore(add_edge(graph, s0, a, 1, 2))
  ignore(add_edge(graph, s0, b, 1, 2))
  ignore(add_edge(graph, a, c, 72, 0))
  ignore(add_edge(graph, b, d, 72, 0))
  ignore(add_edge(graph, c, e, 72, 0))
  ignore(add_edge(graph, d, f, 72, 0))
  graph
}

///|
test "normalize_ranks_for_test ignores auxiliary nodes when choosing the origin" {
  let graph = new_graph()
  let slack = add_node(graph, "slack", kind=NodeKind::Slack)
  let vnode = add_node(graph, "virtual", kind=NodeKind::Virtual)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  set_node_rank(graph, slack, -50)
  set_node_rank(graph, vnode, -30)
  set_node_rank(graph, a, 10)
  set_node_rank(graph, b, 14)

  let max_rank = normalize_ranks_for_test(graph)

  assert_eq(max_rank, 4)
  assert_eq(collect_node_ranks(graph), [-60, -40, 0, 4])
}

///|
test "sort_nodes_by_rank is stable for equal-rank nodes" {
  let graph = new_graph()
  let n0 = add_node(graph, "n0")
  let n1 = add_node(graph, "n1")
  let n2 = add_node(graph, "n2")
  let n3 = add_node(graph, "n3")
  let n4 = add_node(graph, "n4")
  set_node_rank(graph, n0, 2)
  set_node_rank(graph, n1, 1)
  set_node_rank(graph, n2, 2)
  set_node_rank(graph, n3, 1)
  set_node_rank(graph, n4, 2)
  let nodes = [n0, n1, n2, n3, n4]

  sort_nodes_by_rank(graph, nodes)

  assert_eq(nodes, [n1, n3, n0, n2, n4])
}

///|
test "network_simplex LR keeps symmetric fanout nodes aligned" {
  let graph = build_lr_fanout_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  let ranks = collect_node_ranks(graph)

  assert_eq(ranks.length(), 3)
  assert_eq(ranks[1], ranks[2])
  assert_eq(ranks[1] - ranks[0], 1)
}

///|
test "network_simplex LR preserves layered port-label ladder spacing" {
  let graph = build_lr_port_label_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  let ranks = collect_node_ranks(graph)

  assert_eq(ranks.length(), 9)
  assert_eq(ranks[3], ranks[4])
  assert_eq(ranks[5], ranks[6])
  assert_eq(ranks[7], ranks[8])
  assert_eq(ranks[5] - ranks[3], 72)
  assert_eq(ranks[7] - ranks[5], 72)
  assert_eq(ranks[3] - ranks[2], 1)
  assert_eq(ranks[5] - ranks[1], 1)
  assert_eq(ranks[7] - ranks[0], 1)
}
