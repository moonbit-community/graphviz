// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "collect_rank_extremes descends nested subgraphs" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  ignore(graph.node("a"))
  ignore(graph.node("b"))
  ignore(graph.node("c"))
  let nested = graph.subgraph(name="nested")
  let source = nested.subgraph(name="source")
  source.set_attr("rank", "source")
  ignore(source.node("a"))
  let sink = graph.subgraph(name="sink")
  sink.set_attr("rank", "sink")
  ignore(sink.node("b"))

  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  collect_rank_extremes(graph, min_nodes, max_nodes)

  assert_eq(min_nodes.get("a"), Some(true))
  assert_eq(max_nodes.get("b"), Some(true))
  assert_eq(min_nodes.get("c"), None)
  assert_eq(max_nodes.get("c"), None)
}
