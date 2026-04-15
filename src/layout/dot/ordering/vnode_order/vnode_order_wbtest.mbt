// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "edge_internal_to_cluster treats ancestor-related clusters as internal" {
  let cluster_parents : Map[String, String?] = Map::new()
  cluster_parents["child"] = Some("parent")
  cluster_parents["parent"] = None

  assert_true(edge_internal_to_cluster("parent", "child", cluster_parents))
  assert_true(edge_internal_to_cluster("child", "parent", cluster_parents))
  assert_false(edge_internal_to_cluster("left", "right", cluster_parents))
}

///|
test "build_vnode_keys_from_nlist interpolates vnodes between real nodes" {
  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["a", "b"]

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v1", "v2"]

  let order_index : Map[String, Int] = Map::new()
  order_index["a"] = 0
  order_index["b"] = 1

  let nlist_order_index : Map[String, Int] = Map::new()
  nlist_order_index["a"] = 0
  nlist_order_index["v1"] = 1
  nlist_order_index["v2"] = 2
  nlist_order_index["b"] = 3

  let keys = build_vnode_keys_from_nlist(
    ordered_groups,
    vnodes_by_rank,
    order_index,
    nlist_order_index,
    Map::new(),
    false,
  )

  assert_eq(keys.get("v1"), Some(1.0 / 3.0))
  assert_eq(keys.get("v2"), Some(2.0 / 3.0))
}
