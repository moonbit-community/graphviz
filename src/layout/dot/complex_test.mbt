test "dot layout handles complex sample" {
  let graph = @dot_parser.parse_dot_file("tests/layout/dot/complex.dot")
  let layout = layout_dot(graph)
  layout.apply()
  let nodes = graph.nodes()
  guard nodes.length() > 0 else {
    fail("expected nodes")
  }
  for node in nodes {
    guard node.get_attr("pos") is Some(_) else {
      fail("missing pos for node \{node.name()}")
    }
  }
  let edges = graph.edges()
  guard edges.length() > 0 else {
    fail("expected edges")
  }
  for edge in edges {
    guard edge.get_attr("pos") is Some(_) else {
      fail("missing pos for edge \{edge.tail().name()} -> \{edge.head().name()}")
    }
  }
  guard graph.get_attr("bb") is Some(_) else {
    fail("missing graph bb")
  }
}
