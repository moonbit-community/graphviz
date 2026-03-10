///|
/// Integrated network_simplex edge-vnode spacing ladders stay owner-local so
/// the core wbtest file can focus on kernel and compact-graph behavior.

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
