// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "intercluster cycles retain soft constraints on acyclic branches" {
  // External Graphviz 14.1.1 b53 rank trace. Even an acyclic branch must
  // retain class1/interclust1's pair of weighted slack edges.
  let graph = @dot_parser.parse_dot(
    "digraph { subgraph cluster_57 { n57; n58; n50 -> n58; n48 -> n58; } subgraph cluster_43 { n43; n50; n45 -> n50; n49; n45 -> n49; n48; n45 -> n48; n45; n51; n45 -> n51; } subgraph cluster_52 { n52; n56; n54 -> n56; n53; n48 -> n53; n49 -> n53; n54; n53 -> n54; n55; n54 -> n55; } subgraph cluster_60 { n60; n61; n50 -> n61; n49 -> n61; } subgraph cluster_44 { n44; n46; } n56 -> n60; n51 -> n52; n55 -> n57; n58 -> n44; n61 -> n44; }",
  )
  let ranks = compute_ranks_directed_with_clusters(
    graph,
    graph.nodes(),
    graph.edges(),
    true,
    CL_BACK,
  )
  @test.assert_eq(ranks, {
    "n57": 2,
    "n58": 4,
    "n50": 2,
    "n48": 2,
    "n43": 0,
    "n45": 0,
    "n49": 2,
    "n51": 2,
    "n52": 4,
    "n56": 8,
    "n54": 6,
    "n53": 4,
    "n55": 8,
    "n60": 10,
    "n61": 10,
    "n44": 12,
    "n46": 12,
  })
}

///|
test "nested cluster ranks retain local offsets across reciprocal boundary edges" {
  // Graphviz 14.1.1 rank.c: rank the inner chain before class1 constructs
  // slack edges between its leader and the outer states.
  let graph = @dot_parser.parse_dot(
    "digraph { subgraph cluster_outer { init; idle; disabled; subgraph cluster_inner { a -> b -> c -> d; } fault; } init -> idle; idle -> a; idle -> disabled; disabled -> a; disabled -> idle; a -> fault; c -> idle; d -> idle; d -> idle; fault -> a; }",
  )
  let ranks = compute_ranks_directed_with_clusters(
    graph,
    graph.nodes(),
    graph.edges(),
    false,
    CL_BACK,
  )
  @test.assert_eq(ranks, {
    "init": 2,
    "idle": 3,
    "disabled": 4,
    "a": 0,
    "b": 1,
    "c": 2,
    "d": 3,
    "fault": 1,
  })
}

///|
test "build_rank_groups assigns missing ranks to zero and preserves node order within each rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")

  let ranks : Map[String, Int] = Map([])
  ranks["a"] = 2
  ranks["c"] = 2

  let groups = build_rank_groups([a, b, c], ranks)

  let zero_group = match groups.get(0) {
    Some(value) => value
    None => fail("missing zero rank group")
  }
  let two_group = match groups.get(2) {
    Some(value) => value
    None => fail("missing rank 2 group")
  }
  assert_eq(zero_group, ["b"])
  assert_eq(two_group, ["a", "c"])
}

///|
test "compute_rank_data assembles rank groups gaps and self-edge label heights" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ab = graph.edge(a, b)
  ab.set_attr("minlen", "2")
  let cc = graph.edge(c, c)
  cc.set_attr("fixture_id", "self")

  let data = compute_rank_data(
    make_rank_data_input(graph, [a, b, c], [ab, cc], false, CL_BACK, edge => {
      match edge.get_attr("fixture_id") {
        Some("self") => 12.0
        _ => 0.0
      }
    }),
  )

  let zero_group = match data.groups.get(0) {
    Some(value) => value
    None => fail("missing zero rank group")
  }
  let two_group = match data.groups.get(2) {
    Some(value) => value
    None => fail("missing rank 2 group")
  }

  assert_eq(data.edge_tail, ["a", "c"])
  assert_eq(data.edge_head, ["b", "c"])
  assert_eq(data.edge_reversed, [false, false])
  assert_eq(data.ranks.get("a"), Some(0))
  assert_eq(data.ranks.get("b"), Some(2))
  assert_eq(data.ranks.get("c"), Some(0))
  assert_eq(zero_group, ["a", "c"])
  assert_eq(two_group, ["b"])
  assert_eq(data.rank_keys, [0, 2])
  assert_eq(data.all_ranks, [0, 1, 2])
  assert_eq(data.self_edge_labels.get("c"), Some(6.0))
}

///|
test "compute_rank_data keeps a chain across sibling clusters on separate ranks" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let clusters : Array[@cgraph.Graph] = []
  let nodes : Array[@cgraph.Node] = []
  for i in 0..<6 {
    let cluster = graph.subgraph(name="cluster\{i}")
    clusters.push(cluster)
    nodes.push(cluster.node("\{i}"))
  }
  let edges : Array[@cgraph.Edge] = []
  for i in 0..<5 {
    edges.push(graph.edge(nodes[i], nodes[i + 1]))
  }

  let data = compute_rank_data(
    make_rank_data_input(graph, graph.nodes(), graph.edges(), false, CL_BACK, _ => {
      0.0
    }),
  )

  for i in 0..<6 {
    assert_eq(data.ranks.get("\{i}"), Some(i))
  }
}

///|
test "compute_rank_data keeps parsed sibling-cluster chains on separate ranks" {
  let graph = @dot_parser.parse_dot(
    "digraph { subgraph cluster0 { 0 } subgraph cluster1 { peripheries=0; 1 } subgraph cluster2 { 2 } subgraph cluster3 { peripheries=0; 3 } subgraph cluster4 { peripheries=0; 4 } subgraph cluster5 { 5 } 0 -> 1 -> 2 -> 3 -> 4; }",
  )
  let data = compute_rank_data(
    make_rank_data_input(graph, graph.nodes(), graph.edges(), false, CL_BACK, _ => {
      0.0
    }),
  )

  assert_eq(data.edge_tail, ["0", "1", "2", "3"])
  assert_eq(data.edge_head, ["1", "2", "3", "4"])
  for i in 0..<5 {
    assert_eq(data.ranks.get("\{i}"), Some(i))
  }
}
