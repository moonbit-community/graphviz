///|
pub fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  compute_base_ranks : (
    (
      @cgraph.Graph,
      Array[@cgraph.Node],
      Array[@cgraph.Edge],
      Bool,
    ) -> (Map[String, Int])
  ),
  compute_cluster_ranks : (
    (
      @cgraph.Graph,
      Array[@cgraph.Node],
      Array[@cgraph.Edge],
      Bool,
    ) -> (Map[String, Int])
  ),
  back_weight_scale : Int,
  edge_is_constraint : ((@cgraph.Edge) -> Bool),
  edge_minlen : ((@cgraph.Edge) -> Int),
  edge_weight : ((@cgraph.Edge) -> Int),
  orient_edges_for_names : (
    (
      Array[String],
      Array[String],
      Array[String],
      Array[Bool],
    ) -> (Array[String], Array[String], Array[Bool])
  ),
) -> Map[String, Int] {
  let (cluster_graphs, top_clusters) = collect_top_clusters(source)
  if top_clusters.length() == 0 {
    return compute_base_ranks(source, nodes, edges, has_edge_labels)
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  let node_cluster = build_node_cluster_index(top_clusters, cluster_members)
  let (local_ranks, cluster_leaders) = compute_local_cluster_ranks_and_leaders(
    source,
    nodes,
    edges,
    top_clusters,
    cluster_graphs,
    cluster_members,
    (cluster_graph, cluster_nodes, cluster_edges) =>
      compute_cluster_ranks(
        cluster_graph,
        cluster_nodes,
        cluster_edges,
        has_edge_labels,
      ),
  )
  let leader_ranks = solve_clustered_leader_ranks(
    nodes,
    edges,
    node_cluster,
    cluster_leaders,
    local_ranks,
    has_edge_labels,
    back_weight_scale,
    edge_is_constraint,
    edge_minlen,
    edge_weight,
    orient_edges_for_names,
  )
  let ranks = project_clustered_node_ranks(
    nodes,
    node_cluster,
    cluster_leaders,
    local_ranks,
    leader_ranks,
  )
  apply_clustered_rank_postprocessing(source, nodes, ranks)
}
