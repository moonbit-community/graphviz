// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "compass_port_point_on_shape clips box compass anchors" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let box = graph.node("box")
  box.set_attr("shape", "box")
  box.set_attr("penwidth", "0")

  let east_anchor = compass_port_point_on_shape(
    box,
    point(0.0, 0.0),
    @node_primitives.node_size_from_points(100.0, 60.0),
    @cgraph.Compass::E,
    @rankdir.RankDir::TB,
  )
  assert_eq(east_anchor, point(50.0, 0.0))

  let north_anchor = compass_port_point_on_shape(
    box,
    point(0.0, 0.0),
    @node_primitives.node_size_from_points(100.0, 60.0),
    @cgraph.Compass::N,
    @rankdir.RankDir::TB,
  )
  assert_eq(north_anchor, point(0.0, 30.0))
}
