// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "remap_parallel_edge_layouts uses a snapshot so reversed remaps do not cascade" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let edge_3 = graph.edge(a, b)
  let ranks : Map[String, Int] = { "a": 0, "b": 2 }
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  edges_out_by_id[edge_1.id()] = build_layout_edge(edge_1, 1.0)
  edges_out_by_id[edge_2.id()] = build_layout_edge(edge_2, 20.0)
  edges_out_by_id[edge_3.id()] = build_layout_edge(edge_3, 40.0)

  remap_parallel_edge_layouts({
    edges: [edge_1, edge_2, edge_3],
    ranks,
    edges_out_by_id,
    edge_port_label_pos_fn: _ => None,
  })

  assert_eq(
    edges_out_by_id
    .get(edge_1.id())
    .map(fn(layout) { layout.splines[0].points[0] }),
    Some(@edge_spline.point(40.0, 0.0)),
  )
  assert_eq(
    edges_out_by_id
    .get(edge_2.id())
    .map(fn(layout) { layout.splines[0].points[0] }),
    Some(@edge_spline.point(20.0, 0.0)),
  )
  assert_eq(
    edges_out_by_id
    .get(edge_3.id())
    .map(fn(layout) { layout.splines[0].points[0] }),
    Some(@edge_spline.point(1.0, 0.0)),
  )
}
