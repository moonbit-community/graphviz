///|
fn make_layout_tree(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  label_pos? : @geom.Point? = None,
  nodes? : Array[DotLayoutNode] = [],
  edges? : Array[DotLayoutEdge] = [],
  subgraphs? : Array[LayoutTree] = [],
) -> LayoutTree {
  { graph, bbox, label_pos, nodes, edges, subgraphs }
}

///|
fn make_node_layout(
  node : @cgraph.Node,
  pos : @geom.Point,
  width_in : Double,
  height_in : Double,
  label_pos? : @geom.Point? = None,
  xlabel_pos? : @geom.Point? = None,
) -> DotLayoutNode {
  { node, pos, width_in, height_in, label_pos, xlabel_pos }
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
test "shift_layout_graph shifts nodes edges labels and subgraphs recursively" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  let cluster_node = cluster.node("c")

  let layout = make_layout_tree(
    graph,
    { llx: 0.0, lly: 1.0, urx: 20.0, ury: 30.0 },
    label_pos=Some({ x: 2.0, y: 3.0 }),
    nodes=[
      make_node_layout(
        a,
        { x: 10.0, y: 20.0 },
        1.0,
        0.5,
        label_pos=Some({ x: 11.0, y: 21.0 }),
        xlabel_pos=Some({ x: 12.0, y: 22.0 }),
      ),
    ],
    edges=[
      make_edge_layout(
        edge,
        {
          start: Some({ x: 0.0, y: 0.0 }),
          end: Some({ x: 9.0, y: 9.0 }),
          points: [
            { x: 1.0, y: 2.0 },
            { x: 3.0, y: 4.0 },
            { x: 5.0, y: 6.0 },
            { x: 7.0, y: 8.0 },
          ],
        },
        label_pos=Some({ x: 4.0, y: 5.0 }),
        head_label_pos=Some({ x: 6.0, y: 7.0 }),
        tail_label_pos=Some({ x: 8.0, y: 9.0 }),
        xlabel_pos=Some({ x: 10.0, y: 11.0 }),
      ),
    ],
    subgraphs=[
      make_layout_tree(
        cluster,
        { llx: 1.0, lly: 2.0, urx: 6.0, ury: 8.0 },
        label_pos=Some({ x: 2.5, y: 7.5 }),
        nodes=[make_node_layout(cluster_node, { x: 3.0, y: 4.0 }, 0.5, 0.5)],
      ),
    ],
  )

  let shifted = shift_layout_graph(layout, 5.0, -7.0)

  assert_eq(shifted.bbox, { llx: 5.0, lly: -6.0, urx: 25.0, ury: 23.0 })
  assert_eq(shifted.label_pos, Some({ x: 7.0, y: -4.0 }))
  assert_eq(shifted.nodes[0].pos, { x: 15.0, y: 13.0 })
  assert_eq(shifted.nodes[0].label_pos, Some({ x: 16.0, y: 14.0 }))
  assert_eq(shifted.nodes[0].xlabel_pos, Some({ x: 17.0, y: 15.0 }))
  assert_eq(shifted.edges[0].splines[0].start, Some({ x: 5.0, y: -7.0 }))
  assert_eq(shifted.edges[0].splines[0].end, Some({ x: 14.0, y: 2.0 }))
  assert_eq(shifted.edges[0].splines[0].points, [
    { x: 6.0, y: -5.0 },
    { x: 8.0, y: -3.0 },
    { x: 10.0, y: -1.0 },
    { x: 12.0, y: 1.0 },
  ])
  assert_eq(shifted.edges[0].label_pos, Some({ x: 9.0, y: -2.0 }))
  assert_eq(shifted.edges[0].head_label_pos, Some({ x: 11.0, y: 0.0 }))
  assert_eq(shifted.edges[0].tail_label_pos, Some({ x: 13.0, y: 2.0 }))
  assert_eq(shifted.edges[0].xlabel_pos, Some({ x: 15.0, y: 4.0 }))
  assert_eq(shifted.subgraphs[0].bbox, {
    llx: 6.0,
    lly: -5.0,
    urx: 11.0,
    ury: 1.0,
  })
  assert_eq(shifted.subgraphs[0].label_pos, Some({ x: 7.5, y: 0.5 }))
  assert_eq(shifted.subgraphs[0].nodes[0].pos, { x: 8.0, y: -3.0 })
}

