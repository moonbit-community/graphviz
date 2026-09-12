// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "parallel edges with distinct port offsets retain their mincross multiplicity" {
  for variant in 0..<32 {
    let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
    let names = ["a", "b", "c", "d", "e", "f", "x", "y", "z"]
    let nodes = names.map(name => graph.node(name))
    let tails : Array[String] = []
    let heads : Array[String] = []
    let edges : Array[@cgraph.Edge] = []
    let offsets : Array[Double] = []
    let orders : Array[Double] = []
    let mut state = variant + 1
    for index in 0..<24 {
      state = (state * 17 + 23) % 97
      let tail = state % 6
      state = (state * 17 + 23) % 97
      let head = (tail / 3 + 1) * 3 + state % 3
      edges.push(graph.edge(nodes[tail], nodes[head]))
      tails.push(names[tail])
      heads.push(names[head])
      offsets.push(index.to_double())
      orders.push(0.75)
    }
    let run = (coalesce : Bool) => {
      reorder_rank_groups(
        [0, 1, 2],
        { 0: ["a", "b", "c"], 1: ["d", "e", "f"], 2: ["x", "y", "z"] },
        edges,
        tails,
        heads,
        offsets,
        offsets,
        orders,
        orders,
        {},
        {},
        {},
        {},
        {},
        {},
        {
          "a": 0,
          "b": 1,
          "c": 2,
          "d": 3,
          "e": 4,
          "f": 5,
          "x": 6,
          "y": 7,
          "z": 8,
        },
        {},
        18.0,
        false,
        {},
        {},
        {},
        {},
        {},
        coalesce_parallel_edges=coalesce,
      )
    }
    let unmerged = run(false)
    let coalesced = run(true)
    @test.assert_eq(coalesced[0], unmerged[0])
    @test.assert_eq(coalesced[1], unmerged[1])
    @test.assert_eq(coalesced[2], unmerged[2])
  }
}
