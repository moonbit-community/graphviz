// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "adjacent flat labels tighten one horizontal edge without slack nodes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let first = graph.edge(a, b)
  let second = graph.edge(a, b)
  first.set_attr("label", "short")
  second.set_attr("label", "longer")
  let build = build_constraint_graph({
    nodes: [a, b],
    edges: [first, second],
    edge_tail: [],
    edge_head: [],
    edge_out_order: { "a": [0, 1] },
    nlist_order: ["a", "b"],
    ranks: { "a": 0, "b": 0 },
    rank_keys: [0],
    groups: { 0: ["a", "b"] },
    sizes: build_constraint_builder_test_sizes(),
    cluster_keys: Map([]),
    nodesep_pt: 10.0,
    has_edge_labels: true,
    extra_nodes: [],
    extra_edges: [
      {
        tail: "a",
        head: "b",
        minlen: 50,
        weight: 1,
        tail_port: None,
        head_port: None,
      },
      {
        tail: "a",
        head: "b",
        minlen: 70,
        weight: 1,
        tail_port: None,
        head_port: None,
      },
    ],
    edge_vnodes: Map([]),
    root_ln_targets: [],
    root_rn_targets: [],
    compress_width_minlen: None,
    segment_minlen: (_, _) => (0, 0),
    edge_has_mid_label: _ => true,
    edge_degree_increment: _ => 1,
    root_margin: 8.0,
    root_compress_weight: 1000,
  })
  @test.assert_eq(build.graph.nodes.length(), 2)
  @test.assert_eq(build.graph.edges.length(), 1)
  @test.assert_eq(build.graph.edges[0].minlen, 70)
  @test.assert_eq(build.graph.edges[0].weight, 2)
}

///|
test "cluster endpoints retain ordinary chain weights while free singleton endpoints amplify" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  let degrees = build_node_degrees([edge], _ => 1, { "a": "cluster_a" })
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}weight_1"
  @test.assert_eq(scaled_segment_edge_weight(3, "a", vnode, degrees), 3)
  @test.assert_eq(scaled_segment_edge_weight(3, "b", vnode, degrees), 6)
}
