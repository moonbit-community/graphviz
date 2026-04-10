// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_reverse_merge_metadata folds reversed duplicates into forward reps" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  forward.set_attr("weight", "2")
  let reversed = graph.edge(b, a, name="rev")
  reversed.set_attr("weight", "3")

  let metadata = build_reverse_merge_metadata({
    edges: [forward, reversed],
    edge_tail: ["a", "a"],
    edge_head: ["b", "b"],
    edge_excluded_from_reverse_merge: _edge => false,
  })

  assert_eq(metadata.merged_edge_weight_bonus.get(0), Some(3))
  assert_eq(metadata.merged_edge_skip.get(1), Some(true))
  assert_eq(metadata.merged_edge_skip.get(0), None)
}
