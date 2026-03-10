///|

///|
fn transform_make_layout_tree(
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
fn transform_make_node_layout(
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
fn transform_make_edge_layout(
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
test "transform_point and transform_optional_point map coordinates for each rankdir" {
  let bbox : @geom.Rect = { llx: 10.0, lly: 20.0, urx: 50.0, ury: 80.0 }
  let point : @geom.Point = { x: 13.0, y: 29.0 }

  assert_eq(transform_point(point, bbox, RankDir::TB), point)
  assert_eq(transform_point(point, bbox, RankDir::BT), { x: 13.0, y: 71.0 })
  assert_eq(transform_point(point, bbox, RankDir::LR), { x: 71.0, y: 13.0 })
  assert_eq(transform_point(point, bbox, RankDir::RL), { x: 29.0, y: 13.0 })

  assert_eq(
    transform_optional_point(Some(point), bbox, RankDir::BT),
    Some({ x: 13.0, y: 71.0 }),
  )
  assert_eq(transform_optional_point(None, bbox, RankDir::LR), None)
}

///|
test "transform_spline and shift_spline update all spline coordinates consistently" {
  let bbox : @geom.Rect = { llx: 0.0, lly: 10.0, urx: 100.0, ury: 60.0 }
  let spline : @geom.Spline = {
    start: Some({ x: 1.0, y: 11.0 }),
    end: Some({ x: 7.0, y: 17.0 }),
    points: [
      { x: 1.0, y: 11.0 },
      { x: 3.0, y: 13.0 },
      { x: 5.0, y: 15.0 },
      { x: 7.0, y: 17.0 },
    ],
  }

  let transformed = transform_spline(spline, bbox, RankDir::BT)
  assert_eq(transformed.start, Some({ x: 1.0, y: 59.0 }))
  assert_eq(transformed.end, Some({ x: 7.0, y: 53.0 }))
  assert_eq(transformed.points, [
    { x: 1.0, y: 59.0 },
    { x: 3.0, y: 57.0 },
    { x: 5.0, y: 55.0 },
    { x: 7.0, y: 53.0 },
  ])

  let shifted = shift_spline(spline, 4.0, -3.0)
  assert_eq(shifted.start, Some({ x: 5.0, y: 8.0 }))
  assert_eq(shifted.end, Some({ x: 11.0, y: 14.0 }))
  assert_eq(shifted.points, [
    { x: 5.0, y: 8.0 },
    { x: 7.0, y: 10.0 },
    { x: 9.0, y: 12.0 },
    { x: 11.0, y: 14.0 },
  ])
}

///|
test "shift helpers and transform_bbox_with_root preserve geometric bounds" {
  let point : @geom.Point = { x: 3.0, y: 4.0 }
  assert_eq(shift_point(point, 5.0, -2.0), { x: 8.0, y: 2.0 })
  assert_eq(
    shift_optional_point(Some(point), -1.0, 6.0),
    Some({ x: 2.0, y: 10.0 }),
  )
  assert_eq(shift_optional_point(None, -1.0, 6.0), None)

  let bbox : @geom.Rect = { llx: 20.0, lly: 10.0, urx: 40.0, ury: 30.0 }
  let root_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 }

  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::TB), bbox)
  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::BT), {
    llx: 20.0,
    lly: 50.0,
    urx: 40.0,
    ury: 70.0,
  })
  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::LR), {
    llx: 50.0,
    lly: 20.0,
    urx: 70.0,
    ury: 40.0,
  })
  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::RL), {
    llx: 10.0,
    lly: 20.0,
    urx: 30.0,
    ury: 40.0,
  })
}

