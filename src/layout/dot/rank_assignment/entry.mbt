///|
pub fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  graph_has_cluster : ((@cgraph.Graph) -> Bool),
  compute_base_ranks : (
    (
      @cgraph.Graph,
      Array[@cgraph.Node],
      Array[@cgraph.Edge],
      Bool,
    ) -> (Map[String, Int])
  ),
  compute_clustered_ranks : (
    (
      @cgraph.Graph,
      Array[@cgraph.Node],
      Array[@cgraph.Edge],
      Bool,
    ) -> (Map[String, Int])
  ),
) -> Map[String, Int] {
  if graph_has_cluster(source) {
    return compute_clustered_ranks(source, nodes, edges, has_edge_labels)
  }
  compute_base_ranks(source, nodes, edges, has_edge_labels)
}
