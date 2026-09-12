// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "downward concentration transfers incoming weight to the replacement outgoing edge" {
  let graph = ConcentrateFastGraph::new()
  let kept_in = graph.add_edge("p", "left", 2)
  let kept_out = graph.add_edge("left", "a", 3)
  let removed_in = graph.add_edge("p", "right", 5)
  let port : @cgraph.Port = { name: Some("field"), compass: None, }
  let removed_out = graph.add_edge("right", "b", 7, head_port=Some(port))
  graph.merge_node("left", "right", Down)
  assert_eq(graph.edges[kept_in].weight, 2)
  assert_eq(graph.edges[kept_out].weight, 3)
  assert_eq(graph.outgoing["left"], [kept_out, 4])
  assert_eq(graph.edges[4].weight, 12)
  assert_eq(graph.edges[4].head_port, Some(port))
  assert_eq(graph.edges[4].tail_port, None)
  @test.assert_eq(graph.copied_from.get(4), Some(removed_out))
  assert_eq(graph.edges[removed_in].to_virtual, Some(4))
  assert_eq(graph.edges[removed_out].to_virtual, Some(4))
  assert_eq(graph.incoming["right"].length(), 0)
  assert_eq(graph.outgoing["right"].length(), 0)
}

///|
test "upward concentration transfers outgoing weight to the replacement incoming edge" {
  let graph = ConcentrateFastGraph::new()
  let kept_in = graph.add_edge("a", "left", 2)
  let kept_out = graph.add_edge("left", "q", 3)
  let removed_in = graph.add_edge("b", "right", 5)
  let removed_out = graph.add_edge("right", "q", 7)
  graph.merge_node("left", "right", Up)
  assert_eq(graph.edges[kept_in].weight, 2)
  assert_eq(graph.edges[kept_out].weight, 3)
  assert_eq(graph.edges[4].tail, "b")
  assert_eq(graph.edges[4].head, "left")
  assert_eq(graph.edges[4].weight, 12)
  @test.assert_eq(graph.copied_from.get(4), Some(removed_in))
  assert_eq(graph.edges[removed_in].to_virtual, Some(4))
  assert_eq(graph.edges[removed_out].to_virtual, Some(4))
}

///|
test "merge weight follows redirects even after the intermediate edge is deleted" {
  let graph = ConcentrateFastGraph::new()
  let first = graph.add_edge("a", "b", 2)
  let middle = graph.add_edge("c", "d", 3)
  let last = graph.add_edge("e", "f", 5)
  graph.merge_weight(middle, last)
  graph.delete_edge(middle)
  graph.merge_weight(first, middle)
  assert_eq(graph.edges[middle].weight, 5)
  assert_eq(graph.edges[last].weight, 10)
}

///|
test "fast edge deletion swaps the last adjacency entry into the removed slot" {
  let graph = ConcentrateFastGraph::new()
  let first = graph.add_edge("a", "b", 1)
  let second = graph.add_edge("a", "c", 1)
  let third = graph.add_edge("a", "d", 1)
  graph.delete_edge(first)
  assert_eq(graph.outgoing["a"], [third, second])
}
