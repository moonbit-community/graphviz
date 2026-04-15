// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "select_vnode_anchor_neighbor prefers the first rank-crossing neighbor and otherwise falls back to the first incident neighbor or empty" {
  let ranks : Map[String, Int] = Map::new()
  ranks["same"] = 1
  ranks["same2"] = 1
  ranks["low"] = 0
  ranks["high"] = 2

  assert_eq(
    select_vnode_anchor_neighbor(["same", "low", "high"], ranks, 1, true),
    "low",
  )
  assert_eq(
    select_vnode_anchor_neighbor(["same", "high"], ranks, 1, false),
    "high",
  )
  assert_eq(
    select_vnode_anchor_neighbor(["same", "peer"], ranks, 1, true),
    "peer",
  )
  assert_eq(
    select_vnode_anchor_neighbor(["same", "same2"], ranks, 1, true),
    "same",
  )
  assert_eq(select_vnode_anchor_neighbor([], ranks, 1, false), "")
}

///|
test "compute_vnode_interpolation_key interpolates between anchor orders and falls back when anchors are missing" {
  let vnode_between = "\{@edge_identity.EDGE_VNODE_PREFIX}between"
  let vnode_same = "\{@edge_identity.EDGE_VNODE_PREFIX}same"
  let vnode_missing = "\{@edge_identity.EDGE_VNODE_PREFIX}missing"

  let order_index : Map[String, Int] = Map::new()
  order_index["left"] = 0
  order_index["right"] = 3
  order_index["same_top"] = 1
  order_index["same_bottom"] = 1

  let ranks : Map[String, Int] = Map::new()
  ranks["left"] = 0
  ranks["right"] = 2
  ranks[vnode_between] = 1
  ranks["same_top"] = 0
  ranks["same_bottom"] = 2
  ranks[vnode_same] = 1
  ranks[vnode_missing] = 1

  let parents : Map[String, Array[String]] = Map::new()
  parents[vnode_between] = ["left"]
  parents[vnode_same] = ["same_top"]
  parents[vnode_missing] = ["left"]

  let children : Map[String, Array[String]] = Map::new()
  children[vnode_between] = ["right"]
  children[vnode_same] = ["same_bottom"]

  assert_eq(
    compute_vnode_interpolation_key(
      "real", 1, 7, order_index, ranks, parents, children,
    ),
    7.0,
  )
  assert_eq(
    compute_vnode_interpolation_key(
      vnode_between, 1, 9, order_index, ranks, parents, children,
    ),
    1.5,
  )
  assert_eq(
    compute_vnode_interpolation_key(
      vnode_same, 1, 9, order_index, ranks, parents, children,
    ),
    0.5,
  )
  assert_eq(
    compute_vnode_interpolation_key(
      vnode_missing, 1, 4, order_index, ranks, parents, children,
    ),
    4.0,
  )
}

///|
test "seed_local_groups_by_vnode reorders rank members by interpolated vnode position while preserving trivial ranks" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"

  let cluster_groups : Map[Int, Array[String]] = Map::new()
  cluster_groups[0] = ["left", "right"]
  cluster_groups[1] = ["real0", "real1", vnode]
  cluster_groups[2] = ["far0", "far1"]
  cluster_groups[3] = ["single"]

  let ranks : Map[String, Int] = Map::new()
  ranks["left"] = 0
  ranks["right"] = 0
  ranks["real0"] = 1
  ranks["real1"] = 1
  ranks[vnode] = 1
  ranks["far0"] = 2
  ranks["far1"] = 2
  ranks["single"] = 3

  let parents : Map[String, Array[String]] = Map::new()
  parents[vnode] = ["left"]

  let children : Map[String, Array[String]] = Map::new()
  children[vnode] = ["far1"]

  let seeded = seed_local_groups_by_vnode(
    [0, 1, 2, 3],
    cluster_groups,
    ranks,
    parents,
    children,
  )

  assert_eq(seeded.get(0), Some(["left", "right"]))
  assert_eq(seeded.get(1), Some(["real0", vnode, "real1"]))
  assert_eq(seeded.get(2), Some(["far0", "far1"]))
  assert_eq(seeded.get(3), Some(["single"]))
}

///|
test "build_cluster_rank_seeded_groups applies same-rank flat constraints after vnode seeding" {
  let local_context : ClusterLocalReorderContext = {
    cluster_node_set: { "a": true, "b": true, "c": true },
    cluster_nodes: ["a", "b", "c"],
    cluster_node_order: { "a": 0, "b": 1, "c": 2 },
    cluster_groups: { 0: ["c", "a", "b"] },
    cluster_rank_keys: [0],
    cluster_fixed_positions: Map::new(),
  }

  let input_phase_output : ClusterLocalReorderRunInputsOutput = {
    cluster_edges: [],
    cluster_edge_tail: [],
    cluster_edge_head: [],
    cluster_edge_tail_port_x: [],
    cluster_edge_head_port_x: [],
    cluster_edge_tail_port_order: [],
    cluster_edge_head_port_order: [],
    parents: Map::new(),
    children: Map::new(),
    graphviz_out_neighbors: Map::new(),
    graphviz_in_neighbors: Map::new(),
    edge_order: Map::new(),
    cluster_sizes: Map::new(),
    cluster_keys: Map::new(),
    cluster_flat_constraints: { "a|c": true, "c|b": true },
  }

  let fixed_ranks : Map[String, Int] = Map::new()
  fixed_ranks["a"] = 0
  fixed_ranks["b"] = 0
  fixed_ranks["c"] = 0

  let seeded = build_cluster_rank_seeded_groups(
    local_context, input_phase_output, fixed_ranks,
  )

  assert_eq(seeded.get(0), Some(["a", "c", "b"]))
}
