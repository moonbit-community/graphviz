// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_node_positions_map defaults missing coordinates to zero" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")

  let x_positions : Map[String, Double] = Map::new()
  x_positions["a"] = 10.0
  let y_positions : Map[String, Double] = Map::new()
  y_positions["b"] = 20.0

  let positions = build_node_positions_map([a, b], x_positions, y_positions)

  assert_eq(positions.get("a"), Some({ x: 10.0, y: 0.0 }))
  assert_eq(positions.get("b"), Some({ x: 0.0, y: 20.0 }))
}
