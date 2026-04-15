// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Graphviz parity: this larger LR slack-normal scaffold is still algorithmic
/// enough to express owner-locally. Keep exact feasible-tree, pre-balance,
/// and final-rank coverage so rank fixture replay can focus on the denser
/// remaining LR cases.
fn build_large_lr_slack_normal_fixture_graph() -> NsGraph {
  let node_specs : Array[ExactRankNodeSpec] = []
  let slack_ranks : Array[Int] = [
    287, 287, 95, -1, -1, -1, -1, -1, 431, 431, 371, 215, 287, 191, 71, 71, 71, 215,
    143, 71, 215, 215, 215, 95, -1, -1, -1, -1, -1, 71, 71, 71, 143, 143, 71, -1,
    -1, -1, -1, -1, -1, -1,
  ]
  for rank in slack_ranks {
    node_specs.push({ name: "", kind: NodeKind::Slack, rank })
  }
  let normal_names : Array[String] = [
    "n1", "n2", "n3", "n0", "n4", "n5", "n6", "n7", "n8", "n9", "n10", "n11", "n12",
    "n13", "n14", "n15", "n16", "n17", "n18", "n19", "n20", "n21", "n22", "n23",
    "n24", "n25", "n26", "n27", "n28", "n29", "n30", "n31", "n32", "n33", "n34",
    "n35", "n36", "n37", "n38", "n39", "n40", "n41", "n42",
  ]
  let normal_ranks : Array[Int] = [
    0, 0, 0, 0, 72, 144, 72, 84, 156, 0, 0, 0, 72, 144, 96, 228, 144, 216, 300, 372,
    72, 216, 192, 288, 360, 288, 144, 216, 432, 372, 444, 0, 0, 0, 72, 144, 96, 516,
    444, 216, 288, 288, 528,
  ]
  for i in 0..<normal_names.length() {
    node_specs.push({
      name: normal_names[i],
      kind: NodeKind::Normal,
      rank: normal_ranks[i],
    })
  }
  build_exact_rank_fixture_graph(node_specs, [
    { tail: 0, head: 83, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 0, head: 84, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 1, head: 82, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 1, head: 83, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 2, head: 77, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 2, head: 78, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 3, head: 74, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 3, head: 75, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 4, head: 73, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 4, head: 77, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 5, head: 73, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 5, head: 76, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 6, head: 73, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 6, head: 74, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 7, head: 72, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 7, head: 73, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 8, head: 70, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 8, head: 79, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 9, head: 70, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 9, head: 72, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 10, head: 70, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 10, head: 71, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 11, head: 69, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 11, head: 70, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 12, head: 66, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 12, head: 67, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 13, head: 63, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 13, head: 64, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 14, head: 62, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 14, head: 66, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 15, head: 62, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 15, head: 65, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 16, head: 62, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 16, head: 63, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 17, head: 61, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 17, head: 69, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 18, head: 61, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 18, head: 68, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 19, head: 61, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 19, head: 62, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 20, head: 59, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 20, head: 80, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 21, head: 59, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 21, head: 61, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 22, head: 59, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 22, head: 60, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 23, head: 55, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 23, head: 56, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 24, head: 52, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 24, head: 53, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 25, head: 51, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 25, head: 55, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 26, head: 51, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 26, head: 54, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 27, head: 51, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 27, head: 52, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 28, head: 50, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 28, head: 51, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 29, head: 48, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 29, head: 57, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 30, head: 48, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 30, head: 50, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 31, head: 48, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 31, head: 49, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 32, head: 47, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 32, head: 59, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 33, head: 47, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 33, head: 58, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 34, head: 47, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 34, head: 48, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 35, head: 45, minlen: 1, weight: 1, in_pos: 4 },
    { tail: 35, head: 82, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 36, head: 45, minlen: 1, weight: 1, in_pos: 3 },
    { tail: 36, head: 81, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 37, head: 45, minlen: 1, weight: 1, in_pos: 2 },
    { tail: 37, head: 47, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 38, head: 45, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 38, head: 46, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 39, head: 45, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 39, head: 42, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 40, head: 43, minlen: 1, weight: 1, in_pos: 1 },
    { tail: 40, head: 44, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 41, head: 42, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 41, head: 43, minlen: 1, weight: 1, in_pos: 0 },
    { tail: 42, head: 46, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 43, head: 48, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 44, head: 49, minlen: 84, weight: 0, in_pos: 0 },
    { tail: 46, head: 47, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 47, head: 81, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 48, head: 58, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 49, head: 50, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 50, head: 57, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 51, head: 62, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 52, head: 54, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 53, head: 56, minlen: 97, weight: 0, in_pos: 0 },
    { tail: 54, head: 55, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 55, head: 63, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 56, head: 64, minlen: 97, weight: 0, in_pos: 0 },
    { tail: 57, head: 60, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 58, head: 59, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 59, head: 83, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 60, head: 61, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 61, head: 80, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 62, head: 68, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 63, head: 65, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 64, head: 67, minlen: 97, weight: 0, in_pos: 0 },
    { tail: 65, head: 66, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 66, head: 70, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 67, head: 71, minlen: 84, weight: 0, in_pos: 0 },
    { tail: 68, head: 69, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 71, head: 72, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 72, head: 79, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 74, head: 76, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 75, head: 78, minlen: 97, weight: 0, in_pos: 0 },
    { tail: 76, head: 77, minlen: 72, weight: 0, in_pos: 0 },
    { tail: 80, head: 84, minlen: 85, weight: 0, in_pos: 0 },
    { tail: 81, head: 82, minlen: 72, weight: 0, in_pos: 0 },
  ])
}

