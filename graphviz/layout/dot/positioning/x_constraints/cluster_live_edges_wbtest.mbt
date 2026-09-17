// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "cluster keepout follows only the first retained outgoing origin" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let inside = graph.node("inside")
  let outside = graph.node("outside")
  let head = graph.node("head")
  let unrelated = graph.edge(outside, head)
  let related = graph.edge(inside, head)
  let vnode = "_mbt_edge_vn_0_1"
  let live : @setup.ConcentrateFastGraph = {
    copied_from: {},
    edges: [
      {
        tail: vnode,
        head: "head",
        weight: 1,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(unrelated),
      },
      {
        tail: vnode,
        head: "head",
        weight: 1,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(related),
      },
    ],
    outgoing: Map([(vnode, [0, 1])]),
    incoming: { "head": [0, 1] },
  }
  let members = Map([("inside", true), (vnode, true)])
  @test.assert_eq(live_cluster_related_nodes(live, members).get(vnode), None)
  live.outgoing[vnode] = [1, 0]
  @test.assert_eq(
    live_cluster_related_nodes(live, members).get(vnode),
    Some(true),
  )
}

///|
test "cluster containment follows only the first retained incoming origin" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let inside = graph.node("inside")
  let outside = graph.node("outside")
  let head = graph.node("head")
  let crossing = graph.edge(outside, head)
  let internal = graph.edge(inside, head)
  let vnode = "_mbt_edge_vn_0_1"
  let live : @setup.ConcentrateFastGraph = {
    copied_from: {},
    edges: [
      {
        tail: "outside",
        head: vnode,
        weight: 1,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(crossing),
      },
      {
        tail: "inside",
        head: vnode,
        weight: 1,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(internal),
      },
    ],
    outgoing: { "outside": [0], "inside": [1] },
    incoming: Map([(vnode, [0, 1])]),
  }
  let members = Map([("inside", true), ("head", true), (vnode, true)])
  @test.assert_eq(
    live_cluster_right_boundary_member(live, vnode, members),
    false,
  )
  live.incoming[vnode] = [1, 0]
  @test.assert_eq(
    live_cluster_right_boundary_member(live, vnode, members),
    true,
  )
  let ranks = Map([("inside", 0), ("head", 2), (vnode, 1)])
  @test.assert_eq(
    live_cluster_left_boundary_members(live, [internal], ranks, members).get(
      vnode,
    ),
    Some(true),
  )
  @test.assert_eq(
    live_cluster_left_boundary_members(live, [crossing], ranks, members).get(
      vnode,
    ),
    None,
  )
}

///|
test "flat parallel constraints accumulate weight before X construction" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let first = graph.edge(a, b)
  let second = graph.edge(a, b)
  second.set_attr("weight", "3")
  let output = build_constraint_segment_pass({
    edges: [first, second],
    edge_tail: ["a", "a"],
    edge_head: ["b", "b"],
    edge_out_order: { "a": [0, 1] },
    nlist_order: ["a", "b"],
    ranks: { "a": 0, "b": 0 },
    cluster_keys: {},
    edge_vnodes: {},
    order_in_rank: { "a": 0, "b": 1 },
    nodesep_pt: 18.0,
    sizes: {},
    skip_intercluster: false,
    rank_adj_constraints: {},
    edge_has_mid_label: _ => false,
    edge_degree_increment: _ => 1,
  })
  @test.assert_eq(output.flat_minlen_constraints["a|b"].weight, 4)
}

///|
test "X segments retain transferred weights and live adjacency order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let a = graph.node("a")
  let b = graph.node("b")
  let original = graph.edge(a, b)
  let live : @setup.ConcentrateFastGraph = {
    copied_from: {},
    edges: [
      {
        tail: "a",
        head: "b",
        weight: 19,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(original),
      },
      {
        tail: "a",
        head: "b",
        weight: 4,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(original),
      },
    ],
    outgoing: { "a": [1, 0] },
    incoming: { "b": [0, 1] },
  }
  let output = build_constraint_segment_pass(
    {
      edges: [original],
      edge_tail: ["a"],
      edge_head: ["b"],
      edge_out_order: { "a": [0] },
      nlist_order: ["a", "b"],
      ranks: { "a": 0, "b": 1 },
      cluster_keys: {},
      edge_vnodes: {},
      order_in_rank: { "a": 0, "b": 0 },
      nodesep_pt: 18.0,
      sizes: {},
      skip_intercluster: false,
      rank_adj_constraints: {},
      edge_has_mid_label: _ => false,
      edge_degree_increment: _ => 1,
    },
    live_graph=Some(live),
  )
  @test.assert_eq(output.segments_by_tail["a"].map(edge => edge.weight), [4, 19])
}
