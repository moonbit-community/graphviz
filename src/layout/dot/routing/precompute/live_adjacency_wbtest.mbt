///|
test "copied fast edges retain immediate virtual origin cluster ownership" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.subgraph(name="cluster_a").node("a")
  let b = graph.node("b")
  let owner = graph.edge(a, b)
  let first = "_mbt_edge_vn_0_1"
  let second = "_mbt_edge_vn_0_2"
  let junction = "_mbt_edge_vn_1_2"
  let original : @setup.ConcentrateFastEdge = {
    tail: first,
    head: second,
    weight: 1,
    tail_port: None,
    head_port: None,
    to_virtual: Some(1),
    original: Some(owner),
  }
  let fast : @setup.ConcentrateFastGraph = {
    edges: [
      original,
      { ..original, head: junction, to_virtual: None, },
      { ..original, tail: second, head: "b", to_virtual: None, },
    ],
    copied_from: { 1: 0 },
    incoming: {},
    outgoing: Map([(first, [1]), (second, [2])]),
  }
  let origins = live_vnode_origin_clusters(fast, { "a": "cluster_a", "b": "" })
  @test.assert_eq(origins[first], ("", ""))
  @test.assert_eq(origins[second], ("cluster_a", ""))
}

///|
test "live routing adjacency excludes deleted segments and preserves fast-list order" {
  let deleted : @setup.ConcentrateFastEdge = {
    tail: "a",
    head: "removed",
    weight: 1,
    tail_port: None,
    head_port: None,
    to_virtual: Some(1),
    original: None,
  }
  let first = { ..deleted, head: "join", to_virtual: None, }
  let second = { ..first, tail: "b", }
  let parallel = { ..first, }
  let graph : @setup.ConcentrateFastGraph = {
    copied_from: {},
    edges: [deleted, first, second, parallel],
    outgoing: { "a": [3, 1], "b": [2], "removed": [] },
    incoming: { "join": [2, 3, 1], "removed": [] },
  }
  let adjacency = build_live_path_adjacency(graph)
  @test.assert_eq(adjacency.out_edges.get("a"), Some(["join", "join"]))
  @test.assert_eq(adjacency.in_edges.get("join"), Some(["b", "a", "a"]))
  @test.assert_eq(adjacency.in_edges.get("removed"), Some([]))
}
