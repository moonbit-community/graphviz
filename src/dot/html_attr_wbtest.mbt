///|
test "DOT roundtrip keeps HTML distinct from identical quoted text" {
  let graph = parse_dot("digraph { a [label=<hello>]; b [label=\"<hello>\"]; }")
  let rewritten = parse_dot(write_dot(graph))
  @test.assert_eq(
    rewritten.node("a").get_attr_value("label"),
    Some(@cgraph.AttrValue::Html("<hello>")),
  )
  @test.assert_eq(
    rewritten.node("b").get_attr_value("label"),
    Some(@cgraph.AttrValue::Text("<hello>")),
  )
}

///|
test "HTML default overrides retain syntax even when text is equal" {
  let graph = parse_dot(
    "digraph { node [label=<hello>]; a; b [label=\"<hello>\"]; }",
  )
  let rewritten = parse_dot(write_dot(graph))
  @test.assert_eq(
    rewritten.node("a").get_attr_value("label"),
    Some(@cgraph.AttrValue::Html("<hello>")),
  )
  @test.assert_eq(
    rewritten.node("b").get_attr_value("label"),
    Some(@cgraph.AttrValue::Text("<hello>")),
  )
}

///|
test "HTML graph and edge defaults survive inheritance and later changes" {
  let graph = parse_dot(
    "digraph { label=<old>; edge [label=<old>]; subgraph cluster_a { a -> b; } label=\"new\"; edge [label=\"new\"]; b -> c; }",
  )
  let rewritten = parse_dot(write_dot(graph))
  @test.assert_eq(
    rewritten.subgraphs()[0].get_attr_value("label"),
    Some(@cgraph.AttrValue::Html("<old>")),
  )
  @test.assert_eq(
    rewritten.edges()[0].get_attr_value("label"),
    Some(@cgraph.AttrValue::Html("<old>")),
  )
  @test.assert_eq(
    rewritten.edges()[1].get_attr_value("label"),
    Some(@cgraph.AttrValue::Text("new")),
  )
}
