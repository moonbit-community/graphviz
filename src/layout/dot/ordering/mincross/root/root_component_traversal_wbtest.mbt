// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_component_traversal_starts sorts by root order and prefers real nodes over edge vnodes" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"

  let starts = build_component_traversal_starts([vnode, "b", "a"], {
    "a": 2,
    "b": 1,
  })

  assert_eq(starts.start_nodes, [vnode, "b", "a"])
  assert_eq(starts.traversal_starts, ["b", "a"])
}

///|
test "build_flat_constraint_adjacency keeps only enabled parseable links inside the active node set" {
  let node_set = build_node_membership_set(["a", "b"])
  let adjacency = build_flat_constraint_adjacency(["a", "b", "c"], node_set, {
    "a|b": true,
    "b|c": true,
    "a|": true,
    "no_delimiter": true,
    "b|a": false,
  })

  assert_eq(adjacency.flat_out.get("a"), Some(["b"]))
  assert_eq(adjacency.flat_out.get("b"), Some([]))
  assert_eq(adjacency.flat_out.get("c"), Some([]))
  assert_eq(adjacency.flat_in.get("a"), Some([]))
  assert_eq(adjacency.flat_in.get("b"), Some(["a"]))
  assert_eq(adjacency.flat_in.get("c"), Some([]))
}

///|
test "collect_components_from_traversal replays preferred starts first and then remaining starts" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let order_nodes = [vnode, "a", "b", "c", "d"]
  let node_set = build_node_membership_set(order_nodes)
  let out_neighbors : Map[String, Array[String]] = Map::new()
  out_neighbors[vnode] = []
  out_neighbors["a"] = [vnode]
  out_neighbors["b"] = []
  out_neighbors["c"] = ["d"]
  out_neighbors["d"] = []

  let in_neighbors : Map[String, Array[String]] = Map::new()
  in_neighbors[vnode] = ["a"]
  in_neighbors["a"] = []
  in_neighbors["b"] = []
  in_neighbors["c"] = []
  in_neighbors["d"] = ["c"]

  let flat_out : Map[String, Array[String]] = Map::new()
  flat_out[vnode] = []
  flat_out["a"] = []
  flat_out["b"] = []
  flat_out["c"] = []
  flat_out["d"] = []

  let flat_in : Map[String, Array[String]] = Map::new()
  flat_in[vnode] = []
  flat_in["a"] = []
  flat_in["b"] = []
  flat_in["c"] = []
  flat_in["d"] = []

  let adjacency : ComponentTraversalAdjacency = {
    out_neighbors,
    in_neighbors,
    flat_out,
    flat_in,
  }
  let starts : ComponentTraversalStarts = {
    start_nodes: order_nodes,
    traversal_starts: ["a", "c"],
  }

  let components = collect_components_from_traversal(
    order_nodes, node_set, starts, adjacency,
  )

  assert_eq(components, [["a", vnode], ["c", "d"], ["b"]])
}
