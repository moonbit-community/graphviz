// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "apply_clustered_rank_postprocessing collapses rank sets and enforces extrema" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let d = graph.node("d")

  let same = graph.subgraph(name="same")
  same.set_attr("rank", "same")
  ignore(same.node("a"))
  ignore(same.node("b"))

  let source = graph.subgraph(name="source")
  source.set_attr("rank", "source")
  ignore(source.node("c"))

  let sink = graph.subgraph(name="sink")
  sink.set_attr("rank", "sink")
  ignore(sink.node("d"))

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 4
  ranks["b"] = 7
  ranks["c"] = 3
  ranks["d"] = 1

  let result = apply_clustered_rank_postprocessing(graph, [a, b, c, d], ranks)

  assert_eq(result.get("a"), Some(4))
  assert_eq(result.get("b"), Some(4))
  assert_eq(result.get("c"), Some(0))
  assert_eq(result.get("d"), Some(4))
}
