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

///|
test "acyclic_edge_directions_for_names reverses the back edge of a cycle" {
  let directions = acyclic_edge_directions_for_names(
    ["a", "b", "c"],
    ["a", "b", "c", "b"],
    ["b", "c", "a", "b"],
    [true, true, true, true],
  )

  assert_eq(directions.tail, ["a", "b", "a", "b"])
  assert_eq(directions.head, ["b", "c", "c", "b"])
  assert_eq(directions.reversed, [false, false, true, false])
}

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