///|
test "rotate_layout_graph maps layout payloads through LR coordinates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  let cluster_node = cluster.node("c")
  let root_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 }

  let layout = make_layout_tree(
    graph,
    { llx: 10.0, lly: 15.0, urx: 90.0, ury: 70.0 },
    label_pos=Some({ x: 50.0, y: 75.0 }),
    nodes=[
      make_node_layout(
        a,
        { x: 10.0, y: 20.0 },
        1.0,
        0.5,
        label_pos=Some({ x: 11.0, y: 21.0 }),
        xlabel_pos=Some({ x: 12.0, y: 22.0 }),
      ),
    ],
    edges=[
      make_edge_layout(
        edge,
        {
          start: Some({ x: 0.0, y: 5.0 }),
          end: Some({ x: 90.0, y: 65.0 }),
          points: [
            { x: 1.0, y: 2.0 },
            { x: 3.0, y: 4.0 },
            { x: 5.0, y: 6.0 },
            { x: 7.0, y: 8.0 },
          ],
        },
        label_pos=Some({ x: 30.0, y: 40.0 }),
        head_label_pos=Some({ x: 35.0, y: 45.0 }),
        tail_label_pos=Some({ x: 25.0, y: 35.0 }),
        xlabel_pos=Some({ x: 20.0, y: 30.0 }),
      ),
    ],
    subgraphs=[
      make_layout_tree(
        cluster,
        { llx: 20.0, lly: 10.0, urx: 50.0, ury: 30.0 },
        label_pos=Some({ x: 35.0, y: 28.0 }),
        nodes=[make_node_layout(cluster_node, { x: 25.0, y: 15.0 }, 0.5, 0.5)],
      ),
    ],
  )

  let rotated = rotate_layout_graph(layout, root_bbox, RankDir::LR)

  assert_eq(rotated.bbox, { llx: 10.0, lly: 10.0, urx: 65.0, ury: 90.0 })
  assert_eq(rotated.label_pos, Some({ x: 5.0, y: 50.0 }))
  assert_eq(rotated.nodes[0].pos, { x: 60.0, y: 10.0 })
  assert_eq(rotated.nodes[0].label_pos, Some({ x: 59.0, y: 11.0 }))
  assert_eq(rotated.nodes[0].xlabel_pos, Some({ x: 58.0, y: 12.0 }))
  assert_eq(rotated.edges[0].splines[0].start, Some({ x: 75.0, y: 0.0 }))
  assert_eq(rotated.edges[0].splines[0].end, Some({ x: 15.0, y: 90.0 }))
  assert_eq(rotated.edges[0].splines[0].points, [
    { x: 78.0, y: 1.0 },
    { x: 76.0, y: 3.0 },
    { x: 74.0, y: 5.0 },
    { x: 72.0, y: 7.0 },
  ])
  assert_eq(rotated.edges[0].label_pos, Some({ x: 40.0, y: 30.0 }))
  assert_eq(rotated.edges[0].head_label_pos, Some({ x: 35.0, y: 35.0 }))
  assert_eq(rotated.edges[0].tail_label_pos, Some({ x: 45.0, y: 25.0 }))
  assert_eq(rotated.edges[0].xlabel_pos, Some({ x: 50.0, y: 20.0 }))
  assert_eq(rotated.subgraphs[0].bbox, {
    llx: 50.0,
    lly: 20.0,
    urx: 70.0,
    ury: 50.0,
  })
  assert_eq(rotated.subgraphs[0].label_pos, Some({ x: 52.0, y: 35.0 }))
  assert_eq(rotated.subgraphs[0].nodes[0].pos, { x: 65.0, y: 25.0 })
}

