// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "count_crossings_port_aware_with_inputs respects fixed external slots" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[1] = ["x", "y"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["x"] = 1
  ranks["y"] = 1
  ranks["ext"] = 1

  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let y = graph.node("y")
  let ext = graph.node("ext")
  let edges = [
    graph.edge(a, y),
    graph.edge(a, x),
    graph.edge(a, ext),
    graph.edge(b, x),
  ]

  let inputs = build_port_aware_crossing_inputs(
    groups,
    edges,
    ["a", "a", "a", "b"],
    ["y", "x", "ext", "x"],
    ranks~,
  )
  let crossings = count_crossings_port_aware_with_inputs(
    [0, 1],
    groups,
    ranks,
    ["a", "a", "a", "b"],
    ["y", "x", "ext", "x"],
    inputs,
    edge_tail_port_x=[2.0, 1.0, 5.0, 0.0],
    edge_head_port_x=[0.0, 0.0, 0.0, 4.0],
    fixed_order={ "ext": 3 },
  )

  assert_eq(crossings, 2)
}

///|
test "count_crossings_port_aware includes incoming local port crossings" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[1] = ["x"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["x"] = 1

  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let edges = [graph.edge(a, x), graph.edge(b, x)]

  let crossings = count_crossings_port_aware(
    groups,
    ranks,
    edges,
    ["a", "b"],
    ["x", "x"],
    edge_tail_port_x=[],
    edge_head_port_x=[2.0, 1.0],
  )

  assert_eq(crossings, 1)
}

///|
test "count_crossings_port_aware includes local port crossings for same node fanout" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["p"]
  groups[1] = ["x", "y"]

  let ranks : Map[String, Int] = Map::new()
  ranks["p"] = 0
  ranks["x"] = 1
  ranks["y"] = 1

  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let p = graph.node("p")
  let x = graph.node("x")
  let y = graph.node("y")
  let edges = [graph.edge(p, x), graph.edge(p, y)]

  let crossings = count_crossings_port_aware(
    groups,
    ranks,
    edges,
    ["p", "p"],
    ["x", "y"],
    edge_tail_port_x=[2.0, 1.0],
    edge_head_port_x=[],
  )

  assert_eq(crossings, 1)
}
