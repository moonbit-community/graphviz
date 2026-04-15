// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

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
