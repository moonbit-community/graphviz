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
