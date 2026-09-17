// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "concentrated opposite does not add weight or a second ordering edge" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let low = graph.node("low")
  let high = graph.node("high")
  let forward = graph.edge(low, high)
  let backward = graph.edge(high, low)
  let metadata = build_reverse_merge_metadata({
    edges: [forward, backward],
    edge_tail: ["low", "low"],
    edge_head: ["high", "high"],
    edge_excluded_from_reverse_merge: _ => false,
    edge_ports_equal: (_, _) => true,
  })
  @test.assert_eq(metadata.merged_edge_skip.get(1), Some(true))
  @test.assert_eq(
    metadata.merged_edge_weight_bonus.get(0).unwrap_or_default(),
    0,
  )
  let output = build_order_edges_by_tail(
    ["low"],
    [forward, backward],
    ["low", "low"],
    ["high", "high"],
    [0.0, 0.0],
    [0.0, 0.0],
    [0.0, 0.0],
    [0.0, 0.0],
    { "low": 0, "high": 1 },
    {},
    true,
    {},
    false,
    false,
    false,
    { "low": [0, 1] },
  )
  @test.assert_eq(output.edge_creation_order, [("low", "high")])
  @test.assert_eq(output.order_edges_by_tail["low"].length(), 1)
  @test.assert_eq(output.order_edges_by_tail["low"][0].2, 1)
}

///|
test "concentrated backward duplicates do not duplicate root virtual chains" {
  for cluster in ["", "cluster_local"] {
    let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
    graph.set_attr("concentrate", "true")
    let low = graph.node("low")
    let high = graph.node("high")
    let first = graph.edge(high, low)
    let duplicate = graph.edge(high, low)
    let output = build_order_edges_by_tail(
      ["low"],
      [first, duplicate],
      ["low", "low"],
      ["high", "high"],
      [0.0, 0.0],
      [0.0, 0.0],
      [0.0, 0.0],
      [0.0, 0.0],
      { "low": 0, "high": 2 },
      Map([(@edge_identity.edge_vnode_key(first), ["v"])]),
      true,
      { "low": cluster, "high": cluster },
      true,
      false,
      false,
      { "low": [0, 1] },
    )
    @test.assert_eq(output.edge_creation_order, [("low", "v"), ("v", "high")])
    @test.assert_eq(output.order_edges_by_tail["low"][0].2, 1)
  }
}
