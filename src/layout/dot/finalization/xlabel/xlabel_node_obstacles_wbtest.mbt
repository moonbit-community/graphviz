// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
