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
