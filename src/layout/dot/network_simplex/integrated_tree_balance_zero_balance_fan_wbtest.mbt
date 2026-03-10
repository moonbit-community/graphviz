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
