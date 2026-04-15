// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_path_adjacency preserves parallel multiplicity and expands vnode chains" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let direct0 = graph.edge(a, b)
  let direct1 = graph.edge(a, b)
  let chained = graph.edge(b, c)

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(chained)] = ["v1", "v2"]

  let adjacency = build_path_adjacency(
    [direct0, direct1, chained],
    edge_vnodes,
    [],
    [],
  )

  assert_eq(adjacency.out_edges.get("a").unwrap_or([]), ["b", "b"])
  assert_eq(adjacency.out_edges.get("b").unwrap_or([]), ["v1"])
  assert_eq(adjacency.out_edges.get("v1").unwrap_or([]), ["v2"])
  assert_eq(adjacency.out_edges.get("v2").unwrap_or([]), ["c"])
  assert_eq(adjacency.in_edges.get("b").unwrap_or([]), ["a", "a"])
  assert_eq(adjacency.in_edges.get("v1").unwrap_or([]), ["b"])
  assert_eq(adjacency.in_edges.get("v2").unwrap_or([]), ["v1"])
  assert_eq(adjacency.in_edges.get("c").unwrap_or([]), ["v2"])
}

///|
test "build_path_adjacency uses overridden tail and head order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  let adjacency = build_path_adjacency([edge], Map::new(), ["b"], ["a"])

  assert_eq(adjacency.out_edges.get("b").unwrap_or([]), ["a"])
  assert_eq(adjacency.in_edges.get("a").unwrap_or([]), ["b"])
  guard adjacency.out_edges.get("a") is None else {
    fail("expected overridden tail/head to suppress original direction")
  }
}

///|
test "pathplan_bounds merges vnode positions and expands each rank by route width" {
  let positions : Map[String, @geom.Point] = Map::new()
  positions["a"] = { x: 10.0, y: 0.0 }
  positions["b"] = { x: 40.0, y: 0.0 }

  let vnode_positions : Map[String, @geom.Point] = Map::new()
  vnode_positions["v"] = { x: -20.0, y: 0.0 }

  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths(2.0, 4.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths(5.0, 1.0)

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["v"] = @node_primitives.vnode_size_from_widths(3.0, 7.0)

  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  x_groups[1] = ["v"]

  let bounds = pathplan_bounds(
    positions, vnode_positions, sizes, vnode_sizes, x_groups,
  )
  assert_eq(bounds.left, -39.0)
  assert_eq(bounds.right, 73.0)
}

///|
test "pathplan_bounds returns zero bounds for empty rank groups" {
  let bounds = pathplan_bounds(
    Map::new(),
    Map::new(),
    Map::new(),
    Map::new(),
    Map::new(),
  )
  assert_eq(bounds.left, 0.0)
  assert_eq(bounds.right, 0.0)
}
