// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Graphviz parity: clustered path branch selection happens before non-cluster
/// base rank assignment, matching rank.c control flow.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  back_weight_scale : Int,
) -> Map[String, Int] {
  if @cluster_graph.graph_has_cluster(source) {
    return @cluster_ranks.compute_clustered_ranks(
      source, nodes, edges, has_edge_labels, back_weight_scale, compute_ranks_directed_with_clusters,
    )
  }
  @solver.compute_ranks_directed_base(
    source, nodes, edges, has_edge_labels, edge_tail, edge_head,
  )
}

///|
/// Convenience entry for callers that want internal edge orientation.
pub fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  back_weight_scale : Int,
) -> Map[String, Int] {
  let acyclic_directions = @solver.acyclic_edge_directions_with_order(
    source, nodes, edges,
  )
  let edge_tail = acyclic_directions.tail
  let edge_head = acyclic_directions.head
  compute_ranks_directed(
    source, nodes, edges, has_edge_labels, edge_tail, edge_head, back_weight_scale,
  )
}