///|
test "build_feasible_tree and pre_balance preserve large LR slack-normal scaffold" {
  let tree_graph = build_large_lr_slack_normal_fixture_graph()
  assert_eq(feasible_tree_edges_for_test(tree_graph), [
    6, 13, 12, 15, 10, 8, 112, 114, 7, 113, 48, 55, 54, 57, 52, 50, 92, 103, 109,
    93, 95, 96, 104, 106, 107, 49, 94, 97, 105, 108, 110, 111, 70, 78, 79, 82, 83,
    80, 81, 86, 90, 91, 98, 101, 102, 115, 85, 89, 99, 100, 84, 87, 88, 116, 76,
    74, 72, 0, 2, 69, 66, 64, 62, 60, 58, 22, 47, 44, 42, 39, 40, 37, 35, 32, 30,
    28, 27, 25, 16, 21, 18, 5, 14, 34,
  ])

  let balance_graph = build_large_lr_slack_normal_fixture_graph()
  assert_eq(pre_balance_ranks_for_test(balance_graph), [
    132, 132, 313, 169, 241, 241, 169, 241, 204, 204, 169, 204, 85, -12, 60, 60,
    -12, 132, 132, 60, 60, 60, 60, -109, -228, -84, -156, -228, -84, -84, -84, -156,
    -12, -12, -84, -12, -12, -12, -84, -156, -240, -156, -155, -155, -239, -11, -83,
    -11, -83, -155, -83, -83, -227, -227, -155, -83, -108, -11, -11, 61, 61, 133,
    61, -11, -11, 61, 133, 86, 133, 205, 205, 170, 242, 242, 170, 170, 242, 314,
    314, 314, 205, 61, 133, 133, 290,
  ])
}

///|
test "network_simplex LR rebalances large slack-normal scaffold" {
  let graph = build_large_lr_slack_normal_fixture_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [
    132, 57, 270, 126, 198, 198, 126, 198, 144, 144, 126, 126, 42, -90, -18, -18,
    -90, 18, 18, -18, -18, -18, -54, -175, -306, -216, -234, -306, -216, -198, -198,
    -270, -126, -126, -198, -126, -126, -126, -198, -291, -354, -312, -290, -311,
    -353, -125, -197, -125, -197, -269, -197, -215, -305, -305, -233, -161, -174,
    -125, -125, -17, -53, 19, -17, -89, -77, -17, 55, 43, 55, 127, 145, 127, 199,
    199, 127, 127, 199, 271, 271, 271, 91, -53, 58, 133, 176,
  ])
}
