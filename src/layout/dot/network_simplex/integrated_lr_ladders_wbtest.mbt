///|
/// Integrated network_simplex scaffold scenarios are split out so the core
/// algorithm wbtest file stays focused on kernel and compact-graph behavior.

///|
test "build_feasible_tree and pre_balance preserve integrated edge-vnode spacing ladder" {
  let tree_graph = build_lr_edge_vnode_spacing_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [
    1, 43, 37, 35, 34, 32, 36, 30, 31, 28, 29, 26, 27, 24, 25, 22, 23, 42, 41, 15,
    12, 47, 10, 9, 40, 46, 7, 39, 19, 16, 45, 38, 44, 4, 20, 2,
  ])

  let balance_graph = build_lr_edge_vnode_spacing_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [
    49, 49, 49, -38, -68, -68, -93, -93, -93, -93, -93, -148, -148, -148, -148, -148,
    -93, -148, -92, -147, -147, -147, -147, -147, -147, -92, -92, -92, -92, -92,
    -67, -67, -37, 50, 50, 50, 50,
  ])
}

///|
test "network_simplex LR preserves integrated edge-vnode spacing ladder" {
  let graph = build_lr_edge_vnode_spacing_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [
    49, 49, 49, 5, -53, -64, -93, -93, -93, -93, -93, -148, -148, -148, -148, -148,
    -113, -133, -112, -132, -147, -147, -147, -147, -147, -92, -92, -92, -92, -92,
    -63, -52, 6, 50, 50, 50, 50,
  ])
}

///|
fn build_lr_edge_labels_fixture_graph() -> NsGraph {
  build_exact_rank_fixture_graph(
    [
      { name: "", kind: NodeKind::Slack, rank: 71 },
      { name: "", kind: NodeKind::Slack, rank: 71 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "", kind: NodeKind::Slack, rank: -1 },
      { name: "a", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Virtual, rank: 0 },
      { name: "c", kind: NodeKind::Normal, rank: 0 },
      { name: "b", kind: NodeKind::Normal, rank: 72 },
      { name: "", kind: NodeKind::Virtual, rank: 99 },
      { name: "d", kind: NodeKind::Normal, rank: 72 },
    ],
    [
      { tail: 0, head: 8, minlen: 1, weight: 2, in_pos: 2 },
      { tail: 0, head: 9, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 1, head: 7, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 1, head: 8, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 2, head: 5, minlen: 1, weight: 2, in_pos: 1 },
      { tail: 2, head: 6, minlen: 1, weight: 2, in_pos: 0 },
      { tail: 3, head: 4, minlen: 1, weight: 2, in_pos: 0 },
      { tail: 3, head: 5, minlen: 1, weight: 2, in_pos: 0 },
      { tail: 4, head: 7, minlen: 72, weight: 0, in_pos: 0 },
      { tail: 5, head: 8, minlen: 100, weight: 0, in_pos: 0 },
      { tail: 6, head: 9, minlen: 72, weight: 0, in_pos: 0 },
    ],
  )
}

///|
test "build_feasible_tree and pre_balance preserve compact LR edge-label ladder spacing" {
  let tree_graph = build_lr_edge_labels_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [
    4, 7, 6, 8, 9, 5, 10, 1, 2,
  ])

  let balance_graph = build_lr_edge_labels_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [
    72, 72, -28, -28, -27, -27, -27, 73, 73, 73,
  ])
}

///|
test "network_simplex LR preserves edge-label ladder spacing" {
  let graph = build_lr_edge_labels_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [
    71, 71, -27, -27, -26, -26, -26, 72, 72, 72,
  ])
}

///|
test "network_simplex LR preserves xlabel cluster spacing from TB inputs" {
  let graph = build_lr_xlabels_tb_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [158, 0, 150, 8, 42, 78, 115, 43, 79])
}
