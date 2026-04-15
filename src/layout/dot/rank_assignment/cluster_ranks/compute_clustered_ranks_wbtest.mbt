// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn base_cluster_pipeline_ranks(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  back_weight_scale : Int,
) -> Map[String, Int] {
  ignore(back_weight_scale)
  let directions = @solver.acyclic_edge_directions_with_order(
    graph, nodes, edges,
  )
  @solver.compute_ranks_directed_base(
    graph,
    nodes,
    edges,
    has_edge_labels,
    directions.tail,
    directions.head,
  )
}

///|
test "compute_clustered_ranks projects local cluster ranks into the outer solve" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster0")
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  ignore(cluster.node("a"))
  ignore(cluster.node("b"))
  let ab = graph.edge(a, b)
  ab.set_attr("minlen", "1")
  let ac = graph.edge(a, c)
  ac.set_attr("minlen", "1")

  let ranks = compute_clustered_ranks(
    graph,
    [a, b, c],
    [ab, ac],
    false,
    10,
    base_cluster_pipeline_ranks,
  )

  assert_eq(ranks.get("a"), Some(0))
  assert_eq(ranks.get("b"), Some(1))
  assert_eq(ranks.get("c"), Some(1))
}
