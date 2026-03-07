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
  let expected_cluster =
    rect_from_center({ x: 20.0, y: 30.0 }, cluster_metrics.width_pt, cluster_metrics.height_pt, 3.0)
  let expected_nested =
    rect_from_center({ x: 40.0, y: 50.0 }, nested_metrics.width_pt, nested_metrics.height_pt, 3.0)

  assert_eq(rects, [expected_cluster, expected_nested])
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

  let expanded = expand_layout_tree_bbox_for_edge_labels(layout, ranks, Map::new())
  let metrics = match @edge_label_metrics.edge_label_metrics_for_attr(edge, "headlabel", true) {
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

  assert_eq(graph.get_attr("bb"), Some(@shared.format_rect(layout.bbox)))
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
