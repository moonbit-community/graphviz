// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_routing_layout_nodes uses provided positions and defaults missing nodes to origin" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let positions : Map[String, @geom.Point] = { "a": { x: 10.0, y: 20.0 } }
  let output_sizes : Map[String, NodeSize] = {
    "a": sample_node_size(12.0, 8.0),
    "b": sample_node_size(20.0, 10.0),
  }

  let nodes_out = build_routing_layout_nodes(
    [a, b],
    positions,
    output_sizes,
    RecordOrientation::Horizontal,
  )

  assert_eq(nodes_out.length(), 2)
  assert_point_close(nodes_out[0].pos, { x: 10.0, y: 20.0 })
  assert_close(nodes_out[0].width_in, 12.0 / 72.0)
  assert_close(nodes_out[0].height_in, 8.0 / 72.0)
  assert_point_close(nodes_out[1].pos, { x: 0.0, y: 0.0 })
  assert_close(nodes_out[1].width_in, 20.0 / 72.0)
  assert_close(nodes_out[1].height_in, 10.0 / 72.0)
}
