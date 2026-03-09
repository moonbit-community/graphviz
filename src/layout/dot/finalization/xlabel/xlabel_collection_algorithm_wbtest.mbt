///|
fn xlabel_make_node_layout(
  node : @cgraph.Node,
  pos : @geom.Point,
  width_in : Double,
  height_in : Double,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutNode {
  { node, pos, width_in, height_in, label_pos: None, xlabel_pos }
}

///|
fn xlabel_make_edge_layout(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  label_pos? : @geom.Point? = None,
  head_label_pos? : @geom.Point? = None,
  tail_label_pos? : @geom.Point? = None,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutEdge {
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
fn straight_spline() -> @geom.Spline {
  {
    start: None,
    end: None,
    points: [
      @edge_spline.point(0.0, 0.0),
      @edge_spline.point(3.0, 0.0),
      @edge_spline.point(6.0, 0.0),
      @edge_spline.point(9.0, 0.0),
    ],
  }
}

///|
test "build_node_obstacle_with_xlabel_slot creates a deferred slot for unresolved node xlabels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  node.set_attr("xlabel", "outside")

  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  let obstacle = build_node_obstacle_with_xlabel_slot(
    xlabel_make_node_layout(node, @edge_spline.point(50.0, 60.0), 1.0, 0.5),
    false,
    labels,
    objects,
  )

  assert_eq(obstacle.pos, @edge_spline.point(14.0, 42.0))
  assert_eq(obstacle.width, 72.0)
  assert_eq(obstacle.height, 36.0)
  assert_eq(obstacle.label_index, Some(0))
  assert_eq(objects.length(), 0)
  assert_eq(labels.length(), 1)
  match labels[0].target {
    XLabelTarget::Node(name) => assert_eq(name, "n")
    _ => fail("expected node xlabel target")
  }
  assert_eq(labels[0].set, false)
  assert_true(labels[0].width > 0.0)
  assert_true(labels[0].height > 0.0)
}

///|
test "build_node_obstacle_with_xlabel_slot keeps resolved xlabels as fixed obstacles and flips node bounds" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")
  node.set_attr("xlabel", "outside")
  let xlabel_pos = @edge_spline.point(100.0, 110.0)

  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  let obstacle = build_node_obstacle_with_xlabel_slot(
    xlabel_make_node_layout(
      node,
      @edge_spline.point(40.0, 50.0),
      1.5,
      0.5,
      xlabel_pos=Some(xlabel_pos),
    ),
    true,
    labels,
    objects,
  )

  let metrics = match xlabel_metrics_for_node(node) {
    Some(value) => value
    None => fail("expected node xlabel metrics")
  }
  let label_dims = maybe_flip_dims(metrics.width, metrics.height, true)

  assert_eq(obstacle.pos, @edge_spline.point(22.0, -4.0))
  assert_eq(obstacle.width, 36.0)
  assert_eq(obstacle.height, 108.0)
  assert_eq(obstacle.label_index, None)
  assert_eq(labels.length(), 0)
  assert_eq(objects.length(), 1)
  assert_eq(
    objects[0].pos,
    @edge_spline.point(
      xlabel_pos.x - label_dims.width / 2.0,
      xlabel_pos.y - label_dims.height / 2.0,
    ),
  )
  assert_eq(objects[0].width, label_dims.width)
  assert_eq(objects[0].height, label_dims.height)
  assert_eq(objects[0].label_index, None)
}

///|
test "collect_edge_xlabel_candidates uses anchors for unresolved edge labels and existing obstacles for resolved ones" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  edge.set_attr("taillabel", "tail")
  edge.set_attr("headlabel", "head")
  edge.set_attr("xlabel", "extra")

  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  collect_edge_xlabel_candidates(
    xlabel_make_edge_layout(
      edge,
      straight_spline(),
      label_pos=Some(@edge_spline.point(20.0, 30.0)),
    ),
    @layout_prep.SplinesMode::Spline,
    false,
    labels,
    objects,
  )

  let edge_key = @edge_identity.edge_key(edge)

  assert_eq(labels.length(), 3)
  assert_eq(objects.length(), 4)
  assert_eq(objects[0].label_index, None)
  assert_true(objects[0].width > 0.0)
  assert_true(objects[0].height > 0.0)

  assert_eq(objects[1].pos, @edge_spline.point(0.0, 0.0))
  assert_eq(objects[1].width, 0.0)
  assert_eq(objects[1].height, 0.0)
  assert_eq(objects[1].label_index, Some(0))
  assert_eq(objects[2].pos, @edge_spline.point(9.0, 0.0))
  assert_eq(objects[2].width, 0.0)
  assert_eq(objects[2].height, 0.0)
  assert_eq(objects[2].label_index, Some(1))
  assert_eq(objects[3].pos, @edge_spline.point(4.5, 0.0))
  assert_eq(objects[3].width, 0.0)
  assert_eq(objects[3].height, 0.0)
  assert_eq(objects[3].label_index, Some(2))

  match labels[0].target {
    XLabelTarget::EdgeTail(key) => assert_eq(key, edge_key)
    _ => fail("expected tail xlabel target")
  }
  match labels[1].target {
    XLabelTarget::EdgeHead(key) => assert_eq(key, edge_key)
    _ => fail("expected head xlabel target")
  }
  match labels[2].target {
    XLabelTarget::EdgeXlabel(key) => assert_eq(key, edge_key)
    _ => fail("expected exterior edge xlabel target")
  }
}

