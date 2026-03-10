///|
test "apply_ratio_fill_scale scales only root layouts, rounds node positions, and recurses into subgraphs" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("ratio", "fill")
  root.set_attr("size", "2,1")
  let cluster = root.subgraph(name="cluster_0")
  let a = root.node("a")
  let b = cluster.node("b")
  let edge = root.edge(a, a)
  ignore(b)

  let cluster_layout = root_coordinates_make_layout_tree(
    cluster,
    { llx: 10.0, lly: 5.0, urx: 20.0, ury: 10.0 },
    label_pos=Some({ x: 15.0, y: 9.0 }),
    nodes=[
      root_coordinates_make_node_layout(
        b,
        { x: 12.6, y: 8.4 },
        1.0,
        1.0,
        label_pos=Some({ x: 11.0, y: 7.0 }),
      ),
    ],
  )
  let layout = root_coordinates_make_layout_tree(
    root,
    { llx: 0.0, lly: 0.0, urx: 72.0, ury: 24.0 },
    label_pos=Some({ x: 12.5, y: 6.5 }),
    nodes=[
      root_coordinates_make_node_layout(
        a,
        { x: 10.4, y: 7.6 },
        1.0,
        1.0,
        label_pos=Some({ x: 1.25, y: 2.5 }),
        xlabel_pos=Some({ x: 3.0, y: 4.0 }),
      ),
    ],
    edges=[
      root_coordinates_make_edge_layout(
        edge,
        {
          start: Some({ x: 1.0, y: 2.0 }),
          end: Some({ x: 11.0, y: 7.0 }),
          points: [
            { x: 1.0, y: 2.0 },
            { x: 3.0, y: 4.0 },
            { x: 7.0, y: 5.0 },
            { x: 11.0, y: 7.0 },
          ],
        },
        label_pos=Some({ x: 5.0, y: 6.0 }),
        head_label_pos=Some({ x: 6.0, y: 7.0 }),
        tail_label_pos=Some({ x: 4.0, y: 5.0 }),
        xlabel_pos=Some({ x: 7.0, y: 8.0 }),
      ),
    ],
    subgraphs=[cluster_layout],
  )

  let scaled = apply_ratio_fill_scale(layout, @rankdir.RankDir::TB, layout.bbox)
  let scaled_cluster = scaled.subgraphs[0]
  let scaled_edge = scaled.edges[0].splines[0]

  assert_eq(scaled.bbox, { llx: 0.0, lly: 0.0, urx: 144.0, ury: 72.0 })
  assert_eq(scaled.label_pos, Some({ x: 25.0, y: 19.5 }))
  assert_eq(scaled.nodes[0].pos, { x: 21.0, y: 23.0 })
  assert_eq(scaled.nodes[0].label_pos, Some({ x: 2.5, y: 7.5 }))
  assert_eq(scaled.nodes[0].xlabel_pos, Some({ x: 6.0, y: 12.0 }))
  assert_eq(scaled_edge.start, Some({ x: 2.0, y: 6.0 }))
  assert_eq(scaled_edge.end, Some({ x: 22.0, y: 21.0 }))
  assert_eq(scaled_edge.points, [
    { x: 2.0, y: 6.0 },
    { x: 6.0, y: 12.0 },
    { x: 14.0, y: 15.0 },
    { x: 22.0, y: 21.0 },
  ])
  assert_eq(scaled.edges[0].label_pos, Some({ x: 10.0, y: 18.0 }))
  assert_eq(scaled.edges[0].head_label_pos, Some({ x: 12.0, y: 21.0 }))
  assert_eq(scaled.edges[0].tail_label_pos, Some({ x: 8.0, y: 15.0 }))
  assert_eq(scaled.edges[0].xlabel_pos, Some({ x: 14.0, y: 24.0 }))
  assert_eq(scaled_cluster.bbox, { llx: 20.0, lly: 15.0, urx: 40.0, ury: 30.0 })
  assert_eq(scaled_cluster.label_pos, Some({ x: 30.0, y: 27.0 }))
  assert_eq(scaled_cluster.nodes[0].pos, { x: 25.0, y: 25.0 })
  assert_eq(scaled_cluster.nodes[0].label_pos, Some({ x: 22.0, y: 21.0 }))
  assert_eq(
    apply_ratio_fill_scale(cluster_layout, @rankdir.RankDir::TB, layout.bbox).bbox,
    cluster_layout.bbox,
  )
}
