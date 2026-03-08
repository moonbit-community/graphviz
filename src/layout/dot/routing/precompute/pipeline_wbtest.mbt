///|
test "build_head_port_metrics accumulates count and distance envelope per key" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let e1 = graph.edge(a, b)
  let e2 = graph.edge(c, b)
  let ignored = graph.edge(a, c)

  let metrics = build_head_port_metrics([e1, e2, ignored], true, edge => {
    if edge.id() == e1.id() {
      Some(("b:p", 8.0))
    } else if edge.id() == e2.id() {
      Some(("b:p", 3.0))
    } else {
      None
    }
  })

  assert_eq(metrics.head_port_counts.get("b:p"), Some(2))
  assert_eq(metrics.head_port_min_dist.get("b:p"), Some(3.0))
  assert_eq(metrics.head_port_max_dist.get("b:p"), Some(8.0))
}

///|
test "build_head_port_metrics stays empty when complex tuning is disabled" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  let metrics = build_head_port_metrics([edge], false, _edge => {
    Some(("b:p", 5.0))
  })

  assert_eq(metrics.head_port_counts.length(), 0)
  assert_eq(metrics.head_port_min_dist.length(), 0)
  assert_eq(metrics.head_port_max_dist.length(), 0)
}
