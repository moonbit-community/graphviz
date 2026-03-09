///|
test "build_dot_route_base_deps applies record border adjust only to non-html record labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let record_plain = graph.node("record_plain")
  record_plain.set_attr("shape", "record")
  record_plain.set_attr("label", "left|right")

  let record_html = graph.node("record_html")
  record_html.set_attr("shape", "record")
  record_html.set_attr("label", "<<TABLE><TR><TD>x</TD></TR></TABLE>>")

  let plain_box = graph.node("plain_box")
  plain_box.set_attr("shape", "box")
  plain_box.set_attr("label", "plain")

  let deps = build_dot_route_base_deps(
    @layout_prep.RecordOrientation::Horizontal,
    Map::new(),
    Map::new(),
  )

  assert_eq(
    (deps.record_border_adjust)(record_plain),
    @record_geometry.RECORD_BORDER_PT,
  )
  assert_eq((deps.record_border_adjust)(record_html), 0.0)
  assert_eq((deps.record_border_adjust)(plain_box), 0.0)
}

///|
test "build_dot_route_base_deps converts edge mid label metrics into routing metrics" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let labeled = graph.edge(a, b)
  labeled.set_attr("label", "mid")
  let unlabeled = graph.edge(b, a)

  let deps = build_dot_route_base_deps(
    @layout_prep.RecordOrientation::Horizontal,
    Map::new(),
    Map::new(),
  )

  match (deps.edge_mid_label_metrics)(unlabeled) {
    None => ()
    Some(_) => fail("expected unlabeled edge to have no routing metrics")
  }

  let expected = match @edge_label_metrics.edge_mid_label_metrics(labeled) {
    Some(value) => value
    None => fail("expected edge label metrics")
  }
  let actual = match (deps.edge_mid_label_metrics)(labeled) {
    Some(value) => value
    None => fail("expected routed label metrics")
  }

  assert_eq(actual.width, expected.width)
  assert_eq(actual.height, expected.height)
}
