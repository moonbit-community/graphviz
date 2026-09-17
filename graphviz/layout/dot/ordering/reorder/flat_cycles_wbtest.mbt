// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "flat cycle breaking merges an ordinary back edge into the ordering edge" {
  let (topology, matrix) = break_flat_cycles(
    [0],
    { 0: ["b", "a"] },
    { "a": 0, "b": 0 },
    { "b|a": true, "a|b": true },
    ["a"],
    ["b"],
  )
  @test.assert_eq(topology.get("a|b"), Some(false))
  @test.assert_eq(topology.get("b|a"), Some(true))
  @test.assert_eq(matrix.get("a|b"), None)
  @test.assert_eq(matrix.get("b|a"), Some(true))
}

///|
test "ordering back edges are deleted but retain their reversed matrix entry" {
  let (topology, matrix) = break_flat_cycles(
    [0],
    { 0: ["a", "b", "c"] },
    { "a": 0, "b": 0, "c": 0 },
    { "a|b": true, "b|c": true, "c|a": true },
    [],
    [],
  )
  @test.assert_eq(topology.get("c|a"), Some(false))
  @test.assert_eq(topology.get("a|c"), None)
  @test.assert_eq(matrix.get("a|c"), Some(true))
}

///|
test "ordinary flat edges precede appended ordering edges in postorder" {
  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 0 }
  let groups : Map[Int, Array[String]] = { 0: ["a", "b", "c"] }
  let (topology, _) = break_flat_cycles(
    [0],
    groups,
    ranks,
    { "a|c": true, "a|b": true },
    ["a"],
    ["b"],
  )
  @test.assert_eq(
    flat_reorder_rank_groups([0], groups, ranks, topology, false)[0],
    ["a", "c", "b"],
  )
}

///|
test "backward rank seeding does not count flat edges as ordinary outgoing edges" {
  let seeded = build_neighbor_rank_groups(
    [0, 1],
    { 0: ["p", "q"], 1: ["a", "b"] },
    ["p", "q", "a"],
    ["a", "b", "b"],
    { "p": 0, "q": 0, "a": 1, "b": 1 },
    { "a": 0, "p": 1, "b": 2, "q": 3 },
    Map([]),
    Map([]),
    1,
    graphviz_out_neighbors={ "p": ["a"], "q": ["b"], "a": ["b"] },
    graphviz_in_neighbors={ "a": ["p"], "b": ["q", "a"] },
  )
  @test.assert_eq(seeded[0], ["p", "q"])
  @test.assert_eq(seeded[1], ["a", "b"])
}

///|
test "flat cycle deletion preserves the swapped live adjacency order" {
  let ranks : Map[String, Int] = { "a": 0, "b": 0, "c": 0, "d": 0 }
  let groups : Map[Int, Array[String]] = { 0: ["a", "b", "c", "d"] }
  let (topology, _) = break_flat_cycles(
    [0],
    groups,
    ranks,
    { "a|b": true, "b|a": true, "b|c": true, "b|d": true },
    ["a", "b", "b", "b"],
    ["b", "a", "c", "d"],
  )
  @test.assert_eq(
    flat_reorder_rank_groups([0], groups, ranks, topology, false)[0],
    ["a", "b", "c", "d"],
  )
}
