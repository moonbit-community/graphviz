///|
fn rank_wb_find_edge(
  graph : @cgraph.Graph,
  tail : String,
  head : String,
) -> @cgraph.Edge? {
  for edge in graph.edges() {
    if edge.tail().name() == tail && edge.head().name() == head {
      return Some(edge)
    }
  }
  None
}

///|
test "edge weight and minlen parsing clamps values" {
  let graph = @dot_parser.parse_dot(
    "digraph { a -> b [weight=2, minlen=3]; c -> d [weight=-2, minlen=0]; e -> f; }",
  )
  let edge_ab = match rank_wb_find_edge(graph, "a", "b") {
    Some(edge) => edge
    None => fail("missing edge a -> b")
  }
  let edge_cd = match rank_wb_find_edge(graph, "c", "d") {
    Some(edge) => edge
    None => fail("missing edge c -> d")
  }
  let edge_ef = match rank_wb_find_edge(graph, "e", "f") {
    Some(edge) => edge
    None => fail("missing edge e -> f")
  }
  assert_eq(@dot_shared.edge_weight(edge_ab), 2)
  assert_eq(@dot_shared.edge_minlen(edge_ab), 3)
  assert_eq(@dot_shared.edge_weight(edge_cd), 0)
  assert_eq(@dot_shared.edge_minlen(edge_cd), 1)
  assert_eq(@dot_shared.edge_weight(edge_ef), 1)
  assert_eq(@dot_shared.edge_minlen(edge_ef), 1)
}
