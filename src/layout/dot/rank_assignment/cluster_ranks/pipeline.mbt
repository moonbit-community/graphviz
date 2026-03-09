///|
/// Graphviz parity: clustered rank assignment first computes top-level cluster
/// locals, then solves leader ranks, then projects/postprocesses final node
/// ranks in the same high-level order as rank.c.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_clustered_ranks(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  back_weight_scale : Int,
  compute_recursive_ranks : (
    @cgraph.Graph,
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Bool,
    Int,
  ) -> Map[String, Int],
) -> Map[String, Int] {
  let top_cluster_data = collect_top_clusters(source)
  let cluster_graphs = top_cluster_data.cluster_graphs
  let top_clusters = top_cluster_data.top_clusters
  if top_clusters.length() == 0 {
    let acyclic_directions = @solver.acyclic_edge_directions_with_order(
      source, nodes, edges,
    )
    let tail = acyclic_directions.tail
    let head = acyclic_directions.head
    return @solver.compute_ranks_directed_base(
      source, nodes, edges, has_edge_labels, tail, head,
    )
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  let node_cluster = build_node_cluster_index(top_clusters, cluster_members)
  let local_cluster_ranks = compute_local_cluster_ranks_and_leaders(
    source,
    nodes,
    edges,
    top_clusters,
    cluster_graphs,
    cluster_members,
    (cluster_graph, cluster_nodes, cluster_edges) => {
      compute_recursive_ranks(
        cluster_graph, cluster_nodes, cluster_edges, has_edge_labels, back_weight_scale,
      )
    },
  )
  let local_ranks = local_cluster_ranks.local_ranks
  let cluster_leaders = local_cluster_ranks.cluster_leaders
  let leader_ranks = solve_clustered_leader_ranks(
    nodes,
    edges,
    node_cluster,
    cluster_leaders,
    local_ranks,
    has_edge_labels,
    back_weight_scale,
    (node_names, edge_tail, edge_head, edge_is_active) => {
      let directions = @solver.acyclic_edge_directions_for_names(
        node_names, edge_tail, edge_head, edge_is_active,
      )
      (directions.tail, directions.head, directions.reversed)
    },
  )
  let ranks = project_clustered_node_ranks(
    nodes, node_cluster, cluster_leaders, local_ranks, leader_ranks,
  )
  apply_clustered_rank_postprocessing(source, nodes, ranks)
}
