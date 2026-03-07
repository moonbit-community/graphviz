///|
fn fixture_edge_at(graph : @cgraph.Graph, index : Int) -> @cgraph.Edge raise {
  let edges = graph.edges()
  guard index >= 0 && index < edges.length() else {
    fail("expected edge at index \{index}")
  }
  edges[index]
}

///|
test "parse_edge_dir accepts graphviz aliases" {
  guard parse_edge_dir("forward") is Some(EdgeDir::Forward) else {
    fail("expected dir=forward")
  }
  guard parse_edge_dir("b") is Some(EdgeDir::Back) else {
    fail("expected dir=b to map to Back")
  }
  guard parse_edge_dir("both") is Some(EdgeDir::Both) else {
    fail("expected dir=both")
  }
  guard parse_edge_dir("none") is Some(EdgeDir::None) else {
    fail("expected dir=none")
  }
  guard parse_edge_dir("invalid") is None else {
    fail("expected invalid dir to return None")
  }
}

///|
test "edge_dir_for uses graph kind and defaults" {
  let directed = @dot_parser.parse_dot(
    "digraph { a -> b [dir=back]; c -> d [dir=invalid]; e -> f }",
  )
  guard edge_dir_for(fixture_edge_at(directed, 0), directed.kind()) is EdgeDir::Back else {
    fail("expected first edge to be Back")
  }
  guard edge_dir_for(fixture_edge_at(directed, 1), directed.kind()) is EdgeDir::Forward else {
    fail("expected invalid dir attr to default Forward")
  }
  guard edge_dir_for(fixture_edge_at(directed, 2), directed.kind()) is EdgeDir::Forward else {
    fail("expected missing dir attr to default Forward")
  }

  let undirected = @dot_parser.parse_dot("graph { a -- b [dir=both] }")
  guard edge_dir_for(fixture_edge_at(undirected, 0), undirected.kind()) is EdgeDir::None else {
    fail("expected undirected edges to use EdgeDir::None")
  }
}
