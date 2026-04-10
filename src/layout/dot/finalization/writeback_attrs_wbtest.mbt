// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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

  let node_layout = writeback_make_node_layout(
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
  let edge_layout = writeback_make_edge_layout(
    edge,
    spline,
    label_pos=Some({ x: 4.0, y: 5.0 }),
    head_label_pos=Some({ x: 7.0, y: 8.0 }),
    tail_label_pos=Some({ x: 1.0, y: 2.0 }),
    xlabel_pos=Some({ x: 6.0, y: 7.0 }),
  )
  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 },
    nodes=[node_layout],
    edges=[edge_layout],
    subgraphs=[
      writeback_make_layout_tree(cluster, {
        llx: 1.0,
        lly: 1.0,
        urx: 2.0,
        ury: 2.0,
      }),
      writeback_make_layout_tree(plain, {
        llx: 3.0,
        lly: 3.0,
        urx: 4.0,
        ury: 4.0,
      }),
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
test "apply_layout_tree_writeback writes root and cluster label attrs recursively" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("label", "Root Label")
  let cluster = graph.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster Label")

  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 20.0, ury: 10.0 },
    label_pos=Some({ x: 7.0, y: 8.0 }),
    subgraphs=[
      writeback_make_layout_tree(
        cluster,
        { llx: 1.0, lly: 2.0, urx: 11.0, ury: 12.0 },
        label_pos=Some({ x: 6.0, y: 9.0 }),
      ),
    ],
  )

  apply_layout_tree_writeback(layout)

  let root_metrics = match @label_metrics.graph_label_metrics(graph) {
    Some(value) => value
    None => fail("expected root graph label metrics")
  }
  let cluster_metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }

  assert_eq(graph.get_attr("bb"), Some("0,0,20,10"))
  assert_eq(
    graph.get_attr("lwidth"),
    Some(format_fixed(root_metrics.width_pt / 72.0, 2)),
  )
  assert_eq(
    graph.get_attr("lheight"),
    Some(format_fixed(root_metrics.height_pt / 72.0, 2)),
  )
  assert_eq(graph.get_attr("lp"), Some("7,8"))

  assert_eq(cluster.get_attr("bb"), Some("1,2,11,12"))
  assert_eq(
    cluster.get_attr("lwidth"),
    Some(format_fixed(cluster_metrics.width_pt / 72.0, 2)),
  )
  assert_eq(
    cluster.get_attr("lheight"),
    Some(format_fixed(cluster_metrics.height_pt / 72.0, 2)),
  )
  assert_eq(cluster.get_attr("lp"), Some("6,9"))
}
