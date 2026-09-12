// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "isolated leaders do not prevent optimizing connected slack chains" {
  let graph = @network_simplex.new_graph()
  for _ in 0..<6 {
    ignore(@network_simplex.add_node(graph, ""))
  }
  for index in 0..<4 {
    let slack = @network_simplex.add_node(
      graph,
      "",
      kind=@network_simplex.NodeKind::Slack,
    )
    ignore(@network_simplex.add_edge(graph, slack, index, 0, 10))
    ignore(@network_simplex.add_edge(graph, slack, index + 1, 1, 1))
  }
  solve_leader_components(graph)
  for index in 0..<5 {
    @test.assert_eq(graph.nodes[index].rank, index)
  }
  @test.assert_eq(graph.nodes[5].rank, 0)
}
