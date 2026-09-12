// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "live graph excludes flat edges and ignored parallel chains" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let first = graph.edge(a, b)
  let duplicate = graph.edge(a, b)
  let flat = graph.edge(a, c)
  let ranks : Map[String, Int] = { "a": 0, "b": 2, "c": 0 }
  let vnodes = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let live = build_concentrate_fast_graph(
    [first, duplicate, flat],
    ranks,
    vnodes,
    (_, _) => true,
  )
  @test.assert_eq(live.edges.length(), 2)
  @test.assert_eq(live.outgoing["a"].length(), 1)
  @test.assert_eq(live.incoming["b"].length(), 1)
  @test.assert_eq(live.incoming.get("c"), None)
  @test.assert_eq(live.edges[0].weight, 1)
  @test.assert_eq(live.edges[1].weight, 1)
}

///|
test "live graph creation follows target node order rather than edge declaration order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ac = graph.edge(a, c)
  let ab = graph.edge(a, b)
  let ranks : Map[String, Int] = { "a": 0, "b": 1, "c": 1 }
  let vnodes = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let live = build_concentrate_fast_graph([ac, ab], ranks, vnodes, (_, _) => {
    false
  })
  @test.assert_eq(live.outgoing["a"].map(index => live.edges[index].head), [
    "b", "c",
  ])
}

///|
test "live concentration transfers weight while retaining a branching leader" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let p = graph.node("p")
  let a = graph.node("a")
  let b = graph.node("b")
  let first = graph.edge(p, a)
  let second = graph.edge(p, b)
  let ranks : Map[String, Int] = { "p": 0, "a": 2, "b": 2 }
  let vnodes = build_edge_vnodes_for_test(
    graph,
    ranks,
    18.0,
    @rankdir.RankDir::TB,
  )
  let left = edge_vnode_chain_for_test(vnodes, first)[0]
  let right = edge_vnode_chain_for_test(vnodes, second)[0]
  let live = build_concentrate_fast_graph([first, second], ranks, vnodes, (_, _) => {
    false
  })
  let aliases : Map[String, String] = Map([])
  concentrate_live_candidates(
    live,
    { 0: ["p"], 1: [left, right], 2: ["a", "b"] },
    ranks,
    [first, second],
    vnodes,
    {},
    aliases,
    (_, _, _) => true,
  )
  @test.assert_eq(aliases.get(right), Some(left))
  @test.assert_eq(live.incoming[left].length(), 1)
  @test.assert_eq(live.outgoing[left].length(), 2)
  @test.assert_eq(live.edges[live.incoming["b"][0]].weight, 3)
  @test.assert_eq(live.outgoing[right].length(), 0)
}
