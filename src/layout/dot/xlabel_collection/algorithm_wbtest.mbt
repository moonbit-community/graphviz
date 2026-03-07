///|
fn make_node_layout(
  node : @cgraph.Node,
  pos : @geom.Point,
  width_in : Double,
  height_in : Double,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutNode {
  { node, pos, width_in, height_in, label_pos: None, xlabel_pos }
}

///|
fn make_edge_layout(
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
    make_node_layout(node, @edge_spline.point(50.0, 60.0), 1.0, 0.5),
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
    make_node_layout(
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
    make_edge_layout(
      edge,
      straight_spline(),
      label_pos=Some(@edge_spline.point(20.0, 30.0)),
    ),
    @shared.SplinesMode::Spline,
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
    @shared.SplinesMode::Spline,
    false,
    labels,
    objects,
  )

  assert_eq(labels.length(), 0)
  assert_eq(objects.length(), 0)
}
