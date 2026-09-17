// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "zero internal crossings do not hide crossings at a cluster boundary" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tails = ["left", "right", "a", "b"]
  let heads = ["b", "a", "c", "c"]
  let edges = tails.mapi((index, tail) => {
    graph.edge(graph.node(tail), graph.node(heads[index]))
  })
  let ranks : Map[String, Int] = {
    "left": 0,
    "right": 0,
    "a": 1,
    "b": 1,
    "c": 2,
  }
  let local_groups : Map[Int, Array[String]] = { 1: ["a", "b"], 2: ["c"] }
  @test.assert_eq(
    count_crossings_port_aware(local_groups, ranks, edges, tails, heads),
    0,
  )
  let count_root_crossings = candidate => {
    let root_groups = @rank_groups.clone_rank_groups(candidate)
    root_groups[0] = ["left", "right"]
    count_crossings_port_aware(root_groups, ranks, edges, tails, heads)
  }
  @test.assert_eq(count_root_crossings(local_groups), 1)
  let ordered = reorder_rank_groups(
    [1, 2],
    local_groups,
    edges,
    tails,
    heads,
    [0.0, 0.0, 0.0, 0.0],
    [0.0, 0.0, 0.0, 0.0],
    [],
    [],
    {},
    {},
    {},
    {},
    {},
    {},
    { "a": 0, "b": 1, "c": 2 },
    {},
    18.0,
    false,
    {},
    {},
    {},
    {},
    {},
    fixed_positions={ "left": 0.0, "right": 1.0 },
    fixed_ranks=ranks,
    startpass=2,
    crossing_counter=Some(count_root_crossings),
  )
  @test.assert_eq(ordered[1], ["b", "a"])
  @test.assert_eq(count_root_crossings(ordered), 0)
}
