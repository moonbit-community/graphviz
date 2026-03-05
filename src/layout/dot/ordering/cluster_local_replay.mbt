///|
/// Ordering domain: clustered local-replay execution kernel.

///|
/// Graphviz parity: cluster-local replay input keeps unmapped order-edge
/// snapshots, neighbor replay maps, vnode/rank overlays, and cluster traversal
/// metadata grouped before local reorder execution.
pub(all) struct ClusterLocalRankReplayInput {
  groups : Map[Int, Array[String]]
  graph : @cgraph.Graph
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  intercluster_keys : Map[String, String]
  flat_constraints : Map[String, Bool]
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  ranks : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  vnode_ranks : Map[String, Int]
  vnode_clusters : Map[String, String]
  vnode_sizes : Map[String, NodeSize]
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
pub fn run_cluster_local_rank_replay(
  input : ClusterLocalRankReplayInput,
) -> Unit {
  if input.cluster_order.length() == 0 {
    return ()
  }
  let cluster_graph_order =
    build_cluster_graph_order(
      input.graph,
      input.cluster_order,
      input.cluster_parents,
    )
  let cluster_graphs = cluster_graph_order.cluster_graphs
  let cluster_names = cluster_graph_order.cluster_names
  if cluster_graphs.length() == 0 {
    return ()
  }
  let fixed_positions = order_positions_from_groups(input.groups)
  let fixed_ranks = merge_ranks_with_vnodes(input.ranks, input.vnode_ranks)
  // Graphviz parity: cluster-local ND_out/ND_in maps keep raw graph
  // tail/head AGSEQ replay order for startpass=2 median anchors.
  let neighbor_sources =
    build_cluster_local_neighbor_sources(
      input.graph,
      input.graphviz_out_neighbors,
      input.graphviz_in_neighbors,
    )
  let dispatch_context : ClusterLocalReorderDispatchContext =
    {
      node_order: input.node_order,
      order_edges: input.order_edges,
      order_edge_tail: input.order_edge_tail,
      order_edge_head: input.order_edge_head,
      order_edge_tail_port_x: input.order_edge_tail_port_x,
      order_edge_head_port_x: input.order_edge_head_port_x,
      order_edge_tail_port_order: input.order_edge_tail_port_order,
      order_edge_head_port_order: input.order_edge_head_port_order,
      neighbor_sources,
      order_sizes: input.order_sizes,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      port_order_positions: input.port_order_positions,
      port_order_contrib: input.port_order_contrib,
      rank_same_groups: input.rank_same_groups,
      rank_same_order: input.rank_same_order,
      intercluster_keys: input.intercluster_keys,
      flat_constraints: input.flat_constraints,
      vnode_clusters: input.vnode_clusters,
      vnode_sizes: input.vnode_sizes,
      fixed_ranks,
      order_with_vnodes: input.order_with_vnodes,
    }
  reorder_cluster_rank_groups(
    cluster_names,
    cluster_graphs,
    input.groups,
    fixed_positions,
    dispatch_context,
  )
}
