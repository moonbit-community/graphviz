// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_rank_groups assigns missing ranks to zero and preserves node order within each rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 2
  ranks["c"] = 2

  let groups = build_rank_groups([a, b, c], ranks)

  let zero_group = match groups.get(0) {
    Some(value) => value
    None => fail("missing zero rank group")
  }
  let two_group = match groups.get(2) {
    Some(value) => value
    None => fail("missing rank 2 group")
  }
  assert_eq(zero_group, ["b"])
  assert_eq(two_group, ["a", "c"])
}

///|
test "compute_rank_data assembles rank groups gaps and self-edge label heights" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let ab = graph.edge(a, b)
  ab.set_attr("minlen", "2")
  let cc = graph.edge(c, c)
  cc.set_attr("fixture_id", "self")

  let data = compute_rank_data(
    make_rank_data_input(graph, [a, b, c], [ab, cc], false, CL_BACK, edge => {
      match edge.get_attr("fixture_id") {
        Some("self") => 12.0
        _ => 0.0
      }
    }),
  )

  let zero_group = match data.groups.get(0) {
    Some(value) => value
    None => fail("missing zero rank group")
  }
  let two_group = match data.groups.get(2) {
    Some(value) => value
    None => fail("missing rank 2 group")
  }

  assert_eq(data.edge_tail, ["a", "c"])
  assert_eq(data.edge_head, ["b", "c"])
  assert_eq(data.edge_reversed, [false, false])
  assert_eq(data.ranks.get("a"), Some(0))
  assert_eq(data.ranks.get("b"), Some(2))
  assert_eq(data.ranks.get("c"), Some(0))
  assert_eq(zero_group, ["a", "c"])
  assert_eq(two_group, ["b"])
  assert_eq(data.rank_keys, [0, 2])
  assert_eq(data.all_ranks, [0, 1, 2])
  assert_eq(data.self_edge_labels.get("c"), Some(6.0))
}
