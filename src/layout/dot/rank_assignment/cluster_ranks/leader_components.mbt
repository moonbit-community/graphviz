// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// rank.c/rank1 solves each connected component independently. A disconnected
/// graph cannot form the spanning tree required by network simplex.
fn solve_leader_components(graph : @network_simplex.NsGraph) -> Unit {
  let seen = Array::make(graph.nodes.length(), false)
  for start in 0..<graph.nodes.length() {
    guard !seen[start] else { continue }
    let component = [start]
    seen[start] = true
    for next = 0; next < component.length(); next = next + 1 {
      let index = component[next]
      let node = graph.nodes[index]
      for edge_index in [..node.out_edges, ..node.in_edges] {
        let edge = graph.edges[edge_index]
        let neighbor = if edge.tail == index { edge.head } else { edge.tail }
        guard !seen[neighbor] else { continue }
        seen[neighbor] = true
        component.push(neighbor)
      }
    }
    component.sort_by((a, b) => a - b)
    let subgraph = @network_simplex.new_graph()
    let indices : Map[Int, Int] = Map([])
    let component_edges : Array[Int] = []
    for index in component {
      indices[index] = @network_simplex.add_node(
        subgraph,
        "",
        kind=graph.nodes[index].kind,
      )
      for edge_index in graph.nodes[index].out_edges {
        component_edges.push(edge_index)
      }
    }
    component_edges.sort_by((a, b) => a - b)
    for edge_index in component_edges {
      let edge = graph.edges[edge_index]
      let tail = indices[edge.tail]
      let head = indices[edge.head]
      ignore(
        @network_simplex.add_edge(
          subgraph,
          tail,
          head,
          edge.minlen,
          edge.weight,
        ),
      )
    }
    guard @network_simplex.network_simplex_pre_balance(subgraph, 0x7fffffff) else {
      panic()
    }
    let minimum = for index = 0, minimum = 0x7fffffff {
      guard index < subgraph.nodes.length() else { break minimum }
      let node = subgraph.nodes[index]
      continue index + 1,
        if node.kind == @network_simplex.NodeKind::Normal && node.rank < minimum {
          node.rank
        } else {
          minimum
        }
    }
    for original, index in indices {
      graph.nodes[original].rank = subgraph.nodes[index].rank - minimum
    }
  }
}
