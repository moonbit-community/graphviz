// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "backward shadows preserve precreated parallel forward chains" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("concentrate", "true")
  let high = graph.node("high")
  let low = graph.node("low")
  let backward = graph.edge(high, low)
  let forward = graph.edge(low, high)
  let duplicate = graph.edge(low, high)
  let metadata = @order_graph.build_parallel_merge_metadata(
    [backward, forward, duplicate],
    { "high": 1, "low": 0 },
    {},
    (first, second) => first.tail().name() == second.tail().name(),
  )
  assert_eq(metadata.merged_edge_skip.length(), 0)
}

///|
test "parallel merges distinguish concentrated ordinary and cluster edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edges = [graph.edge(a, b), graph.edge(a, b), graph.edge(a, b)]
  let ranks : Map[String, Int] = { "a": 0, "b": 1 }
  let ordinary = @order_graph.build_parallel_merge_metadata(edges, ranks, {}, (
    _,
    _,
  ) => true)
  assert_eq(ordinary.merged_edge_skip.length(), 2)
  assert_eq(ordinary.merged_edge_weight_bonus.get(0), Some(2))
  graph.set_attr("concentrate", "true")
  let concentrated = @order_graph.build_parallel_merge_metadata(
    edges,
    ranks,
    {},
    (_, _) => true,
  )
  assert_eq(concentrated.merged_edge_skip.length(), 2)
  assert_eq(concentrated.merged_edge_weight_bonus.length(), 0)
  let crossing = @order_graph.build_parallel_merge_metadata(
    edges,
    ranks,
    { "a": "cluster_a" },
    (_, _) => true,
  )
  assert_eq(crossing.merged_edge_skip.length(), 2)
  assert_eq(crossing.merged_edge_weight_bonus.get(0), Some(2))
}

///|
test "parallel merging retains differing ports and labeled or flat edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let first = graph.edge(a, b)
  let second = graph.edge(a, b)
  let ranks : Map[String, Int] = { "a": 0, "b": 1 }
  let different = @order_graph.build_parallel_merge_metadata(
    [first, second],
    ranks,
    {},
    (_, _) => false,
  )
  assert_eq(different.merged_edge_skip.length(), 0)
  second.set_attr("label", "label")
  let labeled = @order_graph.build_parallel_merge_metadata(
    [first, second],
    ranks,
    {},
    (_, _) => true,
  )
  assert_eq(labeled.merged_edge_skip.length(), 0)
  let flat = @order_graph.build_parallel_merge_metadata(
    [first, graph.edge(a, b)],
    { "a": 0, "b": 0 },
    {},
    (_, _) => true,
  )
  assert_eq(flat.merged_edge_skip.length(), 0)
}

///|
test "reverse merging transfers the weight of a parallel representative once" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edges = [graph.edge(a, b), graph.edge(b, a), graph.edge(b, a)]
  let initial = @order_graph.build_parallel_merge_metadata(
    edges,
    { "a": 0, "b": 1 },
    {},
    (_, _) => true,
  )
  let merged = @order_graph.build_reverse_merge_metadata(
    {
      edges,
      edge_tail: ["a", "a", "a"],
      edge_head: ["b", "b", "b"],
      edge_excluded_from_reverse_merge: _ => false,
      edge_ports_equal: (_, _) => true,
    },
    initial_metadata=initial,
  )
  assert_eq(merged.merged_edge_skip.length(), 2)
  assert_eq(merged.merged_edge_weight_bonus.get(0), Some(2))
}

///|
test "reverse merge keeps same-named ports with different initial coordinates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("record_a")
  let b = graph.node("record_b")
  a.set_attr("shape", "record")
  b.set_attr("shape", "record")
  a.set_attr("label", "<p>short|<q>x")
  b.set_attr("label", "<p>a much wider field|<q>x")
  let p : @cgraph.Port = { name: Some("p"), compass: None, }
  let q : @cgraph.Port = { name: Some("q"), compass: None, }
  let forward = graph.edge(a, b, tail_port=p, head_port=q)
  let reversed = graph.edge(b, a, tail_port=p, head_port=q)
  let metadata = @order_graph.build_reverse_merge_metadata({
    edges: [forward, reversed],
    edge_tail: ["record_a", "record_a"],
    edge_head: ["record_b", "record_b"],
    edge_excluded_from_reverse_merge: _ => false,
    edge_ports_equal: @ports.build_initial_edge_port_comparator([a, b], Map([])),
  })
  assert_eq(metadata.merged_edge_skip.length(), 0)
  assert_eq(metadata.merged_edge_weight_bonus.length(), 0)
}

///|
test "build_reverse_merge_metadata folds reversed duplicates into forward reps" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  forward.set_attr("weight", "2")
  let reversed = graph.edge(b, a, name="rev")
  reversed.set_attr("weight", "3")

  let metadata = @order_graph.build_reverse_merge_metadata({
    edges: [forward, reversed],
    edge_tail: ["a", "a"],
    edge_head: ["b", "b"],
    edge_excluded_from_reverse_merge: _edge => false,
    edge_ports_equal: @ports.build_initial_edge_port_comparator([a, b], Map([])),
  })

  assert_eq(metadata.merged_edge_weight_bonus.get(0), Some(3))
  assert_eq(metadata.merged_edge_skip.get(1), Some(true))
  assert_eq(metadata.merged_edge_skip.get(0), None)
}
