// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "edge_label_rank_info uses the midpoint rank for long labeled edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  let label_width = @edge_label_metrics.edge_mid_label_width_pt(edge)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  ranks["b"] = 6

  let info = match edge_label_rank_info(edge, ranks, label_width) {
    Some(value) => value
    None => fail("expected edge label rank info")
  }
  assert_eq(info.label_rank, 3)
  assert_eq(info.span, 5)
}

///|
test "edge_label_rank_info handles odd spans and ignores unlabeled one-rank-span and incomplete-rank edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let unlabeled = graph.edge(a, b)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 3
  assert_true(edge_label_rank_info(unlabeled, ranks, 0.0) is None)

  let short_edge = graph.edge(a, b)
  short_edge.set_attr("label", "mid")
  let short_info = match
    edge_label_rank_info(
      short_edge,
      ranks,
      @edge_label_metrics.edge_mid_label_width_pt(short_edge),
    ) {
    Some(value) => value
    None => fail("expected odd-span label rank info")
  }
  assert_eq(short_info.label_rank, 1)
  assert_eq(short_info.span, 3)

  let short_span_ranks : Map[String, Int] = Map::new()
  short_span_ranks["a"] = 0
  short_span_ranks["b"] = 1
  assert_eq(
    edge_label_rank_info(
      short_edge,
      short_span_ranks,
      @edge_label_metrics.edge_mid_label_width_pt(short_edge),
    )
    is None,
    true,
  )

  let incomplete_ranks : Map[String, Int] = Map::new()
  incomplete_ranks["a"] = 0
  assert_eq(
    edge_label_rank_info(
      short_edge,
      incomplete_ranks,
      @edge_label_metrics.edge_mid_label_width_pt(short_edge),
    )
    is None,
    true,
  )
}
