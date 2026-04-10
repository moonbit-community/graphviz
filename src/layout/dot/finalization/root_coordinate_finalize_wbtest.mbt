// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "finalize_root_coordinates applies root margin then shifts to origin and refreshes root labels" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("label", "Root")
  root.set_attr("margin", "0.5")
  ignore(root.subgraph(name="cluster_0"))
  let a = root.node("a")
  let layout = root_coordinates_make_layout_tree(
    root,
    { llx: 10.0, lly: 20.0, urx: 30.0, ury: 40.0 },
    label_pos=Some({ x: -1.0, y: -1.0 }),
    nodes=[root_coordinates_make_node_layout(a, { x: 12.0, y: 25.0 }, 1.0, 1.0)],
    subgraphs=[
      root_coordinates_make_layout_tree(
        root.subgraph(name="cluster_1"),
        { llx: 11.0, lly: 21.0, urx: 15.0, ury: 24.0 },
        label_pos=Some({ x: 12.0, y: 22.0 }),
      ),
    ],
  )

  let finalized = finalize_root_coordinates(layout)
  let expected_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 92.0, ury: 20.0 }

  assert_eq(finalized.bbox, expected_bbox)
  assert_eq(finalized.nodes[0].pos, { x: 38.0, y: 5.0 })
  assert_eq(finalized.subgraphs[0].bbox, {
    llx: 37.0,
    lly: 1.0,
    urx: 41.0,
    ury: 4.0,
  })
  assert_eq(finalized.subgraphs[0].label_pos, Some({ x: 38.0, y: 2.0 }))
  assert_eq(finalized.label_pos, root_label_pos_for_bbox(root, expected_bbox))
}

///|
test "finalize_root_coordinates shifts root bbox to origin and refreshes root label" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("label", "Root Label")
  let layout = root_coordinates_make_layout_tree(
    graph,
    { llx: 10.0, lly: 20.0, urx: 110.0, ury: 70.0 },
    label_pos=Some({ x: -1.0, y: -1.0 }),
  )

  let finalized = finalize_root_coordinates(layout)
  let expected_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 100.0, ury: 50.0 }

  assert_eq(finalized.bbox, expected_bbox)
  assert_eq(finalized.label_pos, root_label_pos_for_bbox(graph, expected_bbox))
}
