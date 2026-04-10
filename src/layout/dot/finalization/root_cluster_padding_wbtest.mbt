// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "apply_root_cluster_padding shifts content by bottom pad and refreshes the root label" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  root.set_attr("label", "Root")
  root.set_attr("labelloc", "t")
  let a = root.node("a")
  let edge = root.edge(a, root.node("b"))
  let layout = root_coordinates_make_layout_tree(
    root,
    { llx: 0.0, lly: 0.0, urx: 20.0, ury: 20.0 },
    label_pos=Some({ x: -1.0, y: -1.0 }),
    nodes=[root_coordinates_make_node_layout(a, { x: 10.0, y: 5.0 }, 1.0, 1.0)],
    edges=[
      root_coordinates_make_edge_layout(edge, {
        start: Some({ x: 1.0, y: 2.0 }),
        end: Some({ x: 19.0, y: 18.0 }),
        points: [
          { x: 1.0, y: 2.0 },
          { x: 5.0, y: 6.0 },
          { x: 12.0, y: 12.0 },
          { x: 19.0, y: 18.0 },
        ],
      }),
    ],
  )
  let padded = apply_root_cluster_padding({
    layout,
    root_cluster_pad_top: 2.0,
    root_cluster_pad_bottom: 3.0,
  })
  let expected_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 20.0, ury: 25.0 }

  assert_eq(padded.bbox, expected_bbox)
  assert_eq(padded.nodes[0].pos, { x: 10.0, y: 8.0 })
  assert_eq(padded.edges[0].splines[0].start, Some({ x: 1.0, y: 5.0 }))
  assert_eq(padded.edges[0].splines[0].end, Some({ x: 19.0, y: 21.0 }))
  assert_eq(padded.label_pos, root_label_pos_for_bbox(root, expected_bbox))
}
