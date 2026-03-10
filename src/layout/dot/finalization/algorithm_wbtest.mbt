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
test "collect_cluster_label_rects recurses and skips unlabeled subgraphs" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "cluster")
  let nested = cluster.subgraph(name="cluster_1")
  nested.set_attr("label", "nested")
  let plain = root.subgraph(name="group_0")

  let cluster_layout = make_layout_tree(
    cluster,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 20.0, y: 30.0 }),
    subgraphs=[
      make_layout_tree(
        nested,
        { llx: 0.0, lly: 0.0, urx: 8.0, ury: 8.0 },
        label_pos=Some({ x: 40.0, y: 50.0 }),
      ),
    ],
  )
  let plain_layout = make_layout_tree(
    plain,
    { llx: 0.0, lly: 0.0, urx: 5.0, ury: 5.0 },
    label_pos=Some({ x: 60.0, y: 70.0 }),
  )

  let rects = collect_cluster_label_rects([cluster_layout, plain_layout], 3.0)

  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let nested_metrics = match @label_metrics.graph_label_metrics(nested) {
    Some(value) => value
    None => fail("expected nested label metrics")
  }
  let expected_cluster = rect_from_center(
    { x: 20.0, y: 30.0 },
    cluster_metrics.width_pt,
    cluster_metrics.height_pt,
    3.0,
  )
  let expected_nested = rect_from_center(
    { x: 40.0, y: 50.0 },
    nested_metrics.width_pt,
    nested_metrics.height_pt,
    3.0,
  )

  assert_eq(rects, [expected_cluster, expected_nested])
}

///|
test "adjust_labels_for_clusters recurses into labeled subgraphs and nudges overlapping edge labels" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "cluster")
  let a = root.node("a")
  let b = root.node("b")
  let edge = root.edge(a, b)
  edge.set_attr("label", "mid")
  let edge_layout = make_edge_layout(
    edge,
    {
      start: None,
      end: None,
      points: [
        { x: 0.0, y: 0.0 },
        { x: 3.0, y: 0.0 },
        { x: 6.0, y: 0.0 },
        { x: 9.0, y: 0.0 },
      ],
    },
    label_pos=Some({ x: 20.0, y: 30.0 }),
  )
  let cluster_layout = make_layout_tree(
    cluster,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 20.0, y: 30.0 }),
    edges=[edge_layout],
  )
  let root_layout = make_layout_tree(
    root,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    subgraphs=[cluster_layout],
  )
  let pad = 2.0
  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let expected = @edge_label.adjust_edge_label_positions(
    [edge_layout],
    [
      rect_from_center(
        { x: 20.0, y: 30.0 },
        cluster_metrics.width_pt,
        cluster_metrics.height_pt,
        pad,
      ),
    ],
    pad,
    edge => {
      match @edge_label_metrics.edge_mid_label_metrics(edge) {
        Some(metrics) => Some({ width: metrics.width, height: metrics.height })
        None => None
      }
    },
  )

  let adjusted = adjust_labels_for_clusters(root_layout, 10.0)

  assert_eq(adjusted.edges.length(), 0)
  assert_eq(adjusted.subgraphs.length(), 1)
  assert_eq(adjusted.subgraphs[0].label_pos, cluster_layout.label_pos)
  assert_eq(
    adjusted.subgraphs[0].edges[0].label_pos,
    expected.edges[0].label_pos,
  )
}

///|
test "expand_layout_tree_bbox_for_edge_labels expands root bbox for endpoint labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("headlabel", "H")

  let layout = make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    edges=[
      make_edge_layout(
        edge,
        {
          start: None,
          end: None,
          points: [
            { x: 0.0, y: 0.0 },
            { x: 3.0, y: 3.0 },
            { x: 6.0, y: 6.0 },
            { x: 9.0, y: 9.0 },
          ],
        },
        head_label_pos=Some({ x: 20.0, y: 15.0 }),
      ),
    ],
  )
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1

  let expanded = expand_layout_tree_bbox_for_edge_labels(
    layout,
    ranks,
    Map::new(),
  )
  let metrics = match
    @edge_label_metrics.edge_label_metrics_for_attr(edge, "headlabel", true) {
    Some(value) => value
    None => fail("expected head label metrics")
  }

  assert_eq(expanded.bbox.llx, 0.0)
  assert_eq(expanded.bbox.lly, 0.0)
  assert_eq(expanded.bbox.urx, 20.0 + metrics.width / 2.0)
  assert_eq(expanded.bbox.ury, 15.0 + metrics.height / 2.0)
}

