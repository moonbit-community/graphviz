///|
fn build_zero_balance_fan_fixture_graph() -> NsGraph {
  build_exact_rank_fixture_graph(
    [
      { name: "mobvm_a_req", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "machsrv_xprot_gen", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "z_shapeshifter", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "z_req", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "arbiter_vadam", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "accel_appearance", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "foo_agent", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
      { name: "handle_1", kind: NodeKind::Normal, rank: 0 },
      { name: "", kind: NodeKind::Slack, rank: 0 },
    ],
    [
      { tail: 1, head: 0, minlen: 0, weight: 10, in_pos: 0 },
      { tail: 1, head: 2, minlen: 2, weight: 1, in_pos: 0 },
      { tail: 3, head: 0, minlen: 0, weight: 10, in_pos: 1 },
      { tail: 3, head: 2, minlen: 2, weight: 1, in_pos: 1 },
      { tail: 4, head: 5, minlen: 0, weight: 10, in_pos: 2 },
      { tail: 4, head: 2, minlen: 2, weight: 1, in_pos: 2 },
      { tail: 6, head: 7, minlen: 0, weight: 10, in_pos: 0 },
      { tail: 6, head: 5, minlen: 2, weight: 1, in_pos: 0 },
      { tail: 8, head: 7, minlen: 0, weight: 10, in_pos: 1 },
      { tail: 8, head: 5, minlen: 2, weight: 1, in_pos: 1 },
      { tail: 9, head: 10, minlen: 0, weight: 10, in_pos: 4 },
      { tail: 9, head: 2, minlen: 6, weight: 1, in_pos: 3 },
      { tail: 11, head: 12, minlen: 4, weight: 10, in_pos: 0 },
      { tail: 11, head: 10, minlen: 0, weight: 1, in_pos: 0 },
      { tail: 13, head: 10, minlen: 0, weight: 10, in_pos: 1 },
      { tail: 13, head: 14, minlen: 10, weight: 1, in_pos: 0 },
      { tail: 15, head: 10, minlen: 0, weight: 10, in_pos: 2 },
      { tail: 15, head: 16, minlen: 4, weight: 1, in_pos: 0 },
      { tail: 17, head: 10, minlen: 0, weight: 10, in_pos: 3 },
      { tail: 17, head: 16, minlen: 4, weight: 1, in_pos: 1 },
    ],
  )
}

///|
test "build_feasible_tree and pre_balance preserve compact zero-balance fan scaffold" {
  let tree_graph = build_zero_balance_fan_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [
    0, 2, 11, 10, 13, 12, 14, 15, 16, 17, 19, 7, 6, 8, 4, 1, 5,
  ])

  let balance_graph = build_zero_balance_fan_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [
    4, 4, 6, 4, 4, 4, 2, 2, 2, 0, 0, 0, 4, 0, 10, 0, 4, 0,
  ])
}

///|
/// Graphviz parity: this wide all-normal tree is fixture-sized but its signal is
/// purely algorithmic. Keep it as an owner-local direct case so integrated
/// rank fixture replay can focus on mixed-node graphs with denser structure.
fn build_wide_normal_tree_fixture_graph() -> NsGraph {
  let node_specs : Array[ExactRankNodeSpec] = []
  for i in 0..<43 {
    node_specs.push({ name: "n\{i}", kind: NodeKind::Normal, rank: 0 })
  }
  build_exact_rank_fixture_graph(node_specs, [
    { tail: 0, head: 1, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 1, head: 2, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 3, head: 0, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 3, head: 4, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 3, head: 5, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 3, head: 39, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 3, head: 40, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 5, head: 6, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 5, head: 16, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 5, head: 17, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 6, head: 7, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 6, head: 8, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 6, head: 15, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 8, head: 9, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 9, head: 10, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 9, head: 12, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 9, head: 13, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 10, head: 11, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 13, head: 14, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 17, head: 18, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 17, head: 19, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 17, head: 38, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 19, head: 20, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 19, head: 26, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 19, head: 27, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 20, head: 21, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 20, head: 23, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 20, head: 24, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 21, head: 22, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 24, head: 25, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 27, head: 28, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 28, head: 29, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 28, head: 30, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 28, head: 37, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 30, head: 31, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 31, head: 32, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 31, head: 34, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 31, head: 35, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 32, head: 33, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 35, head: 36, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 40, head: 41, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 41, head: 42, minlen: 1, weight: 1, in_pos: 0 },
  ])
}

///|
test "build_feasible_tree and pre_balance preserve wide normal tree layering" {
  let tree_graph = build_wide_normal_tree_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [
    2, 3, 4, 7, 10, 11, 13, 14, 17, 15, 16, 18, 12, 8, 9, 19, 20, 22, 25, 28, 26,
    27, 29, 23, 24, 30, 31, 32, 34, 35, 38, 36, 37, 39, 33, 21, 5, 6, 40, 41, 0,
    1,
  ])

  let balance_graph = build_wide_normal_tree_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [
    1, 2, 3, 0, 1, 1, 2, 3, 3, 4, 5, 6, 5, 5, 6, 3, 2, 2, 3, 3, 4, 5, 6, 5, 5, 6,
    4, 4, 5, 6, 6, 7, 8, 9, 8, 8, 9, 6, 3, 1, 1, 2, 3,
  ])
}

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
