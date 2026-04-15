// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
test "edge_swap_ends uses rank first then order index with missing values defaulting to zero" {
  let ranks : Map[String, Int] = { "a": 2, "b": 1, "c": 1 }
  let order_index : Map[String, Int] = { "b": 0, "c": 3 }

  assert_true(edge_swap_ends("a", "b", ranks, order_index))
  assert_false(edge_swap_ends("b", "a", ranks, order_index))
  assert_true(edge_swap_ends("c", "b", ranks, order_index))
  assert_false(edge_swap_ends("b", "c", ranks, order_index))
  assert_false(edge_swap_ends("missing_a", "missing_b", Map::new(), Map::new()))
}

///|
test "reverse_spline swaps markers and reverses point order" {
  let spline : @geom.Spline = {
    start: Some({ x: -1.0, y: 0.0 }),
    end: Some({ x: 9.0, y: 1.0 }),
    points: [{ x: 0.0, y: 0.0 }, { x: 3.0, y: 4.0 }, { x: 6.0, y: 8.0 }],
  }

  let reversed = reverse_spline(spline)
  assert_eq(reversed.start, spline.end)
  assert_eq(reversed.end, spline.start)
  assert_eq(reversed.points, [
    { x: 6.0, y: 8.0 },
    { x: 3.0, y: 4.0 },
    { x: 0.0, y: 0.0 },
  ])
}

///|
test "parallel edge keys are unordered and sameport grouping keeps marks separate" {
  let east : @cgraph.Port = {
    name: Some("p"),
    compass: Some(@cgraph.Compass::E),
  }
  let west : @cgraph.Port = {
    name: Some("q"),
    compass: Some(@cgraph.Compass::W),
  }
  let key1 = edge_parallel_key("tail", "head", Some(east), Some(west))
  let key2 = edge_parallel_key("head", "tail", Some(west), Some(east))
  assert_eq(key1, key2)
  assert_eq(key1, "head|q:w|tail|p:e")

  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let plain = graph.edge(a, b, tail_port=east, head_port=west)
  let marked = graph.edge(a, b, name="marked", tail_port=east, head_port=west)
  marked.set_attr("sametail", "g")

  assert_false(edge_has_sameport_mark(plain))
  assert_true(edge_has_sameport_mark(marked))
  assert_eq(edge_parallel_group_key(plain), "a|p:e|b|q:w|plain")
  assert_eq(edge_parallel_group_key(marked), "a|p:e|b|q:w|sameport")
}

///|
test "edge_dir_attr_key lowercases dir and defaults to forward" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)
  assert_eq(edge_dir_attr_key(edge), "forward")
  edge.set_attr("dir", "BoTh")
  assert_eq(edge_dir_attr_key(edge), "both")
}

///|
test "dot adjustment helpers rewrite the expected control points only" {
  let points : Array[@geom.Point] = [
    { x: 0.0, y: 0.0 },
    { x: 5.0, y: 1.0 },
    { x: 8.0, y: 2.0 },
    { x: 10.0, y: 3.0 },
  ]
  let head_size = @node_primitives.node_size_from_points(12.0, 6.0)
  let inter = adjust_intercluster_dots(
    points,
    { x: 0.0, y: 0.0 },
    { x: 20.0, y: 10.0 },
    head_size,
    8.0,
  )
  assert_eq(inter[0], points[0])
  assert_eq(inter[1], points[1])
  assert_eq(inter[2], { x: 10.0, y: 5.0 })
  assert_eq(inter[3], points[3])

  let intra_even = adjust_intracluster_dots(points)
  assert_eq(intra_even[0], points[0])
  assert_eq(intra_even[1], { x: 5.0, y: 1.0 })
  assert_eq(intra_even[2], { x: 8.0, y: 1.6 })
  assert_eq(intra_even[3], points[3])

  let odd_points : Array[@geom.Point] = [
    { x: 0.0, y: 0.0 },
    { x: 2.0, y: 4.0 },
    { x: 4.0, y: 10.0 },
    { x: 6.0, y: 4.0 },
    { x: 8.0, y: 0.0 },
  ]
  let intra_odd = adjust_intracluster_dots(odd_points)
  assert_eq(intra_odd[2].x, 4.0)
  assert_close(intra_odd[2].y, 2.0)
}
