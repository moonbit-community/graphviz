// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
