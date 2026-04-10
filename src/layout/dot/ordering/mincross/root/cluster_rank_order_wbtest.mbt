// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn build_order_map(entries : Array[(String, Int)]) -> Map[String, Int] {
  let order_map : Map[String, Int] = Map::new()
  for entry in entries {
    let (name, order) = entry
    order_map[name] = order
  }
  order_map
}

///|
test "build_rank_cluster_bucket_order_map records first-seen cluster buckets and one root bucket" {
  let order_cluster_keys : Map[String, String] = {
    "skel_b": "cluster_b",
    "skel_a": "cluster_a",
    "real_cluster": "cluster_a",
  }
  let order_cluster_skeleton : Map[String, Bool] = {
    "skel_b": true,
    "skel_a": true,
  }
  let real_nodes : Map[String, Bool] = {
    "real_root": true,
    "real_cluster": true,
    "real_root_2": true,
  }

  let order_map = build_rank_cluster_bucket_order_map(
    ["skel_b", "real_root", "skel_a", "real_cluster", "real_root_2"],
    order_cluster_keys,
    order_cluster_skeleton,
    real_nodes,
  )

  assert_eq(order_map.get("cluster_b"), Some(0))
  assert_eq(order_map.get(""), Some(1))
  assert_eq(order_map.get("cluster_a"), Some(2))
  assert_eq(order_map.length(), 3)
}

///|
test "anchor_root_bucket moves root bucket after the single carried left anchor" {
  let order_map = build_order_map([("", 0), ("cluster_a", 1)])
  let previous = build_order_map([("cluster_a", 0), ("", 1)])

  anchor_root_bucket(order_map, Some(previous))

  assert_eq(order_map.get("cluster_a"), Some(0))
  assert_eq(order_map.get(""), Some(1))
}

///|
test "anchor_root_bucket leaves order unchanged when previous rank has both left and right clusters" {
  let order_map = build_order_map([("", 0), ("cluster_a", 1), ("cluster_b", 2)])
  let previous = build_order_map([("cluster_a", 0), ("", 1), ("cluster_b", 2)])

  anchor_root_bucket(order_map, Some(previous))

  assert_eq(order_map.get(""), Some(0))
  assert_eq(order_map.get("cluster_a"), Some(1))
  assert_eq(order_map.get("cluster_b"), Some(2))
}
