///|
test "compute_ranks_directed uses supplied edge orientation when the graph has no clusters" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("minlen", "1")

  let ranks = compute_ranks_directed(
    graph,
    [a, b],
    [edge],
    false,
    ["b"],
    ["a"],
    CL_BACK,
  )

  assert_eq(ranks.get("a"), Some(1))
  assert_eq(ranks.get("b"), Some(0))
}

///|
test "compute_ranks_directed ignores supplied orientation and takes the clustered branch when clusters exist" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster0")
  let a = graph.node("a")
  let b = graph.node("b")
  ignore(cluster.node("a"))
  let edge = graph.edge(a, b)
  edge.set_attr("minlen", "1")

  let ranks = compute_ranks_directed(
    graph,
    [a, b],
    [edge],
    false,
    ["b"],
    ["a"],
    CL_BACK,
  )

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(1))
}
