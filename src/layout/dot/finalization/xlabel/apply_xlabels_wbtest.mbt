///|
test "apply_xlabels preserves existing xlabels and expands bbox for node and edge labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  a.set_attr("xlabel", "node-out")
  let edge = graph.edge(a, b)
  edge.set_attr("xlabel", "edge-out")

  let node_xlabel = @edge_spline.point(20.0, 30.0)
  let edge_xlabel = @edge_spline.point(-10.0, 8.0)
  let layout = xlabel_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    nodes=[
      xlabel_make_node_layout(
        a,
        @edge_spline.point(5.0, 5.0),
        1.0,
        0.5,
        xlabel_pos=Some(node_xlabel),
      ),
    ],
    edges=[
      xlabel_make_edge_layout(
        edge,
        straight_spline(),
        xlabel_pos=Some(edge_xlabel),
      ),
    ],
  )

  let updated = apply_xlabels(layout, @layout_prep.SplinesMode::Spline)
  let node_metrics = match xlabel_metrics_for_node(a) {
    Some(value) => value
    None => fail("expected node xlabel metrics")
  }
  let edge_metrics = match xlabel_metrics_for_edge(edge) {
    Some(value) => value
    None => fail("expected edge xlabel metrics")
  }
  let expected_bbox = @edge_label.expand_bbox_for_label_pos(
    @edge_label.expand_bbox_for_label_pos(
      layout.bbox,
      Some(node_xlabel),
      Some({ width: node_metrics.width, height: node_metrics.height }),
    ),
    Some(edge_xlabel),
    Some({ width: edge_metrics.width, height: edge_metrics.height }),
  )

  assert_eq(updated.nodes[0].xlabel_pos, Some(node_xlabel))
  assert_eq(updated.edges[0].xlabel_pos, Some(edge_xlabel))
  assert_eq(updated.bbox, expected_bbox)
}

///|
test "apply_xlabels places unresolved node xlabels and expands bbox" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  node.set_attr("xlabel", "outside")

  let layout = xlabel_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 80.0, ury: 80.0 },
    nodes=[
      xlabel_make_node_layout(node, @edge_spline.point(50.0, 60.0), 1.0, 0.5),
    ],
  )

  let updated = apply_xlabels(layout, @layout_prep.SplinesMode::Spline)
  let metrics = match xlabel_metrics_for_node(node) {
    Some(value) => value
    None => fail("expected node xlabel metrics")
  }
  let expected_pos = @edge_spline.point(
    14.0 - metrics.width / 2.0,
    78.0 + metrics.height / 2.0,
  )
  let expected_bbox = @edge_label.expand_bbox_for_label_pos(
    layout.bbox,
    Some(expected_pos),
    Some({ width: metrics.width, height: metrics.height }),
  )

  assert_eq(updated.nodes[0].xlabel_pos, Some(expected_pos))
  assert_eq(updated.bbox, expected_bbox)
}

///|
test "apply_xlabels writes unresolved edge xlabels back through the edge update map" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("xlabel", "edge-out")

  let layout = xlabel_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 20.0, ury: 20.0 },
    nodes=[
      xlabel_make_node_layout(a, @edge_spline.point(100.0, 100.0), 0.25, 0.25),
      xlabel_make_node_layout(b, @edge_spline.point(120.0, 100.0), 0.25, 0.25),
    ],
    edges=[xlabel_make_edge_layout(edge, straight_spline())],
  )

  let updated = apply_xlabels(layout, @layout_prep.SplinesMode::Spline)
  let metrics = match xlabel_metrics_for_edge(edge) {
    Some(value) => value
    None => fail("expected edge xlabel metrics")
  }
  let expected_pos = @edge_spline.point(
    4.5 - metrics.width / 2.0,
    metrics.height / 2.0,
  )

  assert_eq(updated.edges[0].xlabel_pos, Some(expected_pos))
  assert_eq(updated.edges[0].label_pos, None)
  assert_eq(updated.edges[0].head_label_pos, None)
  assert_eq(updated.edges[0].tail_label_pos, None)
}
