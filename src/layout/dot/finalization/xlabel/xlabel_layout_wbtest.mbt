///|
fn xlabel_make_layout_tree(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  nodes? : Array[DotLayoutNode] = [],
  edges? : Array[DotLayoutEdge] = [],
  subgraphs? : Array[@layout_tree.LayoutTree] = [],
) -> @layout_tree.LayoutTree {
  { graph, bbox, label_pos: None, nodes, edges, subgraphs }
}

///|
fn make_set_xlabel(
  target : XLabelTarget,
  width : Double,
  height : Double,
  pos : @geom.Point,
) -> XLabel {
  { target, width, height, pos, set: true }
}

///|
test "finalize_xlabels writes update maps into root and subgraph layouts and expands bbox" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  a.set_attr("xlabel", "root-node-out")
  let edge = graph.edge(a, b)
  edge.set_attr("xlabel", "root-edge-out")
  edge.set_attr("label", "mid")
  edge.set_attr("taillabel", "tail")
  edge.set_attr("headlabel", "head")

  let cluster = graph.subgraph(name="cluster_0")
  let c = cluster.node("c")
  let d = cluster.node("d")
  let cluster_edge = cluster.edge(c, d)

  let existing_node_xlabel = @edge_spline.point(5.0, 20.0)
  let existing_edge_xlabel = @edge_spline.point(9.0, 15.0)
  let layout = xlabel_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    nodes=[
      xlabel_make_node_layout(
        a,
        @edge_spline.point(0.0, 0.0),
        1.0,
        0.5,
        xlabel_pos=Some(existing_node_xlabel),
      ),
      xlabel_make_node_layout(b, @edge_spline.point(10.0, 0.0), 1.0, 0.5),
    ],
    edges=[
      xlabel_make_edge_layout(
        edge,
        straight_spline(),
        label_pos=Some(@edge_spline.point(2.0, 2.0)),
        head_label_pos=Some(@edge_spline.point(3.0, 3.0)),
        tail_label_pos=Some(@edge_spline.point(4.0, 4.0)),
        xlabel_pos=Some(existing_edge_xlabel),
      ),
    ],
    subgraphs=[
      xlabel_make_layout_tree(
        cluster,
        { llx: 1.0, lly: 1.0, urx: 2.0, ury: 2.0 },
        nodes=[
          xlabel_make_node_layout(c, @edge_spline.point(20.0, 0.0), 1.0, 0.5),
        ],
        edges=[xlabel_make_edge_layout(cluster_edge, straight_spline())],
      ),
    ],
  )

  let edge_key = @edge_identity.edge_key(edge)
  let cluster_edge_key = @edge_identity.edge_key(cluster_edge)
  let labels : Array[XLabel] = [
    make_set_xlabel(
      XLabelTarget::Node("b"),
      20.0,
      8.0,
      @edge_spline.point(18.0, 28.0),
    ),
    make_set_xlabel(
      XLabelTarget::EdgeMid(edge_key),
      12.0,
      6.0,
      @edge_spline.point(30.0, 40.0),
    ),
    make_set_xlabel(
      XLabelTarget::EdgeHead(edge_key),
      10.0,
      4.0,
      @edge_spline.point(50.0, 60.0),
    ),
    make_set_xlabel(
      XLabelTarget::EdgeTail(edge_key),
      14.0,
      6.0,
      @edge_spline.point(-20.0, 2.0),
    ),
    make_set_xlabel(
      XLabelTarget::EdgeXlabel(edge_key),
      16.0,
      6.0,
      @edge_spline.point(12.0, -12.0),
    ),
    make_set_xlabel(
      XLabelTarget::Node("c"),
      10.0,
      10.0,
      @edge_spline.point(80.0, 90.0),
    ),
    make_set_xlabel(
      XLabelTarget::EdgeMid(cluster_edge_key),
      6.0,
      6.0,
      @edge_spline.point(100.0, 105.0),
    ),
    {
      target: XLabelTarget::Node("ignored"),
      width: 7.0,
      height: 7.0,
      pos: @edge_spline.point(300.0, 300.0),
      set: false,
    },
  ]

  let updated = finalize_xlabels(layout, labels, false)
  let node_metrics = match xlabel_metrics_for_node(a) {
    Some(value) => value
    None => fail("expected node xlabel metrics")
  }
  let edge_metrics = match xlabel_metrics_for_edge(edge) {
    Some(value) => value
    None => fail("expected edge xlabel metrics")
  }

  let mut expected_bbox = @edge_label.expand_bbox_for_label_pos(
    @edge_label.expand_bbox_for_label_pos(
      layout.bbox,
      Some(existing_node_xlabel),
      Some({ width: node_metrics.width, height: node_metrics.height }),
    ),
    Some(existing_edge_xlabel),
    Some({ width: edge_metrics.width, height: edge_metrics.height }),
  )
  for label in labels {
    if !label.set {
      continue
    }
    expected_bbox = @edge_label.expand_bbox_for_label_pos(
      expected_bbox,
      Some(xlabel_center(label)),
      Some({ width: label.width, height: label.height }),
    )
  }

  assert_eq(updated.bbox, expected_bbox)
  assert_eq(updated.nodes[0].xlabel_pos, Some(existing_node_xlabel))
  assert_eq(updated.nodes[1].xlabel_pos, Some(@edge_spline.point(28.0, 32.0)))
  assert_eq(updated.edges[0].label_pos, Some(@edge_spline.point(36.0, 43.0)))
  assert_eq(
    updated.edges[0].head_label_pos,
    Some(@edge_spline.point(55.0, 62.0)),
  )
  assert_eq(
    updated.edges[0].tail_label_pos,
    Some(@edge_spline.point(-13.0, 5.0)),
  )
  assert_eq(updated.edges[0].xlabel_pos, Some(@edge_spline.point(20.0, -9.0)))
  assert_eq(
    updated.subgraphs[0].nodes[0].xlabel_pos,
    Some(@edge_spline.point(85.0, 95.0)),
  )
  assert_eq(
    updated.subgraphs[0].edges[0].label_pos,
    Some(@edge_spline.point(103.0, 108.0)),
  )
}

///|
test "finalize_xlabels flips existing xlabel metrics when expanding bbox" {
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

  let updated = finalize_xlabels(layout, [], true)
  let node_metrics = match xlabel_metrics_for_node(a) {
    Some(value) => value
    None => fail("expected node xlabel metrics")
  }
  let edge_metrics = match xlabel_metrics_for_edge(edge) {
    Some(value) => value
    None => fail("expected edge xlabel metrics")
  }
  let node_dims = maybe_flip_dims(node_metrics.width, node_metrics.height, true)
  let edge_dims = maybe_flip_dims(edge_metrics.width, edge_metrics.height, true)
  let expected_bbox = @edge_label.expand_bbox_for_label_pos(
    @edge_label.expand_bbox_for_label_pos(
      layout.bbox,
      Some(node_xlabel),
      Some({ width: node_dims.width, height: node_dims.height }),
    ),
    Some(edge_xlabel),
    Some({ width: edge_dims.width, height: edge_dims.height }),
  )

  assert_eq(updated.bbox, expected_bbox)
}

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
