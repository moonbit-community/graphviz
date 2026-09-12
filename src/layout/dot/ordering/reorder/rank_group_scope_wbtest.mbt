// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "rank installation excludes unranked neighbors from enclosing graph hints" {
  for pass in [0, 1] {
    let ordered = build_neighbor_rank_groups(
      [0, 1],
      { 0: ["a"], 1: ["b"] },
      ["a"],
      ["b"],
      { "a": 0, "b": 1 },
      { "a": 0, "b": 1 },
      {},
      {},
      pass,
      graphviz_out_neighbors={ "a": ["unranked", "b"] },
      graphviz_in_neighbors={ "b": ["unranked", "a"] },
    )
    @test.assert_eq(ordered.get(0), Some(["a"]))
    @test.assert_eq(ordered.get(1), Some(["b"]))
  }
}
