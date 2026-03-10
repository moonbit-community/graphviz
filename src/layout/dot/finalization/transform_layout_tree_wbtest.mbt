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
