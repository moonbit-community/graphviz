// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
