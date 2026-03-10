///|
fn build_dense_normal_feedback_fixture_graph() -> NsGraph {
  let node_names : Array[String] = [
    "S24", "27", "T24", "23", "T1", "25", "26", "4", "5", "6", "7", "T8", "T35",
    "22", "21", "19", "20", "15", "16", "2", "3", "17", "18", "29", "T30", "33",
    "34", "S30", "31", "32", "12", "10", "11", "14", "13", "S1", "41", "37", "39",
    "38", "43", "40", "S35", "36", "28", "42", "9",
  ]
  let node_specs : Array[ExactRankNodeSpec] = []
  for name in node_names {
    node_specs.push({ name, kind: NodeKind::Normal, rank: 0 })
  }
  build_exact_rank_fixture_graph(node_specs, [
    { tail: 0, head: 1, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 0, head: 5, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 1, head: 2, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 3, head: 4, minlen: 1, weight: 1, in_pos: 6 },
    { tail: 3, head: 2, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 5, head: 4, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 5, head: 6, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 6, head: 7, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 7, head: 8, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 8, head: 3, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 8, head: 9, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 8, head: 12, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 9, head: 10, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 10, head: 11, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 13, head: 3, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 13, head: 12, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 14, head: 13, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 15, head: 14, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 15, head: 16, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 15, head: 44, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 16, head: 17, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 17, head: 4, minlen: 1, weight: 1, in_pos: 5 },
    { tail: 18, head: 17, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 19, head: 4, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 19, head: 20, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 19, head: 18, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 19, head: 21, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 19, head: 22, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 20, head: 7, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 21, head: 15, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 22, head: 23, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 23, head: 24, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 25, head: 24, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 25, head: 26, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 26, head: 23, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 27, head: 28, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 27, head: 25, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 28, head: 4, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 28, head: 29, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 29, head: 3, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 30, head: 23, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 31, head: 4, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 31, head: 32, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 31, head: 33, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 31, head: 34, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 31, head: 30, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 32, head: 7, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 33, head: 17, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 34, head: 15, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 35, head: 31, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 35, head: 19, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 36, head: 23, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 37, head: 38, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 37, head: 36, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 37, head: 39, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 37, head: 41, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 38, head: 17, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 39, head: 7, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 40, head: 39, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 40, head: 41, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 41, head: 15, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 42, head: 43, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 42, head: 40, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 43, head: 15, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 44, head: 23, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 45, head: 7, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 46, head: 45, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 46, head: 4, minlen: 1, weight: 1, in_pos: 4 },
  ])
}

///|
test "build_feasible_tree and pre_balance preserve dense normal feedback layering" {
  let tree_graph = build_dense_normal_feedback_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [
    0, 1, 6, 7, 28, 24, 50, 49, 42, 43, 44, 48, 29, 60, 59, 62, 61, 58, 17, 16, 14,
    3, 4, 15, 18, 20, 19, 64, 31, 45, 25, 27, 8, 10, 12, 13, 36, 35, 38, 33, 53,
    52, 66, 65, 54, 34,
  ])

  let balance_graph = build_dense_normal_feedback_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [
    0, 1, 6, 5, 6, 1, 2, 3, 4, 5, 6, 7, 5, 4, 3, 2, 3, 4, 1, 0, 1, 1, 1, 4, 5, 2,
    3, 1, 3, 4, 1, 0, 1, 1, 1, -1, 1, 0, 1, 1, 0, 1, -1, 0, 3, 2, 1,
  ])
}

///|
test "network_simplex TB rebalances dense normal feedback layering" {
  let graph = build_dense_normal_feedback_fixture_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::TB)

  assert_eq(collect_node_ranks(graph), [
    1, 3, 7, 6, 7, 2, 3, 4, 5, 6, 7, 8, 6, 5, 4, 3, 4, 5, 3, 1, 3, 2, 4, 5, 6, 3,
    4, 2, 4, 5, 3, 1, 3, 4, 2, 0, 4, 1, 2, 2, 1, 2, 0, 1, 4, 3, 2,
  ])
}
