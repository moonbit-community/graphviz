// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "sorted_edges_for_routing prioritizes self edges then flat edges then regular edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let regular_edge = graph.edge(graph.node("a"), graph.node("b"))
  let flat_edge = graph.edge(graph.node("c"), graph.node("d"))
  let self_edge = graph.edge(graph.node("s"), graph.node("s"))
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[regular_edge.id()] = build_route_base(
    regular_edge,
    tail_rank=0,
    head_rank=3,
  )
  base_cache[flat_edge.id()] = build_route_base(
    flat_edge,
    is_flat_edge=true,
    tail_rank=0,
    head_rank=0,
  )
  base_cache[self_edge.id()] = build_route_base(
    self_edge,
    orig_tail_name="s",
    orig_head_name="s",
  )

  let ordered = sorted_edges_for_routing(
    [regular_edge, self_edge, flat_edge],
    base_cache,
    Map::new(),
  )

  assert_eq(ordered.map(fn(edge) { edge.id() }), [
    self_edge.id(),
    flat_edge.id(),
    regular_edge.id(),
  ])
}

///|
test "sorted_edges_for_routing compares equivalent endpoint sets by port before edge id" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let right_port_value = @cgraph.Port::{ name: Some("right"), compass: None }
  let left_port_value = @cgraph.Port::{ name: Some("left"), compass: None }
  let right_port = Some(right_port_value)
  let left_port = Some(left_port_value)
  let edge_right = graph.edge(a, b, tail_port=right_port_value)
  let edge_left = graph.edge(a, b, tail_port=left_port_value)
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[edge_right.id()] = build_route_base(
    edge_right,
    tail_port=right_port,
    tail_anchor=@edge_spline.point(8.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
  )
  base_cache[edge_left.id()] = build_route_base(
    edge_left,
    tail_port=left_port,
    tail_anchor=@edge_spline.point(2.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
  )

  let ordered = sorted_edges_for_routing(
    [edge_right, edge_left],
    base_cache,
    Map::new(),
  )

  assert_eq(ordered.map(fn(edge) { edge.id() }), [edge_left.id(), edge_right.id()])
}