///|
test "refresh_cluster_labels recomputes labeled cluster anchors and leaves others unchanged" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  cluster.set_attr("labelloc", "b")
  cluster.set_attr("labeljust", "r")
  let unlabeled = root.subgraph(name="cluster_1")
  let nested = cluster.subgraph(name="cluster_2")
  nested.set_attr("label", "Nested")

  let layout = transform_make_layout_tree(
    root,
    { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 },
    subgraphs=[
      transform_make_layout_tree(
        cluster,
        { llx: 10.0, lly: 20.0, urx: 50.0, ury: 60.0 },
        label_pos=Some({ x: -1.0, y: -1.0 }),
        subgraphs=[
          transform_make_layout_tree(
            nested,
            { llx: 14.0, lly: 26.0, urx: 32.0, ury: 42.0 },
            label_pos=Some({ x: -2.0, y: -2.0 }),
          ),
        ],
      ),
      transform_make_layout_tree(
        unlabeled,
        { llx: 60.0, lly: 10.0, urx: 90.0, ury: 30.0 },
        label_pos=Some({ x: 61.0, y: 11.0 }),
      ),
    ],
  )

  let refreshed = refresh_cluster_labels(layout)
  let refreshed_cluster = refreshed.subgraphs[0]
  let refreshed_nested = refreshed_cluster.subgraphs[0]
  let refreshed_unlabeled = refreshed.subgraphs[1]

  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let nested_metrics = match @label_metrics.graph_label_metrics(nested) {
    Some(value) => value
    None => fail("expected nested label metrics")
  }
  let pad = @cluster_geometry.CLUSTER_LABEL_PAD_PT
  let expected_cluster_label = @graph_label.graph_label_pos(
    refreshed_cluster.bbox,
    cluster_metrics.width_pt + pad * 2.0,
    cluster_metrics.height_pt + pad,
    @graph_label.graph_label_loc(cluster),
    @graph_label.graph_label_just(cluster),
  )
  let expected_nested_label = @graph_label.graph_label_pos(
    refreshed_nested.bbox,
    nested_metrics.width_pt + pad * 2.0,
    nested_metrics.height_pt + pad,
    @graph_label.graph_label_loc(nested),
    @graph_label.graph_label_just(nested),
  )

  assert_eq(refreshed_cluster.label_pos, Some(expected_cluster_label))
  assert_eq(refreshed_nested.label_pos, Some(expected_nested_label))
  assert_eq(refreshed_unlabeled.label_pos, Some({ x: 61.0, y: 11.0 }))
}

///|
test "shift_layout_graph shifts nodes edges labels and subgraphs recursively" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  let cluster_node = cluster.node("c")

  let layout = transform_make_layout_tree(
    graph,
    { llx: 0.0, lly: 1.0, urx: 20.0, ury: 30.0 },
    label_pos=Some({ x: 2.0, y: 3.0 }),
    nodes=[
      transform_make_node_layout(
        a,
        { x: 10.0, y: 20.0 },
        1.0,
        0.5,
        label_pos=Some({ x: 11.0, y: 21.0 }),
        xlabel_pos=Some({ x: 12.0, y: 22.0 }),
      ),
    ],
    edges=[
      transform_make_edge_layout(
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
      transform_make_layout_tree(
        cluster,
        { llx: 1.0, lly: 2.0, urx: 6.0, ury: 8.0 },
        label_pos=Some({ x: 2.5, y: 7.5 }),
        nodes=[
          transform_make_node_layout(cluster_node, { x: 3.0, y: 4.0 }, 0.5, 0.5),
        ],
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

  let layout = transform_make_layout_tree(
    graph,
    { llx: 10.0, lly: 15.0, urx: 90.0, ury: 70.0 },
    label_pos=Some({ x: 50.0, y: 75.0 }),
    nodes=[
      transform_make_node_layout(
        a,
        { x: 10.0, y: 20.0 },
        1.0,
        0.5,
        label_pos=Some({ x: 11.0, y: 21.0 }),
        xlabel_pos=Some({ x: 12.0, y: 22.0 }),
      ),
    ],
    edges=[
      transform_make_edge_layout(
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
      transform_make_layout_tree(
        cluster,
        { llx: 20.0, lly: 10.0, urx: 50.0, ury: 30.0 },
        label_pos=Some({ x: 35.0, y: 28.0 }),
        nodes=[
          transform_make_node_layout(
            cluster_node,
            { x: 25.0, y: 15.0 },
            0.5,
            0.5,
          ),
        ],
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
test "apply_cluster_lr_mirror_after_rotation falls back to BT mirror for single-cluster LR layouts" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  let node = cluster.node("n")

  let rotated = transform_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 80.0, ury: 100.0 },
    nodes=[transform_make_node_layout(node, { x: 20.0, y: 30.0 }, 1.0, 0.5)],
    subgraphs=[
      transform_make_layout_tree(
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

  let rotated = transform_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 80.0, ury: 100.0 },
    nodes=[transform_make_node_layout(node, { x: 20.0, y: 30.0 }, 1.0, 0.5)],
    subgraphs=[
      transform_make_layout_tree(
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
