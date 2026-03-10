///|
test "shift_layout_to_origin translates only root layouts" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let a = root.node("a")
  let b = root.node("b")
  let edge = root.edge(a, b)
  let cluster_layout = root_coordinates_make_layout_tree(
    cluster,
    { llx: 6.0, lly: 8.0, urx: 12.0, ury: 14.0 },
    label_pos=Some({ x: 9.0, y: 13.0 }),
    nodes=[root_coordinates_make_node_layout(b, { x: 11.0, y: 12.0 }, 1.0, 1.0)],
  )
  let layout = root_coordinates_make_layout_tree(
    root,
    { llx: 5.0, lly: 7.0, urx: 15.0, ury: 17.0 },
    label_pos=Some({ x: 9.0, y: 16.0 }),
    nodes=[root_coordinates_make_node_layout(a, { x: 6.0, y: 8.0 }, 1.0, 1.0)],
    edges=[
      root_coordinates_make_edge_layout(
        edge,
        {
          start: Some({ x: 5.0, y: 7.0 }),
          end: Some({ x: 15.0, y: 17.0 }),
          points: [
            { x: 5.0, y: 7.0 },
            { x: 8.0, y: 9.0 },
            { x: 11.0, y: 12.0 },
            { x: 15.0, y: 17.0 },
          ],
        },
        label_pos=Some({ x: 10.0, y: 11.0 }),
      ),
    ],
    subgraphs=[cluster_layout],
  )

  let shifted = shift_layout_to_origin(layout)
  let root_edge = shifted.edges[0].splines[0]
  let shifted_cluster = shifted.subgraphs[0]

  assert_eq(shifted.bbox, { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 })
  assert_eq(shifted.label_pos, Some({ x: 4.0, y: 9.0 }))
  assert_eq(shifted.nodes[0].pos, { x: 1.0, y: 1.0 })
  assert_eq(root_edge.start, Some({ x: 0.0, y: 0.0 }))
  assert_eq(root_edge.end, Some({ x: 10.0, y: 10.0 }))
  assert_eq(root_edge.points[1], { x: 3.0, y: 2.0 })
  assert_eq(shifted.edges[0].label_pos, Some({ x: 5.0, y: 4.0 }))
  assert_eq(shifted_cluster.bbox, { llx: 1.0, lly: 1.0, urx: 7.0, ury: 7.0 })
  assert_eq(shifted_cluster.label_pos, Some({ x: 4.0, y: 6.0 }))
  assert_eq(shifted_cluster.nodes[0].pos, { x: 6.0, y: 5.0 })

  assert_eq(shift_layout_to_origin(cluster_layout).bbox, cluster_layout.bbox)
}
