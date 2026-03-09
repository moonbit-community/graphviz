///|
test "build_label_edge_counts counts only labeled edges per tail" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ab1 = graph.edge(a, b)
  let ab2 = graph.edge(a, b, name="second")
  let cb = graph.edge(c, b)
  ab1.set_attr("fixture_mid_label", "1")
  cb.set_attr("fixture_mid_label", "1")

  let counts = build_label_edge_counts([ab1, ab2, cb], edge => {
    edge.get_attr("fixture_mid_label") is Some("1")
  })

  assert_eq(counts.get("a"), Some(1))
  assert_eq(counts.get("c"), Some(1))
  assert_eq(counts.length(), 2)
}
