// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "root neighbor projection preserves insertion order and retained parallel multiplicity" {
  let projected = project_root_neighbor_hints(
    { "a": ["b", "c", "b", "outside", "b"], "outside": ["b"] },
    ["a", "a", "a"],
    ["c", "b", "b"],
  )
  @test.assert_eq(projected["a"], ["b", "c", "b"])
  @test.assert_eq(projected["outside"], [])
}

///|
test "root replay incoming adjacency follows edge creation rather than nlist tail order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let sink = graph.node("sink")
  let edges = [graph.edge(b, sink), graph.edge(a, sink)]
  let output = build_root_reorder_inputs(
    {
      order_with_vnodes: false,
      order_rank_keys: [0, 1],
      order_groups_for_mincross: { 0: ["a", "b"], 1: ["sink"] },
      order_cluster_keys: {},
      order_cluster_skeleton: {},
      edges,
      edge_tail: ["b", "a"],
      edge_head: ["sink", "sink"],
      cluster_keys: {},
      edge_vnodes: {},
      vnodes_by_rank: {},
      vnode_order_keys_for_ordering: {},
      nlist_order: ["a", "b", "sink"],
      ranks: { "a": 0, "b": 0, "sink": 1 },
      skeleton_edge_creation: [],
      root_edge_creation: [("b", "sink"), ("a", "sink")],
      flat_rank_constraints: {},
    },
    {
      "a": [("a", "sink", 1, true, 0.0, 0.0, 0.0, 0.0)],
      "b": [("b", "sink", 1, true, 0.0, 0.0, 0.0, 0.0)],
    },
  )
  @test.assert_eq(output.root_parents["sink"], ["b", "a"])
  @test.assert_eq(output.root_children["a"], ["sink"])
}
