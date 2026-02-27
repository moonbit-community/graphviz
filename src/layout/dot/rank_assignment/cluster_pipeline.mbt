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
  _edge_reversed : Array[Bool],
  graph_has_cluster : ((@cgraph.Graph) -> Bool),
  edge_minlen : ((@cgraph.Edge) -> Int),
  edge_weight : ((@cgraph.Edge) -> Int),
  back_weight_scale : Int,
) -> Map[String, Int] {
  if graph_has_cluster(source) {
    return compute_ranks_directed_with_clusters_impl(
      source,
      nodes,
      edges,
      has_edge_labels,
      graph_has_cluster,
      edge_minlen,
      edge_weight,
      back_weight_scale,
    )
  }
  compute_ranks_directed_base(
    source,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_minlen,
    edge_weight,
  )
}

///|
/// Convenience entry for callers that want internal edge orientation.
pub fn compute_ranks_directed_with_clusters(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  graph_has_cluster : ((@cgraph.Graph) -> Bool),
  edge_minlen : ((@cgraph.Edge) -> Int),
  edge_weight : ((@cgraph.Edge) -> Int),
  back_weight_scale : Int,
) -> Map[String, Int] {
  let (edge_tail, edge_head, edge_reversed) =
    acyclic_edge_directions(source, nodes, edges)
  compute_ranks_directed(
    source,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_reversed,
    graph_has_cluster,
    edge_minlen,
    edge_weight,
    back_weight_scale,
  )
}

///|
/// Graphviz parity: clustered rank assignment keeps non-cluster fallback path
/// and cluster-local/global solve sequence aligned to rank.c behavior.
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_directed_with_clusters_impl(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  graph_has_cluster : ((@cgraph.Graph) -> Bool),
  edge_minlen : ((@cgraph.Edge) -> Int),
  edge_weight : ((@cgraph.Edge) -> Int),
  back_weight_scale : Int,
) -> Map[String, Int] {
  compute_clustered_ranks(
    source,
    nodes,
    edges,
    has_edge_labels,
    (graph, graph_nodes, graph_edges, graph_has_edge_labels) => {
      let (tail, head, _reversed) =
        acyclic_edge_directions(graph, graph_nodes, graph_edges)
      compute_ranks_directed_base(
        graph,
        graph_nodes,
        graph_edges,
        graph_has_edge_labels,
        tail,
        head,
        edge_minlen,
        edge_weight,
      )
    },
    (graph, graph_nodes, graph_edges, graph_has_edge_labels) => {
      let (tail, head, reversed) =
        acyclic_edge_directions(graph, graph_nodes, graph_edges)
      compute_ranks_directed(
        graph,
        graph_nodes,
        graph_edges,
        graph_has_edge_labels,
        tail,
        head,
        reversed,
        graph_has_cluster,
        edge_minlen,
        edge_weight,
        back_weight_scale,
      )
    },
    back_weight_scale,
    edge_minlen,
    edge_weight,
  )
}

///|
fn compute_clustered_ranks(
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
  edge_minlen : ((@cgraph.Edge) -> Int),
  edge_weight : ((@cgraph.Edge) -> Int),
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
    edge_minlen,
    edge_weight,
    acyclic_edge_directions_for_names,
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