///|
test "apply_layout_tree_writeback writes bbox by graph role and edge label attrs conditionally" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_0")
  let plain = graph.subgraph(name="group_0")
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("dir", "none")
  edge.set_attr("label", "L")
  edge.set_attr("taillabel", "T")
  edge.set_attr("headlabel", "")
  edge.set_attr("xlabel", "X")

  let node_layout = make_node_layout(
    a,
    { x: 10.0, y: 20.0 },
    1.0,
    0.5,
    xlabel_pos=Some({ x: 12.0, y: 24.0 }),
  )
  let spline : @geom.Spline = {
    start: Some({ x: -1.0, y: -1.0 }),
    end: Some({ x: 11.0, y: 11.0 }),
    points: [
      { x: 0.0, y: 0.0 },
      { x: 3.0, y: 0.0 },
      { x: 6.0, y: 0.0 },
      { x: 9.0, y: 0.0 },
    ],
  }
  let edge_layout = make_edge_layout(
    edge,
    spline,
    label_pos=Some({ x: 4.0, y: 5.0 }),
    head_label_pos=Some({ x: 7.0, y: 8.0 }),
    tail_label_pos=Some({ x: 1.0, y: 2.0 }),
    xlabel_pos=Some({ x: 6.0, y: 7.0 }),
  )
  let layout = make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    nodes=[node_layout],
    edges=[edge_layout],
    subgraphs=[
      make_layout_tree(cluster, { llx: 1.0, lly: 1.0, urx: 2.0, ury: 2.0 }),
      make_layout_tree(plain, { llx: 3.0, lly: 3.0, urx: 4.0, ury: 4.0 }),
    ],
  )

  apply_layout_tree_writeback(layout)

  assert_eq(graph.get_attr("bb"), Some(format_rect(layout.bbox)))
  assert_eq(cluster.get_attr("bb"), Some("1,1,2,2"))
  assert_eq(plain.get_attr("bb"), None)

  assert_eq(a.get_attr("pos"), Some("10,20"))
  assert_eq(a.get_attr("width"), Some("1"))
  assert_eq(a.get_attr("height"), Some("0.5"))
  assert_eq(a.get_attr("xlp"), Some("12,24"))

  assert_eq(edge.get_attr("pos"), Some("0,0 3,0 6,0 9,0"))
  assert_eq(edge.get_attr("lp"), Some("4,5"))
  assert_eq(edge.get_attr("head_lp"), None)
  assert_eq(edge.get_attr("tail_lp"), Some("1,2"))
  assert_eq(edge.get_attr("xlp"), Some("6,7"))
}

///|
test "apply_layout_tree_writeback writes graph label metrics star node rounding and arrow markers" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("label", "Root Label")
  let star = graph.node("star")
  star.set_attr("shape", "star")
  let head = graph.node("head")
  let edge = graph.edge(star, head)
  edge.set_attr("dir", "both")

  let star_layout = make_node_layout(star, { x: 10.0, y: 20.0 }, 1.0, 0.5)
  let edge_layout = make_edge_layout(edge, {
    start: Some({ x: -1.0, y: -2.0 }),
    end: Some({ x: 12.0, y: 13.0 }),
    points: [
      { x: 0.0, y: 0.0 },
      { x: 2.0, y: 1.0 },
      { x: 4.0, y: 2.0 },
      { x: 6.0, y: 3.0 },
    ],
  })
  let layout = make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 5.0, y: 9.0 }),
    nodes=[star_layout],
    edges=[edge_layout],
  )

  apply_layout_tree_writeback(layout)

  let graph_metrics = match @label_metrics.graph_label_metrics(graph) {
    Some(value) => value
    None => fail("expected root graph label metrics")
  }
  assert_eq(
    graph.get_attr("lwidth"),
    Some(format_fixed(graph_metrics.width_pt / 72.0, 2)),
  )
  assert_eq(
    graph.get_attr("lheight"),
    Some(format_fixed(graph_metrics.height_pt / 72.0, 2)),
  )
  assert_eq(graph.get_attr("lp"), Some("5,9"))
  assert_eq(star.get_attr("pos"), Some(format_point({ x: 10.0, y: 20.0005 })))
  assert_eq(edge.get_attr("pos"), Some("s,-1,-2 e,12,13 0,0 2,1 4,2 6,3"))
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
