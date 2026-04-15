// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_initial_x_groups derives vnode placement from order keys and strips cluster skeletons" {
  let cluster_skeleton = @cluster_identity.cluster_skeleton_name("cluster_0", 0)

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = [cluster_skeleton, "a", "b"]

  let order_index : Map[String, Int] = Map::new()
  order_index[cluster_skeleton] = 0
  order_index["a"] = 1
  order_index["b"] = 2

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v_left", "v_right"]

  let vnode_order_keys : Map[String, Double] = Map::new()
  vnode_order_keys["v_left"] = 1.5
  vnode_order_keys["v_right"] = 2.5

  let x_groups = build_initial_x_groups({
    use_vnodes_for_xpos: true,
    ordered_groups,
    ordered_groups_with_vnodes: Map::new(),
    order_index,
    vnodes_by_rank,
    vnode_order_keys,
    has_clusters: true,
  })

  assert_eq(x_groups.get(0), Some(["a", "v_left", "b", "v_right"]))
}

///|
test "build_x_cluster_keys overlays vnode clusters only when vnode xpos mode is enabled" {
  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_a"
  cluster_keys["v1"] = "cluster_old"

  let vnode_clusters : Map[String, String] = Map::new()
  vnode_clusters["v1"] = "cluster_new"
  vnode_clusters["v2"] = "cluster_v2"

  let disabled = build_x_cluster_keys(cluster_keys, false, vnode_clusters)
  let enabled = build_x_cluster_keys(cluster_keys, true, vnode_clusters)

  assert_eq(disabled.get("a"), Some("cluster_a"))
  assert_eq(disabled.get("v1"), Some("cluster_old"))
  assert_eq(disabled.get("v2"), None)

  assert_eq(enabled.get("a"), Some("cluster_a"))
  assert_eq(enabled.get("v1"), Some("cluster_new"))
  assert_eq(enabled.get("v2"), Some("cluster_v2"))
}
