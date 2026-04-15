// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "adjust_edge_label_overlaps spreads sibling labels along the rank axis with tail padding" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let edge_1 = graph.edge(tail, graph.node("left"))
  let edge_2 = graph.edge(tail, graph.node("right"))
  let edge_layouts = [
    layout_edge(
      edge_1,
      straight_spline(),
      label_pos=Some(@edge_spline.point(5.0, 10.0)),
    ),
    layout_edge(
      edge_2,
      straight_spline(),
      label_pos=Some(@edge_spline.point(7.0, 20.0)),
    ),
  ]

  let adjusted = adjust_edge_label_overlaps(
    edge_layouts,
    10.0,
    @rankdir.RankDir::TB,
    _ => Some({ width: 6.0, height: 4.0 }),
    _ => Some(@edge_spline.point(0.0, 0.0)),
  )

  assert_eq(adjusted.updates.get(@edge_identity.edge_key(edge_1)), None)
  assert_eq(
    adjusted.updates.get(@edge_identity.edge_key(edge_2)),
    Some(@edge_spline.point(19.0, 20.0)),
  )
  assert_eq(adjusted.edges[0].label_pos, Some(@edge_spline.point(5.0, 10.0)))
  assert_eq(adjusted.edges[1].label_pos, Some(@edge_spline.point(19.0, 20.0)))
}
