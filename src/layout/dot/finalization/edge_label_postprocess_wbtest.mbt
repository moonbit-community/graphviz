///|
fn postprocess_make_layout_tree(
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
fn postprocess_make_edge_layout(
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

  let cluster_layout = postprocess_make_layout_tree(
    cluster,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 20.0, y: 30.0 }),
    subgraphs=[
      postprocess_make_layout_tree(
        nested,
        { llx: 0.0, lly: 0.0, urx: 8.0, ury: 8.0 },
        label_pos=Some({ x: 40.0, y: 50.0 }),
      ),
    ],
  )
  let plain_layout = postprocess_make_layout_tree(
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
test "apply_edge_label_updates recurses into nested subgraphs and preserves non-edge fields" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let nested = cluster.subgraph(name="cluster_1")
  let a = root.node("a")
  let b = root.node("b")
  let root_edge = root.edge(a, b)
  let c = cluster.node("c")
  let d = cluster.node("d")
  let cluster_edge = cluster.edge(c, d)
  let e = nested.node("e")
  let f = nested.node("f")
  let nested_edge = nested.edge(e, f)

  let nested_edge_layout = postprocess_make_edge_layout(
    nested_edge,
    {
      start: None,
      end: None,
      points: [
        { x: 1.0, y: 1.0 },
        { x: 4.0, y: 1.0 },
        { x: 7.0, y: 1.0 },
        { x: 10.0, y: 1.0 },
      ],
    },
    label_pos=Some({ x: 30.0, y: 40.0 }),
  )
  let cluster_edge_layout = postprocess_make_edge_layout(
    cluster_edge,
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
    label_pos=Some({ x: 10.0, y: 20.0 }),
  )
  let root_edge_layout = postprocess_make_edge_layout(
    root_edge,
    {
      start: None,
      end: None,
      points: [
        { x: 2.0, y: 2.0 },
        { x: 5.0, y: 2.0 },
        { x: 8.0, y: 2.0 },
        { x: 11.0, y: 2.0 },
      ],
    },
    label_pos=Some({ x: 50.0, y: 60.0 }),
  )
  let graphs = [
    postprocess_make_layout_tree(
      cluster,
      { llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 },
      label_pos=Some({ x: 8.0, y: 9.0 }),
      edges=[cluster_edge_layout],
      subgraphs=[
        postprocess_make_layout_tree(
          nested,
          { llx: 5.0, lly: 6.0, urx: 7.0, ury: 8.0 },
          label_pos=Some({ x: 11.0, y: 12.0 }),
          edges=[nested_edge_layout],
        ),
      ],
    ),
    postprocess_make_layout_tree(
      root,
      { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
      edges=[root_edge_layout],
    ),
  ]

  let nested_adjusted = @edge_label.adjust_edge_label_positions(
    [nested_edge_layout],
    [{ llx: 25.0, lly: 35.0, urx: 35.0, ury: 45.0 }],
    2.0,
    edge => {
      match @edge_label_metrics.edge_mid_label_metrics(edge) {
        Some(metrics) => Some({ width: metrics.width, height: metrics.height })
        None => None
      }
    },
  )

  let updated = apply_edge_label_updates(graphs, nested_adjusted.updates)

  assert_eq(updated[0].bbox, graphs[0].bbox)
  assert_eq(updated[0].label_pos, graphs[0].label_pos)
  assert_eq(updated[0].edges[0].label_pos, cluster_edge_layout.label_pos)
  assert_eq(updated[0].subgraphs[0].bbox, graphs[0].subgraphs[0].bbox)
  assert_eq(updated[0].subgraphs[0].label_pos, graphs[0].subgraphs[0].label_pos)
  assert_eq(
    updated[0].subgraphs[0].edges[0].label_pos,
    nested_adjusted.edges[0].label_pos,
  )
  assert_eq(updated[1].edges[0].label_pos, root_edge_layout.label_pos)
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
  let edge_layout = postprocess_make_edge_layout(
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
  let cluster_layout = postprocess_make_layout_tree(
    cluster,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    label_pos=Some({ x: 20.0, y: 30.0 }),
    edges=[edge_layout],
  )
  let root_layout = postprocess_make_layout_tree(
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
test "adjust_labels_for_overlaps recurses into subgraphs and propagates overlap updates" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let tail = cluster.node("tail")
  let edge_1 = cluster.edge(tail, cluster.node("left"))
  let edge_2 = cluster.edge(tail, cluster.node("right"))
  edge_1.set_attr("label", "left")
  edge_2.set_attr("label", "right")
  let edge_layouts = [
    postprocess_make_edge_layout(
      edge_1,
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
      label_pos=Some({ x: 5.0, y: 10.0 }),
    ),
    postprocess_make_edge_layout(
      edge_2,
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
      label_pos=Some({ x: 7.0, y: 20.0 }),
    ),
  ]
  let cluster_layout = postprocess_make_layout_tree(
    cluster,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    edges=edge_layouts,
  )
  let root_layout = postprocess_make_layout_tree(
    root,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    subgraphs=[cluster_layout],
  )
  let expected = @edge_label.adjust_edge_label_overlaps(
    edge_layouts,
    10.0,
    @rankdir.RankDir::TB,
    edge => {
      match @edge_label_metrics.edge_mid_label_metrics(edge) {
        Some(metrics) => Some({ width: metrics.width, height: metrics.height })
        None => None
      }
    },
    @edge_label.edge_tail_point_for_layout,
  )

  let adjusted = adjust_labels_for_overlaps(
    root_layout,
    10.0,
    @rankdir.RankDir::TB,
  )

  assert_eq(adjusted.edges.length(), 0)
  assert_eq(adjusted.subgraphs.length(), 1)
  assert_eq(
    adjusted.subgraphs[0].edges[0].label_pos,
    expected.edges[0].label_pos,
  )
  assert_eq(
    adjusted.subgraphs[0].edges[1].label_pos,
    expected.edges[1].label_pos,
  )
}

///|
test "expand_layout_tree_bbox_for_edge_labels expands root bbox for endpoint labels" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  edge.set_attr("headlabel", "H")

  let layout = postprocess_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    edges=[
      postprocess_make_edge_layout(
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
