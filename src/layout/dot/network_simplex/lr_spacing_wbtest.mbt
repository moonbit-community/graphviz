///|
fn build_lr_flat_label_adjacent_graph() -> NsGraph {
  let graph = new_graph()
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  set_node_rank(graph, a, 0)
  set_node_rank(graph, b, 72)
  ignore(add_edge(graph, a, b, 128, 1))
  graph
}

///|
fn build_lr_flat_label_graph() -> NsGraph {
  let graph = new_graph()
  let s0 = add_node(graph, "", kind=NodeKind::Slack)
  let s1 = add_node(graph, "", kind=NodeKind::Slack)
  let v0 = add_node(graph, "", kind=NodeKind::Virtual)
  let a = add_node(graph, "a")
  let b = add_node(graph, "b")
  let c = add_node(graph, "c")
  set_node_rank(graph, s0, -1)
  set_node_rank(graph, s1, -55)
  set_node_rank(graph, v0, 0)
  set_node_rank(graph, a, 0)
  set_node_rank(graph, b, 72)
  set_node_rank(graph, c, 144)
  ignore(add_edge(graph, s0, v0, 1, 1))
  ignore(add_edge(graph, s0, c, 1, 1))
  ignore(add_edge(graph, s1, v0, 55, 1))
  ignore(add_edge(graph, s1, a, 1, 1))
  ignore(add_edge(graph, v0, c, 73, 1))
  ignore(add_edge(graph, a, v0, 73, 1))
  ignore(add_edge(graph, a, b, 90, 100))
  ignore(add_edge(graph, b, c, 90, 100))
  graph
}

///|
fn build_lr_compound_clusters_graph() -> NsGraph {
  let graph = new_graph()
  let s0 = add_node(graph, "", kind=NodeKind::Slack)
  let s1 = add_node(graph, "", kind=NodeKind::Slack)
  let s2 = add_node(graph, "", kind=NodeKind::Slack)
  let s3 = add_node(graph, "", kind=NodeKind::Slack)
  let s4 = add_node(graph, "", kind=NodeKind::Slack)
  let s5 = add_node(graph, "", kind=NodeKind::Slack)
  let s6 = add_node(graph, "", kind=NodeKind::Slack)
  let c2n1 = add_node(graph, "C2N1")
  let c1n1 = add_node(graph, "C1N1")
  set_node_rank(graph, s0, 0)
  set_node_rank(graph, s1, 0)
  set_node_rank(graph, s2, 0)
  set_node_rank(graph, s3, 0)
  set_node_rank(graph, s4, 0)
  set_node_rank(graph, s5, 0)
  set_node_rank(graph, s6, -1)
  set_node_rank(graph, c2n1, 0)
  set_node_rank(graph, c1n1, 0)
  ignore(add_edge(graph, s1, s5, 8, 0))
  ignore(add_edge(graph, s1, s3, 8, 0))
  ignore(add_edge(graph, s2, s0, 8, 0))
  ignore(add_edge(graph, s3, s2, 66, 128))
  ignore(add_edge(graph, s3, c2n1, 41, 0))
  ignore(add_edge(graph, s4, s0, 8, 0))
  ignore(add_edge(graph, s5, s4, 66, 128))
  ignore(add_edge(graph, s5, c1n1, 41, 0))
  ignore(add_edge(graph, s6, c1n1, 1, 1))
  ignore(add_edge(graph, s6, c2n1, 1, 1))
  ignore(add_edge(graph, c2n1, s2, 41, 0))
  ignore(add_edge(graph, c1n1, s4, 41, 0))
  graph
}

///|
test "network_simplex LR preserves adjacent flat-label spacing" {
  let graph = build_lr_flat_label_adjacent_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [0, 128])
}

///|
test "network_simplex LR preserves non-adjacent flat-label spacing" {
  let graph = build_lr_flat_label_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [73, -17, 74, -16, 74, 164])
}

///|
fn build_lr_compound_clusters_fixture_graph() -> NsGraph {
  build_exact_rank_fixture_graph(
    [
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "C2N1", kind: NodeKind::Normal, rank: 0 },
      { name: "C1N1", kind: NodeKind::Normal, rank: 0 },
    ],
    [
      { tail: 1, head: 5, minlen: 8, weight: 0, in_pos: 0 },
      { tail: 1, head: 3, minlen: 8, weight: 0, in_pos: 0 },
      { tail: 2, head: 0, minlen: 8, weight: 0, in_pos: 1 },
      { tail: 3, head: 2, minlen: 67, weight: 128, in_pos: 0 },
      { tail: 3, head: 7, minlen: 39, weight: 0, in_pos: 1 },
      { tail: 4, head: 0, minlen: 8, weight: 0, in_pos: 0 },
      { tail: 5, head: 4, minlen: 67, weight: 128, in_pos: 0 },
      { tail: 5, head: 8, minlen: 39, weight: 0, in_pos: 1 },
      { tail: 6, head: 8, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 6, head: 7, minlen: 1, weight: 1, in_pos: 0 },
      { tail: 7, head: 2, minlen: 39, weight: 0, in_pos: 1 },
      { tail: 8, head: 4, minlen: 39, weight: 0, in_pos: 1 },
    ],
  )
}

///|
test "build_feasible_tree and pre_balance preserve compact LR compound cluster spacing" {
  let tree_graph = build_lr_compound_clusters_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [5, 11, 7, 0, 1, 4, 10, 8])

  let balance_graph = build_lr_compound_clusters_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [
    94, 0, 86, 8, 86, 8, 46, 47, 47,
  ])
}

///|
test "network_simplex LR preserves compound cluster spacing" {
  let graph = build_lr_compound_clusters_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [98, 0, 90, 8, 90, 8, 48, 49, 49])
}
