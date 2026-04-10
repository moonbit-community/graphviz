// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_nonroot_ordered_names keeps forward order only when every tail has no outgoing edges" {
  let rank_names = ["a", "b", "c"]
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  heads_by_tail["b"] = ["x"]

  assert_eq(build_nonroot_ordered_names(rank_names, Map::new()), rank_names)
  assert_eq(build_nonroot_ordered_names(rank_names, heads_by_tail), [
    "c", "b", "a",
  ])
}

///|
test "rebucket_input_like_order groups minimum-rank inputs by local fanout then later then earlier then neutral" {
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  heads_by_tail["i-neutral"] = ["same_1"]
  heads_by_tail["i-earlier"] = ["earlier_head"]
  heads_by_tail["i-later"] = ["later_head"]
  heads_by_tail["i-multi-local"] = ["same_1", "same_2"]

  let cluster_order_pos : Map[String, Int] = Map::new()
  cluster_order_pos["cluster_prev"] = 0
  cluster_order_pos["cluster_cur"] = 1
  cluster_order_pos["cluster_next"] = 2

  let rem_cluster_keys : Map[String, String] = Map::new()
  rem_cluster_keys["same_1"] = "cluster_cur"
  rem_cluster_keys["same_2"] = "cluster_cur"
  rem_cluster_keys["earlier_head"] = "cluster_prev"
  rem_cluster_keys["later_head"] = "cluster_next"

  let reordered = rebucket_input_like_order(
    "cluster_cur",
    ["i-neutral", "i-earlier", "i-later", "i-multi-local"],
    heads_by_tail,
    cluster_order_pos,
    ["cluster_prev", "cluster_cur", "cluster_next"],
    rem_cluster_keys,
  )

  assert_eq(reordered, ["i-multi-local", "i-later", "i-earlier", "i-neutral"])
}

///|
test "build_nonroot_tail_names replays higher ranks first and rebuckets only the minimum non-negative input-like rank" {
  let names = [
    "unknown", "i-neutral", "i-earlier", "i-later", "i-multi-local", "x1", "x2",
  ]
  let rem_ranks : Map[String, Int] = Map::new()
  rem_ranks["i-neutral"] = 0
  rem_ranks["i-earlier"] = 0
  rem_ranks["i-later"] = 0
  rem_ranks["i-multi-local"] = 0
  rem_ranks["x1"] = 1
  rem_ranks["x2"] = 1

  let heads_by_tail : Map[String, Array[String]] = Map::new()
  heads_by_tail["i-neutral"] = ["same_1"]
  heads_by_tail["i-earlier"] = ["earlier_head"]
  heads_by_tail["i-later"] = ["later_head"]
  heads_by_tail["i-multi-local"] = ["same_1", "same_2"]

  let cluster_order_pos : Map[String, Int] = Map::new()
  cluster_order_pos["cluster_prev"] = 0
  cluster_order_pos["cluster_cur"] = 1
  cluster_order_pos["cluster_next"] = 2

  let rem_cluster_keys : Map[String, String] = Map::new()
  rem_cluster_keys["same_1"] = "cluster_cur"
  rem_cluster_keys["same_2"] = "cluster_cur"
  rem_cluster_keys["earlier_head"] = "cluster_prev"
  rem_cluster_keys["later_head"] = "cluster_next"

  let ordered = build_nonroot_tail_names(
    "cluster_cur",
    names,
    rem_ranks,
    heads_by_tail,
    cluster_order_pos,
    ["cluster_prev", "cluster_cur", "cluster_next"],
    rem_cluster_keys,
  )

  assert_eq(ordered, [
    "x1", "x2", "i-multi-local", "i-later", "i-earlier", "i-neutral", "unknown",
  ])
}

///|
test "build_cluster_tail_buckets groups creation replay by first-seen cluster including skeleton fallback names" {
  let cluster1_skeleton = @cluster_identity.cluster_skeleton_name("cluster1", 2)
  let rem_cluster_keys : Map[String, String] = Map::new()
  rem_cluster_keys["root_a"] = ""
  rem_cluster_keys["c1_a"] = "cluster1"
  rem_cluster_keys["c2_a"] = "cluster2"
  rem_cluster_keys["c1_b"] = "cluster1"

  let buckets = build_cluster_tail_buckets(
    ["root_a", cluster1_skeleton, "c2_a", "c1_a", "c1_b"],
    rem_cluster_keys,
  )

  assert_eq(buckets.cluster_order_seen, ["", "cluster1", "cluster2"])
  assert_eq(buckets.names_by_cluster.get(""), Some(["root_a"]))
  assert_eq(
    buckets.names_by_cluster.get("cluster1"),
    Some([cluster1_skeleton, "c1_a", "c1_b"]),
  )
  assert_eq(buckets.names_by_cluster.get("cluster2"), Some(["c2_a"]))
  assert_eq(buckets.cluster_first_seen.get(""), Some(0))
  assert_eq(buckets.cluster_first_seen.get("cluster1"), Some(1))
  assert_eq(buckets.cluster_first_seen.get("cluster2"), Some(2))
}

///|
test "build_cluster_tail_names_for_cluster applies root override only to names present in the root bucket" {
  let root_names = ["root_a", "root_c", "root_b"]
  let context : ClusterTailOrderContext = {
    rem_ranks: Map::new(),
    heads_by_tail: Map::new(),
    cluster_order_pos: Map::new(),
    cluster_order: [""],
    rem_cluster_keys: Map::new(),
    root_tail_order_override: Some(["root_b", "missing", "root_a"]),
  }

  let reordered = build_cluster_tail_names_for_cluster("", root_names, context)

  assert_eq(reordered, ["root_b", "root_a", "root_c"])
}
