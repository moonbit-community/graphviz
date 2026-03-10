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
