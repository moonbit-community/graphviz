// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_cluster_rank_seeded_groups applies same-rank flat constraints after traversal" {
  let local_context : ClusterLocalReorderContext = {
    cluster_node_set: { "a": true, "b": true, "c": true },
    cluster_nodes: ["a", "b", "c"],
    cluster_node_order: { "a": 0, "b": 1, "c": 2 },
    cluster_groups: { 0: ["c", "a", "b"] },
    cluster_rank_keys: [0],
    cluster_fixed_positions: Map([]),
  }

  let input_phase_output : ClusterLocalReorderRunInputsOutput = {
    cluster_edges: [],
    cluster_edge_tail: [],
    cluster_edge_head: [],
    cluster_edge_tail_port_x: [],
    cluster_edge_head_port_x: [],
    cluster_edge_tail_port_order: [],
    cluster_edge_head_port_order: [],
    parents: Map([]),
    children: Map([]),
    graphviz_out_neighbors: Map([]),
    graphviz_in_neighbors: Map([]),
    edge_order: Map([]),
    cluster_sizes: Map([]),
    cluster_keys: Map([]),
    cluster_flat_constraints: { "a|c": true, "c|b": true },
  }

  let fixed_ranks : Map[String, Int] = Map([])
  fixed_ranks["a"] = 0
  fixed_ranks["b"] = 0
  fixed_ranks["c"] = 0

  let expansion_order : Array[String] = []
  let seeded = build_cluster_rank_seeded_groups(
    local_context,
    input_phase_output,
    fixed_ranks,
    expansion_order~,
  )

  @test.assert_eq(seeded.get(0), Some(["a", "c", "b"]))
  @test.assert_eq(expansion_order, ["a", "b", "c"])
}

///|
test "cluster rank seed traverses real and long-edge virtual nodes together" {
  let short_virtual = "_mbt_edge_vn_8_3"
  let back_middle = "_mbt_edge_vn_9_2"
  let back_lower = "_mbt_edge_vn_9_3"
  let groups : Map[Int, Array[String]] = {
    1: ["a0"],
    2: ["a1", back_middle],
    3: [short_virtual, "a2", back_lower],
    4: ["a3"],
  }
  let ranks = @rank_groups.build_node_ranks(groups)
  let names = ["a0", "a1", "a2", "a3", short_virtual, back_middle, back_lower]
  let node_set : Map[String, Bool] = Map([])
  let node_order : Map[String, Int] = Map([])
  for index, name in names {
    node_set[name] = true
    node_order[name] = index
  }
  let local_context : ClusterLocalReorderContext = {
    cluster_node_set: node_set,
    cluster_nodes: names,
    cluster_node_order: node_order,
    cluster_groups: groups,
    cluster_rank_keys: [1, 2, 3, 4],
    cluster_fixed_positions: Map([]),
  }
  let inputs : ClusterLocalReorderRunInputsOutput = {
    cluster_edges: [],
    cluster_edge_tail: [
      "a0", "a0", "a1", "a1", "a2", short_virtual, back_middle, back_lower,
    ],
    cluster_edge_head: [
      "a1", back_middle, "a2", short_virtual, "a3", "a3", back_lower, "a3",
    ],
    cluster_edge_tail_port_x: [],
    cluster_edge_head_port_x: [],
    cluster_edge_tail_port_order: [],
    cluster_edge_head_port_order: [],
    parents: Map([]),
    children: Map([]),
    graphviz_out_neighbors: Map([]),
    graphviz_in_neighbors: Map([]),
    edge_order: Map([]),
    cluster_sizes: Map([]),
    cluster_keys: Map([]),
    cluster_flat_constraints: Map([]),
  }
  let seeded = build_cluster_rank_seeded_groups(local_context, inputs, ranks)
  @test.assert_eq(seeded.get(2), Some(["a1", back_middle]))
  @test.assert_eq(seeded.get(3), Some(["a2", short_virtual, back_lower]))
}
