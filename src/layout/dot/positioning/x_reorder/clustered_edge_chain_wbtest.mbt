// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_xpos_chain_with_vnodes respects rank direction" {
  let forward_ranks : Map[String, Int] = { "tail": 0, "head": 3 }
  let reverse_ranks : Map[String, Int] = { "tail": 3, "head": 0 }

  assert_eq(
    build_xpos_chain_with_vnodes(forward_ranks, "tail", "head", ["v1", "v2"]),
    ["tail", "v1", "v2", "head"],
  )
  assert_eq(
    build_xpos_chain_with_vnodes(reverse_ranks, "tail", "head", ["v1", "v2"]),
    ["tail", "v2", "v1", "head"],
  )
}

///|
test "append_xpos_edge_with_vnodes keeps endpoint port hints on outer segments only" {
  let (graph, order_node_map) = new_test_graph(["a", "v1", "v2", "b"])
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  let ranks : Map[String, Int] = { "a": 0, "v1": 1, "v2": 2, "b": 3 }

  append_xpos_edge_with_vnodes(
    graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    ranks,
    "a",
    "b",
    7,
    true,
    1.0,
    3.0,
    0.2,
    0.8,
    ["v1", "v2"],
  )

  assert_eq(order_edge_tail_out, ["a", "v1", "v2"])
  assert_eq(order_edge_head_out, ["v1", "v2", "b"])
  assert_eq(order_edge_tail_port_x, [1.0, 0.0, 0.0])
  assert_eq(order_edge_head_port_x, [0.0, 0.0, 3.0])
  assert_eq(order_edge_tail_port_order, [0.2, 0.5, 0.5])
  assert_eq(order_edge_head_port_order, [0.5, 0.5, 0.8])
  assert_eq(order_edges_out.length(), 3)
}
