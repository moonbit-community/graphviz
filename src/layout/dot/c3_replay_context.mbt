///|
/// Stage C Phase C3 split: clustered local-replay context and dispatch builders.

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalRankReplayContext {
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
/// Graphviz parity: root mincross output is replayed into clustered
/// build_ranks using unmapped order-edge snapshots before local cluster pass.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_rank_replay_context(
  dispatch_context : ClusteredDispatchContext,
  reorder_context : @ordering.OrderReorderContext,
  materialized : @ordering.OrderMaterializationData,
  order_sizes_out : Map[String, NodeSize],
) -> ClusterLocalRankReplayContext {
  let runtime_context = dispatch_context.runtime_context
  {
    graph: dispatch_context.graph,
    cluster_order: dispatch_context.cluster_meta.cluster_order,
    cluster_parents: dispatch_context.cluster_meta.cluster_parents,
    rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
    rank_same_order: dispatch_context.cluster_meta.rank_same_order,
    intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
    flat_constraints: dispatch_context.cluster_meta.flat_constraints,
    node_order: reorder_context.order_node_order,
    order_edges: materialized.order_edges_out_unmapped,
    order_edge_tail: materialized.order_edge_tail_out_unmapped,
    order_edge_head: materialized.order_edge_head_out_unmapped,
    order_edge_tail_port_x: materialized.order_edge_tail_port_x_unmapped,
    order_edge_head_port_x: materialized.order_edge_head_port_x_unmapped,
    order_edge_tail_port_order: materialized.order_edge_tail_port_order_unmapped,
    order_edge_head_port_order: materialized.order_edge_head_port_order_unmapped,
    graphviz_out_neighbors: materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: materialized.graphviz_in_neighbors,
    ranks: dispatch_context.ranks,
    order_sizes: order_sizes_out,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    vnode_ranks: runtime_context.vnode_info.vnode_ranks,
    vnode_clusters: runtime_context.vnode_info.vnode_clusters,
    vnode_sizes: runtime_context.vnode_info.vnode_sizes,
    order_with_vnodes: dispatch_context.reorder_setup.order_with_vnodes,
  }
}

///|
/// Graphviz parity: local replay dispatch context keeps one immutable payload
/// shared by all per-cluster reorder calls in traversal order.
fn build_cluster_replay_dispatch_context(
  replay_context : ClusterLocalRankReplayContext,
  neighbor_sources : @ordering.ClusterLocalNeighborSources,
  fixed_ranks : Map[String, Int],
) -> @ordering.ClusterLocalReorderDispatchContext {
  {
    node_order: replay_context.node_order,
    order_edges: replay_context.order_edges,
    order_edge_tail: replay_context.order_edge_tail,
    order_edge_head: replay_context.order_edge_head,
    order_edge_tail_port_x: replay_context.order_edge_tail_port_x,
    order_edge_head_port_x: replay_context.order_edge_head_port_x,
    order_edge_tail_port_order: replay_context.order_edge_tail_port_order,
    order_edge_head_port_order: replay_context.order_edge_head_port_order,
    neighbor_sources,
    order_sizes: replay_context.order_sizes,
    nodesep_pt: replay_context.nodesep_pt,
    has_edge_labels: replay_context.has_edge_labels,
    port_order_positions: replay_context.port_order_positions,
    port_order_contrib: replay_context.port_order_contrib,
    rank_same_groups: replay_context.rank_same_groups,
    rank_same_order: replay_context.rank_same_order,
    intercluster_keys: replay_context.intercluster_keys,
    flat_constraints: replay_context.flat_constraints,
    vnode_clusters: replay_context.vnode_clusters,
    vnode_sizes: replay_context.vnode_sizes,
    fixed_ranks,
    order_with_vnodes: replay_context.order_with_vnodes,
  }
}

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
fn run_cluster_local_rank_replay(
  groups : Map[Int, Array[String]],
  replay_context : ClusterLocalRankReplayContext,
) -> Unit {
  if replay_context.cluster_order.length() == 0 {
    return ()
  }
  let cluster_graph_order =
    @ordering.build_cluster_graph_order(
      replay_context.graph,
      replay_context.cluster_order,
      replay_context.cluster_parents,
    )
  let cluster_graphs = cluster_graph_order.cluster_graphs
  let cluster_names = cluster_graph_order.cluster_names
  if cluster_graphs.length() == 0 {
    return ()
  }
  let fixed_positions = @ordering.order_positions_from_groups(groups)
  let fixed_ranks =
    @ordering.merge_ranks_with_vnodes(
      replay_context.ranks,
      replay_context.vnode_ranks,
    )
  // Graphviz parity: cluster-local ND_out/ND_in maps keep raw graph
  // tail/head AGSEQ replay order for startpass=2 median anchors.
  let neighbor_sources =
    @ordering.build_cluster_local_neighbor_sources(
      replay_context.graph,
      replay_context.graphviz_out_neighbors,
      replay_context.graphviz_in_neighbors,
    )
  let dispatch_context =
    build_cluster_replay_dispatch_context(
      replay_context,
      neighbor_sources,
      fixed_ranks,
    )
  @ordering.reorder_cluster_rank_groups(
    cluster_names,
    cluster_graphs,
    groups,
    fixed_positions,
    dispatch_context,
  )
}

///|
/// Graphviz parity: local cluster replay applies only when clustered ordering
/// is enabled and uses pre-root unmapped order-graph snapshots.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_local_rank_replay_after_root(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : @ordering.RootAndClusterRanksOutput,
) -> Unit {
  if !dispatch_context.reorder_setup.order_with_clusters {
    return ()
  }
  let replay_context =
    build_cluster_local_rank_replay_context(
      dispatch_context,
      pre_root_stage.reorder_context,
      pre_root_stage.materialized,
      pre_root_stage.order_sizes_out,
    )
  run_cluster_local_rank_replay(root_cluster_stage.ordered, replay_context)
}
