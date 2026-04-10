// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Graphviz parity: the captured LR xpos scaffold for `L0` is not identical
/// to the rank-fixture-derived slack-normal scaffold above. Keep the exact
/// captured node ranks and minlen ladder owner-locally so the xpos fixture
/// replay can retire without losing its distinct signal.
fn build_l0_xpos_fixture_graph() -> NsGraph {
  let node_specs : Array[ExactRankNodeSpec] = []
  let slack_ranks : Array[Int] = [
    287, 287, 94, -1, -1, -1, -1, -1, 431, 431, 367, 215, 284, 189, 71, 71, 71, 215,
    143, 71, 215, 215, 215, 94, -1, -1, -1, -1, -1, 71, 71, 71, 143, 143, 71, -1,
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
    0, 0, 0, 0, 72, 144, 72, 83, 155, 0, 0, 0, 72, 144, 95, 227, 144, 216, 299, 371,
    72, 216, 190, 288, 360, 285, 144, 216, 432, 368, 440, 0, 0, 0, 72, 144, 95, 512,
    443, 216, 288, 288, 526,
  ]
  for i in 0..<normal_names.length() {
    node_specs.push({
      name: normal_names[i],
      kind: NodeKind::Normal,
      rank: normal_ranks[i],
    })
  }
  build_captured_rank_fixture_graph(node_specs, [
    { tail: 0, head: 83, minlen: 1, weight: 1 },
    { tail: 0, head: 84, minlen: 1, weight: 1 },
    { tail: 1, head: 82, minlen: 1, weight: 1 },
    { tail: 1, head: 83, minlen: 1, weight: 1 },
    { tail: 2, head: 77, minlen: 1, weight: 1 },
    { tail: 2, head: 78, minlen: 1, weight: 1 },
    { tail: 3, head: 74, minlen: 1, weight: 1 },
    { tail: 3, head: 75, minlen: 1, weight: 1 },
    { tail: 4, head: 73, minlen: 1, weight: 1 },
    { tail: 4, head: 77, minlen: 1, weight: 1 },
    { tail: 5, head: 73, minlen: 1, weight: 1 },
    { tail: 5, head: 76, minlen: 1, weight: 1 },
    { tail: 6, head: 73, minlen: 1, weight: 1 },
    { tail: 6, head: 74, minlen: 1, weight: 1 },
    { tail: 7, head: 72, minlen: 1, weight: 1 },
    { tail: 7, head: 73, minlen: 1, weight: 1 },
    { tail: 8, head: 70, minlen: 1, weight: 1 },
    { tail: 8, head: 79, minlen: 1, weight: 1 },
    { tail: 9, head: 70, minlen: 1, weight: 1 },
    { tail: 9, head: 72, minlen: 1, weight: 1 },
    { tail: 10, head: 70, minlen: 1, weight: 1 },
    { tail: 10, head: 71, minlen: 1, weight: 1 },
    { tail: 11, head: 69, minlen: 1, weight: 1 },
    { tail: 11, head: 70, minlen: 1, weight: 1 },
    { tail: 12, head: 66, minlen: 1, weight: 1 },
    { tail: 12, head: 67, minlen: 1, weight: 1 },
    { tail: 13, head: 63, minlen: 1, weight: 1 },
    { tail: 13, head: 64, minlen: 1, weight: 1 },
    { tail: 14, head: 62, minlen: 1, weight: 1 },
    { tail: 14, head: 66, minlen: 1, weight: 1 },
    { tail: 15, head: 62, minlen: 1, weight: 1 },
    { tail: 15, head: 65, minlen: 1, weight: 1 },
    { tail: 16, head: 62, minlen: 1, weight: 1 },
    { tail: 16, head: 63, minlen: 1, weight: 1 },
    { tail: 17, head: 61, minlen: 1, weight: 1 },
    { tail: 17, head: 69, minlen: 1, weight: 1 },
    { tail: 18, head: 61, minlen: 1, weight: 1 },
    { tail: 18, head: 68, minlen: 1, weight: 1 },
    { tail: 19, head: 61, minlen: 1, weight: 1 },
    { tail: 19, head: 62, minlen: 1, weight: 1 },
    { tail: 20, head: 59, minlen: 1, weight: 1 },
    { tail: 20, head: 80, minlen: 1, weight: 1 },
    { tail: 21, head: 59, minlen: 1, weight: 1 },
    { tail: 21, head: 61, minlen: 1, weight: 1 },
    { tail: 22, head: 59, minlen: 1, weight: 1 },
    { tail: 22, head: 60, minlen: 1, weight: 1 },
    { tail: 23, head: 55, minlen: 1, weight: 1 },
    { tail: 23, head: 56, minlen: 1, weight: 1 },
    { tail: 24, head: 52, minlen: 1, weight: 1 },
    { tail: 24, head: 53, minlen: 1, weight: 1 },
    { tail: 25, head: 51, minlen: 1, weight: 1 },
    { tail: 25, head: 55, minlen: 1, weight: 1 },
    { tail: 26, head: 51, minlen: 1, weight: 1 },
    { tail: 26, head: 54, minlen: 1, weight: 1 },
    { tail: 27, head: 51, minlen: 1, weight: 1 },
    { tail: 27, head: 52, minlen: 1, weight: 1 },
    { tail: 28, head: 50, minlen: 1, weight: 1 },
    { tail: 28, head: 51, minlen: 1, weight: 1 },
    { tail: 29, head: 48, minlen: 1, weight: 1 },
    { tail: 29, head: 57, minlen: 1, weight: 1 },
    { tail: 30, head: 48, minlen: 1, weight: 1 },
    { tail: 30, head: 50, minlen: 1, weight: 1 },
    { tail: 31, head: 48, minlen: 1, weight: 1 },
    { tail: 31, head: 49, minlen: 1, weight: 1 },
    { tail: 32, head: 47, minlen: 1, weight: 1 },
    { tail: 32, head: 59, minlen: 1, weight: 1 },
    { tail: 33, head: 47, minlen: 1, weight: 1 },
    { tail: 33, head: 58, minlen: 1, weight: 1 },
    { tail: 34, head: 47, minlen: 1, weight: 1 },
    { tail: 34, head: 48, minlen: 1, weight: 1 },
    { tail: 35, head: 45, minlen: 1, weight: 1 },
    { tail: 35, head: 82, minlen: 1, weight: 1 },
    { tail: 36, head: 45, minlen: 1, weight: 1 },
    { tail: 36, head: 81, minlen: 1, weight: 1 },
    { tail: 37, head: 45, minlen: 1, weight: 1 },
    { tail: 37, head: 47, minlen: 1, weight: 1 },
    { tail: 38, head: 45, minlen: 1, weight: 1 },
    { tail: 38, head: 46, minlen: 1, weight: 1 },
    { tail: 39, head: 45, minlen: 1, weight: 1 },
    { tail: 39, head: 42, minlen: 1, weight: 1 },
    { tail: 40, head: 43, minlen: 1, weight: 1 },
    { tail: 40, head: 44, minlen: 1, weight: 1 },
    { tail: 41, head: 42, minlen: 1, weight: 1 },
    { tail: 41, head: 43, minlen: 1, weight: 1 },
    { tail: 42, head: 46, minlen: 72, weight: 0 },
    { tail: 43, head: 48, minlen: 72, weight: 0 },
    { tail: 44, head: 49, minlen: 83, weight: 0 },
    { tail: 46, head: 47, minlen: 72, weight: 0 },
    { tail: 47, head: 81, minlen: 72, weight: 0 },
    { tail: 48, head: 58, minlen: 72, weight: 0 },
    { tail: 49, head: 50, minlen: 72, weight: 0 },
    { tail: 50, head: 57, minlen: 72, weight: 0 },
    { tail: 51, head: 62, minlen: 72, weight: 0 },
    { tail: 52, head: 54, minlen: 72, weight: 0 },
    { tail: 53, head: 56, minlen: 95, weight: 0 },
    { tail: 54, head: 55, minlen: 72, weight: 0 },
    { tail: 55, head: 63, minlen: 72, weight: 0 },
    { tail: 56, head: 64, minlen: 95, weight: 0 },
    { tail: 57, head: 60, minlen: 72, weight: 0 },
    { tail: 58, head: 59, minlen: 72, weight: 0 },
    { tail: 59, head: 83, minlen: 72, weight: 0 },
    { tail: 60, head: 61, minlen: 72, weight: 0 },
    { tail: 61, head: 80, minlen: 72, weight: 0 },
    { tail: 62, head: 68, minlen: 72, weight: 0 },
    { tail: 63, head: 65, minlen: 72, weight: 0 },
    { tail: 64, head: 67, minlen: 95, weight: 0 },
    { tail: 65, head: 66, minlen: 72, weight: 0 },
    { tail: 66, head: 70, minlen: 72, weight: 0 },
    { tail: 67, head: 71, minlen: 83, weight: 0 },
    { tail: 68, head: 69, minlen: 72, weight: 0 },
    { tail: 71, head: 72, minlen: 72, weight: 0 },
    { tail: 72, head: 79, minlen: 72, weight: 0 },
    { tail: 74, head: 76, minlen: 72, weight: 0 },
    { tail: 75, head: 78, minlen: 95, weight: 0 },
    { tail: 76, head: 77, minlen: 72, weight: 0 },
    { tail: 80, head: 84, minlen: 84, weight: 0 },
    { tail: 81, head: 82, minlen: 72, weight: 0 },
  ])
}

///|
test "network_simplex LR matches exact L0 xpos fixture ranks" {
  let graph = build_l0_xpos_fixture_graph()

  network_simplex(graph, 0x7fffffff, BalanceMode::LR)

  assert_eq(collect_node_ranks(graph), [
    133, 58, 268, 124, 196, 196, 124, 196, 144, 144, 124, 127, 41, -89, -17, -17,
    -89, 19, 19, -17, -17, -17, -53, -173, -305, -215, -233, -305, -215, -197, -197,
    -269, -125, -125, -197, -125, -125, -125, -197, -289, -352, -310, -288, -309,
    -351, -124, -196, -124, -196, -268, -196, -214, -304, -304, -232, -160, -172,
    -124, -124, -16, -52, 20, -16, -88, -77, -16, 56, 42, 56, 128, 145, 125, 197,
    197, 125, 125, 197, 269, 269, 269, 92, -52, 59, 134, 176,
  ])
}
