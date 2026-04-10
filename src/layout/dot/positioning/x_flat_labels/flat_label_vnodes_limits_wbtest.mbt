// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "flat_limits shifts insertion right when an earlier flat label occupies the left side" {
  let order_index : Map[String, Int] = Map::new()
  order_index["x"] = 0
  order_index["a"] = 1
  order_index["b"] = 3
  order_index["left_label"] = 0

  let flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  flat_label_nodes["left_label"] = { tail: "x", head: "a", rank: -1 }

  let vnode_out_heads : Map[String, Array[String]] = Map::new()
  assert_eq(
    flat_limits(
      ["left_label", "slot1", "slot2"],
      order_index,
      flat_label_nodes,
      vnode_out_heads,
      "a",
      "b",
    ),
    2,
  )
}

///|
test "flat_limits shifts away from existing vnode fanouts on either side" {
  let left_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}left"
  let right_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}right"
  let flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()

  let left_order_index : Map[String, Int] = Map::new()
  left_order_index[left_vnode] = 0
  left_order_index["slot1"] = 1
  left_order_index["slot2"] = 2
  left_order_index["a"] = 1
  left_order_index["b"] = 2
  left_order_index["x"] = 0
  let left_vnode_out_heads : Map[String, Array[String]] = Map::new()
  left_vnode_out_heads[left_vnode] = ["x"]
  assert_eq(
    flat_limits(
      [left_vnode, "slot1", "slot2"],
      left_order_index,
      flat_label_nodes,
      left_vnode_out_heads,
      "a",
      "b",
    ),
    2,
  )

  let right_order_index : Map[String, Int] = Map::new()
  right_order_index["slot0"] = 0
  right_order_index["slot1"] = 1
  right_order_index[right_vnode] = 2
  right_order_index["a"] = 0
  right_order_index["b"] = 1
  right_order_index["y"] = 2
  let right_vnode_out_heads : Map[String, Array[String]] = Map::new()
  right_vnode_out_heads[right_vnode] = ["y"]
  assert_eq(
    flat_limits(
      ["slot0", "slot1", right_vnode],
      right_order_index,
      flat_label_nodes,
      right_vnode_out_heads,
      "a",
      "b",
    ),
    0,
  )
}

///|
test "flat_limits falls back to midpoint when left and right vnode fanouts exhaust the primary slot window" {
  let left_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}left"
  let right_vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}right"
  let flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()

  let order_index : Map[String, Int] = Map::new()
  order_index["x"] = 0
  order_index[right_vnode] = 1
  order_index["a"] = 1
  order_index[left_vnode] = 2
  order_index["b"] = 2
  order_index["slot0"] = 0
  order_index["slot1"] = 3
  order_index["y"] = 3

  let vnode_out_heads : Map[String, Array[String]] = Map::new()
  vnode_out_heads[left_vnode] = ["x"]
  vnode_out_heads[right_vnode] = ["y"]

  assert_eq(
    flat_limits(
      [right_vnode, "slot0", "slot1", left_vnode],
      order_index,
      flat_label_nodes,
      vnode_out_heads,
      "a",
      "b",
    ),
    2,
  )
}