///|
test "collect_edge_xlabel_candidates flips dimensions for existing and deferred edge labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  edge.set_attr("taillabel", "tail")
  edge.set_attr("headlabel", "head")
  edge.set_attr("xlabel", "extra")

  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  let resolved_mid = @edge_spline.point(20.0, 30.0)
  collect_edge_xlabel_candidates(
    xlabel_make_edge_layout(
      edge,
      straight_spline(),
      label_pos=Some(resolved_mid),
    ),
    @layout_prep.SplinesMode::Spline,
    true,
    labels,
    objects,
  )

  let mid_metrics = match @edge_label_metrics.edge_mid_label_metrics(edge) {
    Some(value) => value
    None => fail("expected edge mid metrics")
  }
  let tail_metrics = match
    @edge_label_metrics.edge_label_metrics_for_attr(edge, "taillabel", true) {
    Some(value) => value
    None => fail("expected edge tail metrics")
  }
  let head_metrics = match
    @edge_label_metrics.edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some(value) => value
    None => fail("expected edge head metrics")
  }
  let edge_metrics = match xlabel_metrics_for_edge(edge) {
    Some(value) => value
    None => fail("expected edge xlabel metrics")
  }
  let mid_dims = maybe_flip_dims(mid_metrics.width, mid_metrics.height, true)
  let tail_dims = maybe_flip_dims(tail_metrics.width, tail_metrics.height, true)
  let head_dims = maybe_flip_dims(head_metrics.width, head_metrics.height, true)
  let edge_dims = maybe_flip_dims(edge_metrics.width, edge_metrics.height, true)
  let edge_key = @edge_identity.edge_key(edge)

  assert_eq(labels.length(), 3)
  assert_eq(objects.length(), 4)
  assert_eq(
    objects[0].pos,
    @edge_spline.point(
      resolved_mid.x - mid_dims.width / 2.0,
      resolved_mid.y - mid_dims.height / 2.0,
    ),
  )
  assert_eq(objects[0].width, mid_dims.width)
  assert_eq(objects[0].height, mid_dims.height)
  assert_eq(objects[0].label_index, None)

  assert_eq(objects[1].pos, @edge_spline.point(0.0, 0.0))
  assert_eq(objects[1].width, 0.0)
  assert_eq(objects[1].height, 0.0)
  assert_eq(objects[1].label_index, Some(0))
  assert_eq(objects[2].pos, @edge_spline.point(9.0, 0.0))
  assert_eq(objects[2].width, 0.0)
  assert_eq(objects[2].height, 0.0)
  assert_eq(objects[2].label_index, Some(1))
  assert_eq(objects[3].pos, @edge_spline.point(4.5, 0.0))
  assert_eq(objects[3].width, 0.0)
  assert_eq(objects[3].height, 0.0)
  assert_eq(objects[3].label_index, Some(2))

  match labels[0].target {
    XLabelTarget::EdgeTail(key) => assert_eq(key, edge_key)
    _ => fail("expected tail xlabel target")
  }
  assert_eq(labels[0].width, tail_dims.width)
  assert_eq(labels[0].height, tail_dims.height)

  match labels[1].target {
    XLabelTarget::EdgeHead(key) => assert_eq(key, edge_key)
    _ => fail("expected head xlabel target")
  }
  assert_eq(labels[1].width, head_dims.width)
  assert_eq(labels[1].height, head_dims.height)

  match labels[2].target {
    XLabelTarget::EdgeXlabel(key) => assert_eq(key, edge_key)
    _ => fail("expected exterior edge xlabel target")
  }
  assert_eq(labels[2].width, edge_dims.width)
  assert_eq(labels[2].height, edge_dims.height)
}

///|
test "collect_edge_xlabel_candidates skips deferred labels when spline geometry is missing" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("label", "mid")
  edge.set_attr("taillabel", "tail")
  edge.set_attr("headlabel", "head")
  edge.set_attr("xlabel", "extra")

  let labels : Array[XLabel] = []
  let objects : Array[XObject] = []
  collect_edge_xlabel_candidates(
    {
      edge,
      splines: [],
      label_pos: None,
      head_label_pos: None,
      tail_label_pos: None,
      xlabel_pos: None,
    },
    @layout_prep.SplinesMode::Spline,
    false,
    labels,
    objects,
  )

  assert_eq(labels.length(), 0)
  assert_eq(objects.length(), 0)
}

///|
fn xlabel_make_layout_tree(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  nodes? : Array[DotLayoutNode] = [],
  edges? : Array[DotLayoutEdge] = [],
  subgraphs? : Array[@shared.LayoutTree] = [],
) -> @shared.LayoutTree {
  { graph, bbox, label_pos: None, nodes, edges, subgraphs }
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