///|
test "finalize_root_coordinates shifts root bbox to origin and refreshes root label" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("label", "Root Label")
  let layout = make_layout_tree(
    graph,
    { llx: 10.0, lly: 20.0, urx: 110.0, ury: 70.0 },
    label_pos=Some({ x: -1.0, y: -1.0 }),
  )

  let finalized = finalize_root_coordinates(layout)
  let expected_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 100.0, ury: 50.0 }

  assert_eq(finalized.bbox, expected_bbox)
  assert_eq(finalized.label_pos, root_label_pos_for_bbox(graph, expected_bbox))
}

///|
test "apply_cluster_lr_mirror_after_rotation falls back to BT mirror for single-cluster LR layouts" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  let node = cluster.node("n")

  let rotated = make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 80.0, ury: 100.0 },
    nodes=[make_node_layout(node, { x: 20.0, y: 30.0 }, 1.0, 0.5)],
    subgraphs=[
      make_layout_tree(
        cluster,
        { llx: 10.0, lly: 20.0, urx: 30.0, ury: 50.0 },
        label_pos=Some({ x: 15.0, y: 48.0 }),
      ),
    ],
  )

  let mirrored = apply_cluster_lr_mirror_after_rotation({
    graph,
    rankdir: RankDir::LR,
    rotated,
    pre_rotation_bbox: { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 },
    rank_bbox: { llx: 0.0, lly: 0.0, urx: 50.0, ury: 40.0 },
    subgraph_base_bbox: { llx: 0.0, lly: 0.0, urx: 50.0, ury: 40.0 },
  })

  assert_eq(mirrored.bbox, rotated.bbox)
  assert_eq(mirrored.nodes[0].pos, { x: 20.0, y: 70.0 })
  assert_eq(mirrored.subgraphs[0].bbox, {
    llx: 10.0,
    lly: 50.0,
    urx: 30.0,
    ury: 80.0,
  })
  assert_eq(mirrored.subgraphs[0].label_pos, Some({ x: 15.0, y: 52.0 }))
}

///|
test "apply_cluster_lr_mirror_after_rotation uses point mirror and refreshes cluster labels when subgraph bbox exceeds rank bbox" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  let node = cluster.node("n")

  let rotated = make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 80.0, ury: 100.0 },
    nodes=[make_node_layout(node, { x: 20.0, y: 30.0 }, 1.0, 0.5)],
    subgraphs=[
      make_layout_tree(
        cluster,
        { llx: 10.0, lly: 20.0, urx: 30.0, ury: 50.0 },
        label_pos=Some({ x: -1.0, y: -1.0 }),
      ),
    ],
  )

  let mirrored = apply_cluster_lr_mirror_after_rotation({
    graph,
    rankdir: RankDir::LR,
    rotated,
    pre_rotation_bbox: { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 },
    rank_bbox: { llx: 10.0, lly: 0.0, urx: 60.0, ury: 80.0 },
    subgraph_base_bbox: { llx: 0.0, lly: 0.0, urx: 70.0, ury: 80.0 },
  })

  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let pad = @cluster_geometry.CLUSTER_LABEL_PAD_PT
  let expected_label_pos = @graph_label.graph_label_pos(
    mirrored.subgraphs[0].bbox,
    cluster_metrics.width_pt + pad * 2.0,
    cluster_metrics.height_pt + pad,
    @graph_label.graph_label_loc(cluster),
    @graph_label.graph_label_just(cluster),
  )

  assert_eq(mirrored.bbox, rotated.bbox)
  assert_eq(mirrored.nodes[0].pos, { x: 20.0, y: 40.0 })
  assert_eq(mirrored.subgraphs[0].bbox, {
    llx: 10.0,
    lly: 50.0,
    urx: 30.0,
    ury: 80.0,
  })
  assert_eq(mirrored.subgraphs[0].label_pos, Some(expected_label_pos))
}
