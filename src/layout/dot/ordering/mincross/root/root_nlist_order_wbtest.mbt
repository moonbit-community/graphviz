// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_root_tail_order_seed replaces clustered names with rank-qualified skeletons and dedupes repeats" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_a_0"] = "cluster_a"
  cluster_keys["cluster_a_0_dup"] = "cluster_a"
  cluster_keys["cluster_a_1"] = "cluster_a"
  cluster_keys["cluster_b_0"] = "cluster_b"

  let ranks : Map[String, Int] = Map::new()
  ranks["cluster_a_0"] = 0
  ranks["cluster_a_0_dup"] = 0
  ranks["cluster_a_1"] = 1
  ranks["cluster_b_0"] = 0

  let tail_order = build_root_tail_order_seed(
    [
      "root", "cluster_a_0", "cluster_a_0_dup", "cluster_a_1", "cluster_b_0", "root",
    ],
    cluster_keys,
    ranks,
  )

  assert_eq(tail_order, [
    "root",
    @cluster_identity.cluster_skeleton_name("cluster_a", 0),
    @cluster_identity.cluster_skeleton_name("cluster_a", 1),
    @cluster_identity.cluster_skeleton_name("cluster_b", 0),
  ])
}

///|
test "build_root_source_first_tail_order moves source tails ahead while preserving original order within each bucket" {
  let tail_order = build_root_source_first_tail_order(
    ["mid", "src1", "sink", "src2"],
    ["src1", "src2", "mid", "sink"],
    [("src1", "mid"), ("mid", "sink")],
  )

  assert_eq(tail_order, ["src1", "src2", "mid", "sink"])
}

///|
test "finalize_root_nlist_order keeps only materialized nodes then appends missing root nodes in root order" {
  let root_nodes = ["a", "b", "c", "d"]
  let graph_output = @order_graph.build_order_graph_and_nodes(
    "root_nlist_finalize", root_nodes,
  )

  let finalized = finalize_root_nlist_order(
    ["ghost", "c", "a"],
    root_nodes,
    graph_output.order_node_map,
  )

  assert_eq(finalized, ["c", "a", "b", "d"])
}

///|
test "build_root_nlist_order seeds from skeletonized tail order, replays edge creation, and appends missing root nodes" {
  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_x", 0)
  let root_nodes = [skeleton_0, "root_b", "root_a", "v_cross"]
  let graph_output = @order_graph.build_order_graph_and_nodes(
    "root_nlist_order", root_nodes,
  )

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_member"] = "cluster_x"

  let ranks : Map[String, Int] = Map::new()
  ranks["cluster_member"] = 0

  let root_nlist_order = build_root_nlist_order(
    ["cluster_member", "root_b", "root_a"],
    cluster_keys,
    ranks,
    root_nodes,
    graph_output.order_node_map,
    [(skeleton_0, "root_b")],
    [("root_b", "root_a")],
    Map::new(),
  )

  assert_eq(root_nlist_order, [skeleton_0, "root_b", "root_a", "v_cross"])
}
