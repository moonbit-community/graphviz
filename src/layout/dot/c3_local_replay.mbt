///|
/// Stage C Phase C3 split: cluster-local replay pass orchestration
/// and shared dispatch payload for local cluster rank reordering.

///|
/// Graphviz parity: cluster-local reorder dispatch context keeps shared
/// arrays/maps together so each cluster pass reuses one immutable payload.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderDispatchContext {
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  neighbor_sources : ClusterLocalNeighborSources
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_meta : ClusterMetadata
  vnode_info : @routing.EdgeVnodeInfo
  fixed_ranks : Map[String, Int]
  empty_cluster_skeleton : Map[String, Bool]
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: each cluster-local reorder pass reuses global fixed slots,
/// but only mutates rank entries that belong to that cluster.
/// Do not change behavior without updating fixtures/tests.
fn reorder_cluster_rank_group(
  cluster : String,
  expanded_clusters : Map[String, Bool],
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  fixed_positions : Map[String, Double],
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> Unit {
  let local_context = match build_cluster_local_reorder_context(
    {
      cluster,
      cluster_graph,
      groups,
      node_order: dispatch_context.node_order,
      source_out_neighbors: dispatch_context.neighbor_sources.source_out_neighbors,
      vnode_clusters: dispatch_context.vnode_info.vnode_clusters,
      fixed_positions,
      order_with_vnodes: dispatch_context.order_with_vnodes,
    },
  ) {
    Some(value) => value
    None => return ()
  }
  let cluster_graph_edge_count = cluster_graph.edges().length()
  let input_context : ClusterLocalReorderInputBuildContext = {
    cluster_name: cluster,
    cluster_graph_edge_count,
    expanded_clusters,
    order_edges: dispatch_context.order_edges,
    order_edge_tail: dispatch_context.order_edge_tail,
    order_edge_head: dispatch_context.order_edge_head,
    order_edge_tail_port_x: dispatch_context.order_edge_tail_port_x,
    order_edge_head_port_x: dispatch_context.order_edge_head_port_x,
    order_edge_tail_port_order: dispatch_context.order_edge_tail_port_order,
    order_edge_head_port_order: dispatch_context.order_edge_head_port_order,
    neighbor_sources: dispatch_context.neighbor_sources,
    cluster_node_set: local_context.cluster_node_set,
    cluster_rank_keys: local_context.cluster_rank_keys,
    cluster_nodes: local_context.cluster_nodes,
    fixed_ranks: dispatch_context.fixed_ranks,
    order_sizes: dispatch_context.order_sizes,
    vnode_sizes: dispatch_context.vnode_info.vnode_sizes,
    intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
    flat_constraints: dispatch_context.cluster_meta.flat_constraints,
  }
  let input_phase_output =
    build_local_reorder_inputs(input_context)
  let reorder_output =
    run_cluster_rank_reorder(
      local_context,
      input_phase_output,
      dispatch_context,
    )
  if !reorder_output.has_internal_constraints {
    return ()
  }
  apply_cluster_rank_reorder_output(
    groups,
    local_context.cluster_rank_keys,
    reorder_output.ordered_cluster,
    local_context.cluster_node_set,
  )
}

///|
/// Graphviz parity: cluster-local reorder iterates clusters in deterministic
/// build order and applies one independent local pass per cluster.
/// Do not change behavior without updating fixtures/tests.
fn reorder_cluster_rank_groups(
  cluster_names : Array[String],
  cluster_graphs : Map[String, @cgraph.Graph],
  groups : Map[Int, Array[String]],
  fixed_positions : Map[String, Double],
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> Unit {
  let expanded_clusters : Map[String, Bool] = Map::new()
  let mut current_fixed_positions = fixed_positions
  for cluster in cluster_names {
    let cluster_graph = match cluster_graphs.get(cluster) {
      Some(value) => value
      None => continue
    }
    reorder_cluster_rank_group(
      cluster,
      expanded_clusters,
      cluster_graph,
      groups,
      current_fixed_positions,
      dispatch_context,
    )
    expanded_clusters[cluster] = true
    current_fixed_positions = @ordering.order_positions_from_groups(groups)
  }
}

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalRankReplayContext {
  graph : @cgraph.Graph
  cluster_meta : ClusterMetadata
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
  vnode_info : @routing.EdgeVnodeInfo
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
    cluster_meta: dispatch_context.cluster_meta,
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
    vnode_info: runtime_context.vnode_info,
    order_with_vnodes: dispatch_context.reorder_setup.order_with_vnodes,
  }
}

///|
/// Graphviz parity: local replay fixed-rank map overlays vnode ranks on top of
/// base node ranks before any per-cluster reorder calls.
fn build_cluster_replay_fixed_ranks(
  replay_context : ClusterLocalRankReplayContext,
) -> Map[String, Int] {
  let fixed_ranks : Map[String, Int] = Map::new()
  for name, rank in replay_context.ranks {
    fixed_ranks[name] = rank
  }
  for name, rank in replay_context.vnode_info.vnode_ranks {
    fixed_ranks[name] = rank
  }
  fixed_ranks
}

///|
/// Graphviz parity: local replay neighbor sources preserve order-graph ND_out/
/// ND_in and append raw AGSEQ traversal maps for median fallback.
fn build_cluster_replay_neighbor_sources(
  replay_context : ClusterLocalRankReplayContext,
) -> ClusterLocalNeighborSources {
  // Graphviz parity: cluster-local ND_out/ND_in maps keep raw graph
  // tail/head AGSEQ replay order for startpass=2 median anchors.
  let raw_graphviz_neighbors = build_raw_graphviz_neighbor_maps(replay_context.graph)
  {
    source_out_neighbors: replay_context.graphviz_out_neighbors,
    source_in_neighbors: replay_context.graphviz_in_neighbors,
    raw_out_neighbors: raw_graphviz_neighbors.out_neighbors,
    raw_in_neighbors: raw_graphviz_neighbors.in_neighbors,
  }
}

///|
/// Graphviz parity: local replay dispatch context keeps one immutable payload
/// shared by all per-cluster reorder calls in traversal order.
fn build_cluster_replay_dispatch_context(
  replay_context : ClusterLocalRankReplayContext,
  neighbor_sources : ClusterLocalNeighborSources,
  fixed_ranks : Map[String, Int],
) -> ClusterLocalReorderDispatchContext {
  let empty_cluster_skeleton : Map[String, Bool] = Map::new()
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
    cluster_meta: replay_context.cluster_meta,
    vnode_info: replay_context.vnode_info,
    fixed_ranks,
    empty_cluster_skeleton,
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
  if replay_context.cluster_meta.cluster_order.length() == 0 {
    return ()
  }
  let cluster_graph_order =
    build_cluster_graph_order(
      replay_context.graph,
      replay_context.cluster_meta.cluster_order,
      replay_context.cluster_meta.cluster_parents,
    )
  let cluster_graphs = cluster_graph_order.cluster_graphs
  let cluster_names = cluster_graph_order.cluster_names
  if cluster_graphs.length() == 0 {
    return ()
  }
  let fixed_positions = @ordering.order_positions_from_groups(groups)
  let fixed_ranks = build_cluster_replay_fixed_ranks(replay_context)
  let neighbor_sources = build_cluster_replay_neighbor_sources(replay_context)
  let dispatch_context =
    build_cluster_replay_dispatch_context(
      replay_context,
      neighbor_sources,
      fixed_ranks,
    )
  reorder_cluster_rank_groups(
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
