///|
test "adjacent flat edges with a record endpoint have no spline" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  let base = build_route_base(edge)
  let adjacent = { ..base, is_flat_adjacent: true, }
  @test.assert_eq(unsupported_record_flat_edge(adjacent), false)
  a.set_attr("shape", "record")
  @test.assert_eq(unsupported_record_flat_edge(adjacent), true)
  @test.assert_eq(unsupported_record_flat_edge(base), false)
  a.set_attr("shape", "box")
  b.set_attr("shape", "Mrecord")
  @test.assert_eq(unsupported_record_flat_edge(adjacent), true)
}
