// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Graphviz parity: this clustered-skeleton tree is the smallest remaining
/// changed integrated mincross case. Keep exact owner-local coverage so the
/// fixture replay can focus on denser clustered reorder interactions.
fn clustered_skeleton_tree_rank_reorder_case() -> (
  MincrossInput,
  MincrossOutput,
) {
  let input_ranks : Array[Array[Int]] = [
    [29],
    [28],
    [7, 24],
    [6, 8, 23, 25, 27],
    [0, 5, 22, 10, 26],
    [1, 3, 4, 21, 9, 11],
    [2, 12],
    [13],
    [14],
    [15],
    [16],
    [17],
    [18],
    [19],
    [20],
  ]
  let output_ranks : Array[Array[Int]] = [
    [29],
    [28],
    [7, 24],
    [8, 6, 23, 27, 25],
    [5, 0, 10, 22, 26],
    [4, 1, 3, 9, 11, 21],
    [2, 12],
    [13],
    [14],
    [15],
    [16],
    [17],
    [18],
    [19],
    [20],
  ]
  let node_names : Array[String?] = []
  let node_clusters : Array[String?] = []
  let node_cluster_skeleton : Array[Bool] = []
  for _ in 0..<30 {
    node_names.push(None)
    node_clusters.push(None)
    node_cluster_skeleton.push(false)
  }
  node_clusters[0] = Some("cluster_clients_mobvm_a")
  node_cluster_skeleton[0] = true
  node_clusters[2] = Some("cluster_machsrv")
  node_cluster_skeleton[2] = true
  node_clusters[5] = Some("cluster_prot_asrv")
  node_cluster_skeleton[5] = true
  node_clusters[7] = Some("cluster_clients_prot_a")
  node_cluster_skeleton[7] = true
  node_clusters[10] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[10] = true
  node_clusters[11] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[11] = true
  node_clusters[12] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[12] = true
  node_clusters[13] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[13] = true
  node_clusters[14] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[14] = true
  node_clusters[16] = Some("cluster_space_ship_a")
  node_cluster_skeleton[16] = true
  node_clusters[17] = Some("cluster_space_ship_a")
  node_cluster_skeleton[17] = true
  node_clusters[18] = Some("cluster_space_ship_a")
  node_cluster_skeleton[18] = true
  node_clusters[19] = Some("cluster_space_ship_a")
  node_cluster_skeleton[19] = true
  node_clusters[20] = Some("cluster_space_ship_a")
  node_cluster_skeleton[20] = true
  node_clusters[22] = Some("cluster_accel")
  node_cluster_skeleton[22] = true
  node_clusters[23] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[23] = true
  node_clusters[24] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[24] = true
  node_clusters[26] = Some("cluster_shapeshifter_misc")
  node_cluster_skeleton[26] = true
  node_clusters[28] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[28] = true
  node_clusters[29] = Some("cluster_yours_trulybox")
  node_cluster_skeleton[29] = true
  let edges : Array[MincrossEdge] = [
    {
      tail: 0,
      head: 1,
      xpenalty: 1,
      seq: 5,
      order: 0,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 0,
      head: 3,
      xpenalty: 1,
      seq: 4,
      order: 1,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 1,
      head: 2,
      xpenalty: 1,
      seq: 5,
      order: 2,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 3,
      head: 2,
      xpenalty: 1,
      seq: 4,
      order: 3,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 4,
      head: 2,
      xpenalty: 1,
      seq: 3,
      order: 4,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 5,
      head: 4,
      xpenalty: 1,
      seq: 3,
      order: 5,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 6,
      head: 5,
      xpenalty: 1,
      seq: 2,
      order: 6,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 7,
      head: 6,
      xpenalty: 1,
      seq: 2,
      order: 7,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 7,
      head: 8,
      xpenalty: 1,
      seq: 1,
      order: 8,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 8,
      head: 5,
      xpenalty: 1,
      seq: 1,
      order: 9,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 9,
      head: 2,
      xpenalty: 1,
      seq: 14,
      order: 10,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 10,
      head: 11,
      xpenalty: 1000,
      seq: 0,
      order: 11,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 10,
      head: 9,
      xpenalty: 1,
      seq: 14,
      order: 12,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 11,
      head: 12,
      xpenalty: 1000,
      seq: 0,
      order: 13,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 12,
      head: 13,
      xpenalty: 1000,
      seq: 0,
      order: 14,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 13,
      head: 14,
      xpenalty: 1000,
      seq: 0,
      order: 15,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 14,
      head: 15,
      xpenalty: 1,
      seq: 21,
      order: 16,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 15,
      head: 16,
      xpenalty: 1,
      seq: 21,
      order: 17,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 16,
      head: 17,
      xpenalty: 1000,
      seq: 0,
      order: 18,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 17,
      head: 18,
      xpenalty: 1000,
      seq: 0,
      order: 19,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 18,
      head: 19,
      xpenalty: 1000,
      seq: 0,
      order: 20,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 19,
      head: 20,
      xpenalty: 1000,
      seq: 0,
      order: 21,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 21,
      head: 12,
      xpenalty: 1,
      seq: 8,
      order: 22,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 22,
      head: 21,
      xpenalty: 1,
      seq: 8,
      order: 23,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 23,
      head: 10,
      xpenalty: 1000,
      seq: 0,
      order: 24,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 24,
      head: 23,
      xpenalty: 1000,
      seq: 0,
      order: 25,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 24,
      head: 25,
      xpenalty: 1,
      seq: 16,
      order: 26,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 24,
      head: 27,
      xpenalty: 1,
      seq: 15,
      order: 27,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 25,
      head: 26,
      xpenalty: 1,
      seq: 16,
      order: 28,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 27,
      head: 26,
      xpenalty: 1,
      seq: 15,
      order: 29,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 28,
      head: 24,
      xpenalty: 1000,
      seq: 0,
      order: 30,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
    {
      tail: 29,
      head: 28,
      xpenalty: 1000,
      seq: 0,
      order: 31,
      tail_port_x: 0,
      head_port_x: 0,
      tail_port_order: 0,
      head_port_order: 0,
    },
  ]
  build_exact_layered_rank_reorder_case(
    1012,
    "clustered_skeleton_tree_reorder",
    0,
    false,
    0,
    input_ranks,
    output_ranks,
    node_names,
    node_clusters,
    node_cluster_skeleton,
    edges,
    Map::new(),
    Map::new(),
  )
}

///|
test "rank_reorder reorders clustered skeleton tree to reduce crossings" {
  let (input, output) = clustered_skeleton_tree_rank_reorder_case()
  run_mincross_case_with_name_order(input, output, Map::new())
}
