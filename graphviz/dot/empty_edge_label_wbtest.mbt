///|
test "empty edge labels use the implicit default" {
  let graph = parse_dot("digraph { a -> b [label=\"\"]; }")
  @test.assert_eq(filter_nondefault_edge_attrs(graph, graph.edges()[0]), [])
}

///|
test "empty edge labels override a nonempty inherited default" {
  let graph = parse_dot(
    "digraph { edge [label=\"default\"]; a -> b [label=\"\"]; }",
  )
  @test.assert_eq(filter_nondefault_edge_attrs(graph, graph.edges()[0]), [
    ("label", ""),
  ])
}
