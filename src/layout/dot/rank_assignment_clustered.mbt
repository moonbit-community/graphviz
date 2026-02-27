///|
/// Rank assignment clustered path split: keep clustered ranking flow isolated
/// so non-cluster and clustered entry logic can evolve independently.

///|
fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  let (cluster_graphs, top_clusters) = collect_top_clusters_for_rank_assignment(
    source,
  )
  if top_clusters.length() == 0 {
    let (base_tail, base_head, base_reversed) =
      acyclic_edge_directions(source, nodes, edges)
    return compute_ranks_directed_base(
      source,
      nodes,
      edges,
      has_edge_labels,
      base_tail,
      base_head,
      base_reversed,
    )
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  let node_cluster = build_node_cluster_index_for_rank_assignment(
    top_clusters,
    cluster_members,
  )
  let (local_ranks, cluster_leaders) =
    compute_local_cluster_ranks_and_leaders_for_rank_assignment(
      source,
      nodes,
      edges,
      has_edge_labels,
      top_clusters,
      cluster_graphs,
      cluster_members,
    )
  let leader_ranks = solve_clustered_leader_ranks_for_rank_assignment(
    nodes,
    edges,
    node_cluster,
    cluster_leaders,
    local_ranks,
    has_edge_labels,
  )
  let ranks = project_clustered_node_ranks_for_rank_assignment(
    nodes,
    node_cluster,
    cluster_leaders,
    local_ranks,
    leader_ranks,
  )
  apply_clustered_rank_postprocessing_for_rank_assignment(source, nodes, ranks)
}
