// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "finalize_routed_edges preserves input order for layouts that remain after remap" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, c)
  let edge_3 = graph.edge(b, c)
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  edges_out_by_id[edge_1.id()] = build_layout_edge(edge_1, 10.0)
  edges_out_by_id[edge_3.id()] = build_layout_edge(edge_3, 30.0)

  let output = finalize_routed_edges({
    edges: [edge_2, edge_1, edge_3],
    ranks: { "a": 0, "b": 1, "c": 2 },
    edges_out_by_id,
    edge_port_label_pos_fn: _ => None,
  })

  assert_eq(output.map(fn(layout) { layout.edge.id() }), [
    edge_1.id(),
    edge_3.id(),
  ])
}

///|
test "finalize_routed_edges remaps parallel layouts before output order and reapplies target attrs" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  edge_1.set_attr("headlabel", "head")
  edge_2.set_attr("taillabel", "tail")
  edge_2.set_attr("xlabel", "x")

  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  edges_out_by_id[edge_1.id()] = build_layout_edge(
    edge_1,
    10.0,
    head_label_pos=Some(@edge_spline.point(11.0, 1.0)),
    tail_label_pos=Some(@edge_spline.point(12.0, 2.0)),
    xlabel_pos=Some(@edge_spline.point(13.0, 3.0)),
  )
  edges_out_by_id[edge_2.id()] = build_layout_edge(
    edge_2,
    30.0,
    head_label_pos=Some(@edge_spline.point(31.0, 4.0)),
    tail_label_pos=Some(@edge_spline.point(32.0, 5.0)),
    xlabel_pos=Some(@edge_spline.point(33.0, 6.0)),
  )

  let output = finalize_routed_edges({
    edges: [edge_2, edge_1],
    ranks: { "a": 0, "b": 2 },
    edges_out_by_id,
    edge_port_label_pos_fn: input => {
      if input.is_head {
        Some(@edge_spline.point(input.spline.points[0].x, 99.0))
      } else {
        None
      }
    },
  })

  assert_eq(output.map(fn(layout) { layout.edge.id() }), [
    edge_2.id(),
    edge_1.id(),
  ])
  assert_eq(output[0].splines[0].points[0], @edge_spline.point(10.0, 0.0))
  assert_eq(output[0].head_label_pos, None)
  assert_eq(output[0].tail_label_pos, Some(@edge_spline.point(12.0, 2.0)))
  assert_eq(output[0].xlabel_pos, Some(@edge_spline.point(13.0, 3.0)))

  assert_eq(output[1].splines[0].points[0], @edge_spline.point(30.0, 0.0))
  assert_eq(output[1].head_label_pos, Some(@edge_spline.point(30.0, 99.0)))
  assert_eq(output[1].tail_label_pos, None)
  assert_eq(output[1].xlabel_pos, None)
}
