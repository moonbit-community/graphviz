// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "rankleader edges merge across original ports without mutating replay inputs" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("a")
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_a", 1)
  let head = graph.node(skeleton)
  let first = graph.edge(tail, head)
  let second = graph.edge(tail, head)
  first.set_attr("xpenalty", "2")
  second.set_attr("xpenalty", "3")
  for _ in 0..<2 {
    let result = collect_mincross_order_edges(
      Map([("a", true), (skeleton, true)]),
      [first, second],
      ["a", "a"],
      [skeleton, skeleton],
      [1.0, 7.0],
      [0.5, 0.5],
      [1.0, 7.0],
      [0.0, 0.0],
    )
    @test.assert_eq(result.order_edges_out_mincross.length(), 1)
    @test.assert_eq(
      @edge_semantics.edge_xpenalty(result.order_edges_out_mincross[0]),
      5,
    )
    @test.assert_eq(result.order_edge_tail_port_x_mincross, [1.0])
    @test.assert_eq(@edge_semantics.edge_xpenalty(first), 2)
    @test.assert_eq(@edge_semantics.edge_xpenalty(second), 3)
  }
}
