// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "compute_ranks_directed_base merges parallel constraints and normalizes components independently" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let y = graph.node("y")

  let edge_ab_lo = graph.edge(a, b)
  edge_ab_lo.set_attr("minlen", "1")
  edge_ab_lo.set_attr("weight", "2")
  let edge_ab_hi = graph.edge(a, b, name="parallel")
  edge_ab_hi.set_attr("minlen", "3")
  edge_ab_hi.set_attr("weight", "5")
  let edge_xy = graph.edge(x, y)
  edge_xy.set_attr("minlen", "1")
  edge_xy.set_attr("weight", "1")

  let ranks = compute_ranks_directed_base(
    graph,
    [a, b, x, y],
    [edge_ab_lo, edge_ab_hi, edge_xy],
    false,
    ["a", "a", "x"],
    ["b", "b", "y"],
  )

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(3))
  assert_eq(ranks.get("x"), Some(0))
  assert_eq(ranks.get("y"), Some(1))
}

///|
test "compute_ranks_directed_base keeps rank=same nodes in one simplex component" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let y = graph.node("y")

  let same = graph.subgraph(name="same")
  same.set_attr("rank", "same")
  ignore(same.node("b"))
  ignore(same.node("x"))

  let edge_ab = graph.edge(a, b)
  edge_ab.set_attr("minlen", "1")
  let edge_xy = graph.edge(x, y)
  edge_xy.set_attr("minlen", "1")

  let ranks = compute_ranks_directed_base(
    graph,
    [a, b, x, y],
    [edge_ab, edge_xy],
    false,
    ["a", "x"],
    ["b", "y"],
  )

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(1))
  assert_eq(ranks.get("x"), Some(1))
  assert_eq(ranks.get("y"), Some(2))
}
