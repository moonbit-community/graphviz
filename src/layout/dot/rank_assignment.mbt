///|
/// Graphviz parity: clustered path branch selection happens before non-cluster
/// base rank assignment, matching rank.c control flow.
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  _edge_reversed : Array[Bool],
) -> Map[String, Int] {
  if graph_has_cluster(source) {
    return compute_ranks_directed_with_clusters(
      source,
      nodes,
      edges,
      has_edge_labels,
    )
  }
  rank_assignment_compute_ranks_directed_base(
    source,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
  )
}

///|
/// Graphviz parity: base rank assignment keeps agfstout/agfstnode edge-order
/// driven decomposition behavior (rank.c + acyclic.c via fixtures).
/// Do not change behavior without updating fixtures/tests.
fn rank_assignment_compute_ranks_directed_base(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Int] {
  @rank_assignment.compute_ranks_directed_base(
    source,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_is_constraint,
    edge_minlen,
    edge_weight,
    (tail_order, edge_creation) => {
      build_graphviz_nlist_order_from_edges(
        tail_order,
        tail_order,
        edge_creation,
        Map::new(),
      )
    },
  )
}

///|
/// Rank assignment clustered path: keep cluster setup, solve, and projection
/// logic together so clustered ranking behavior is easier to follow.

///|
/// Graphviz parity: clustered rank assignment keeps non-cluster fallback path
/// and cluster-local/global solve sequence aligned to rank.c behavior.
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> Map[String, Int] {
  let (cluster_graphs, top_clusters) = @rank_assignment.collect_top_clusters(
    source,
  )
  if top_clusters.length() == 0 {
    let (base_tail, base_head, _base_reversed) =
      acyclic_edge_directions(source, nodes, edges)
    return rank_assignment_compute_ranks_directed_base(
      source,
      nodes,
      edges,
      has_edge_labels,
      base_tail,
      base_head,
    )
  }
  let cluster_members = @rank_assignment.collect_cluster_members(cluster_graphs)
  let node_cluster = @rank_assignment.build_node_cluster_index(
    top_clusters,
    cluster_members,
  )
  let (local_ranks, cluster_leaders) =
    @rank_assignment.compute_local_cluster_ranks_and_leaders(
      source,
      nodes,
      edges,
      top_clusters,
      cluster_graphs,
      cluster_members,
      (cluster_graph, cluster_nodes, cluster_edges) => {
        let (cluster_tail, cluster_head, cluster_reversed) =
          acyclic_edge_directions(cluster_graph, cluster_nodes, cluster_edges)
        compute_ranks_directed(
          cluster_graph,
          cluster_nodes,
          cluster_edges,
          has_edge_labels,
          cluster_tail,
          cluster_head,
          cluster_reversed,
        )
      },
    )
  let leader_ranks = @rank_assignment.solve_clustered_leader_ranks(
    nodes,
    edges,
    node_cluster,
    cluster_leaders,
    local_ranks,
    has_edge_labels,
    CL_BACK,
    edge_is_constraint,
    edge_minlen,
    edge_weight,
    acyclic_edge_directions_for_names,
  )
  let ranks = @rank_assignment.project_clustered_node_ranks(
    nodes,
    node_cluster,
    cluster_leaders,
    local_ranks,
    leader_ranks,
  )
  @rank_assignment.apply_clustered_rank_postprocessing(source, nodes, ranks)
}
