// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
