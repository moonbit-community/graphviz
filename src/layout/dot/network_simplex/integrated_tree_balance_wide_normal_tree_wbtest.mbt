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
