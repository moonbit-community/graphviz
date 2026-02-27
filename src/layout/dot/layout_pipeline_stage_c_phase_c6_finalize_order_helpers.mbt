///|
/// Stage C Phase C6 split: finalize-order group cleanup
/// and nlist creation helpers for Stage C outputs.

///|
/// Graphviz parity: final cleanup output preserves vnode-augmented groups and
/// finalized real-node groups in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_order_groups_with_cluster_remincross_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (next_ordered_with_vnodes, final_groups)
}

///|
/// Graphviz parity: cluster-rank reorder is skipped when root reorder exposes
/// a single-cluster single-anchor shape (one cluster bucket globally and at
/// most one clustered node per rank), so cluster-local ordering remains
/// anchored at the root-skeleton expansion position.
/// Do not change behavior without updating fixtures/tests.
fn has_single_cluster_rank_order_bucket(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
) -> Bool {
  let seen_clusters : Map[String, Bool] = Map::new()
  for _rank, order_map in cluster_rank_order {
    for cluster, _order in order_map {
      if cluster == "" {
        continue
      }
      seen_clusters[cluster] = true
      if seen_clusters.length() > 1 {
        return false
      }
    }
  }
  if seen_clusters.length() != 1 {
    return false
  }
  for _rank, names in final_groups {
    let mut cluster_nodes = 0
    for name in names {
      if cluster_key_or_empty(cluster_keys, name) != "" {
        cluster_nodes = cluster_nodes + 1
        if cluster_nodes > 1 {
          return false
        }
      }
    }
  }
  true
}

///|
/// Graphviz parity: cluster-enabled final groups apply cluster-rank ordering
/// then local-cluster bucket ordering before clustered ReMincross refinement.
/// Do not change behavior without updating fixtures/tests.
fn reorder_final_groups_for_cluster_remincross(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
  intercluster_keys : Map[String, String],
  local_cluster_order : Map[String, Int],
) -> Map[Int, Array[String]] {
  let reordered =
    if has_single_cluster_rank_order_bucket(
      final_groups,
      cluster_rank_order,
      cluster_keys,
    ) {
      final_groups
    } else {
      reorder_rank_groups_by_cluster_rank_order(
        final_groups,
        cluster_rank_order,
        cluster_keys,
      )
    }
  // Graphviz parity: order local subclusters within outer clusters by minrank/first order.
  reorder_groups_by_local_cluster_order(
    reordered,
    cluster_keys,
    intercluster_keys,
    local_cluster_order,
  )
  dot_trace_groups("cleaned_groups_post", reordered)
  reordered
}


///|
/// Graphviz parity: cluster-enabled finalize phase forwards cleaned groups
/// into clustered ReMincross refinement with Graphviz argument ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_finalize_order_groups_cluster_remincross_phase(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  final_groups : Map[Int, Array[String]],
  next_ordered_with_vnodes : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let dispatch_context =
    build_clustered_remincross_pass_dispatch_context(
      graph,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      order_with_vnodes,
      order_with_clusters,
      flat_rank_constraints,
      creation_order,
      edges_by_tail,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      next_ordered_with_vnodes,
      final_groups,
      real_nodes,
      graphviz_flip,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
    )
  run_clustered_remincross_pass(dispatch_context)
}


///|
/// Graphviz parity: cluster-enabled final cleanup phase applies cluster/local
/// ordering then forwards into clustered ReMincross refinement unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_finalize_order_groups_cluster_enabled_phase(
  dispatch_context : FinalizeOrderGroupsDispatchContext,
  cleaned_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let skip_cluster_rank_order_for_lr = false
  let final_groups =
    if skip_cluster_rank_order_for_lr {
      cleaned_groups
    } else {
      reorder_final_groups_for_cluster_remincross(
        cleaned_groups,
        dispatch_context.cluster_rank_order,
        dispatch_context.cluster_meta.cluster_keys,
        dispatch_context.cluster_meta.intercluster_keys,
        dispatch_context.local_cluster_order,
      )
    }
  run_finalize_order_groups_cluster_remincross_phase(
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_reversed,
    dispatch_context.edge_tail_port_x,
    dispatch_context.edge_head_port_x,
    dispatch_context.edge_tail_port_order,
    dispatch_context.edge_head_port_order,
    dispatch_context.ranks,
    dispatch_context.order_with_vnodes,
    true,
    dispatch_context.flat_rank_constraints,
    dispatch_context.creation_order,
    dispatch_context.edges_by_tail,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    final_groups,
    dispatch_context.ordered_with_vnodes,
    dispatch_context.real_nodes,
    dispatch_context.graphviz_flip,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
  )
}


///|
/// Graphviz parity: final cleanup pre-phase keeps only real nodes from ordered
/// groups before cluster/local reorder and clustered ReMincross refinement.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_order_groups_cleaned_groups_phase(
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let cleaned_groups =
    collect_real_only_rank_groups(order_rank_keys, ordered, real_nodes)
  dot_trace_groups("cleaned_groups_pre", cleaned_groups)
  cleaned_groups
}



///|
/// Graphviz parity: final cleanup dispatch phase keeps cluster-enabled and
/// non-clustered branches in Graphviz-equivalent control-flow ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_finalize_order_groups_dispatch_phase(
  dispatch_context : FinalizeOrderGroupsDispatchContext,
  cleaned_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  if dispatch_context.order_with_clusters {
    run_finalize_order_groups_cluster_enabled_phase(
      dispatch_context,
      cleaned_groups,
    )
  } else {
    (dispatch_context.ordered_with_vnodes, cleaned_groups)
  }
}

///|
/// Graphviz parity: final group cleanup context builder preserves clustered
/// cleanup payload ordering before branch dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_order_groups_dispatch_context(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> FinalizeOrderGroupsDispatchContext {
  {
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order,
    cluster_meta,
    local_cluster_order,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    real_nodes,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  }
}


///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
fn finalize_order_groups_with_cluster_remincross(
  dispatch_context : FinalizeOrderGroupsDispatchContext,
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let cleaned_groups =
    build_finalize_order_groups_cleaned_groups_phase(
      order_rank_keys,
      ordered,
      dispatch_context.real_nodes,
    )
  let (next_ordered_with_vnodes, final_groups) =
    run_finalize_order_groups_dispatch_phase(
      dispatch_context,
      cleaned_groups,
    )
  build_finalize_order_groups_with_cluster_remincross_output(
    next_ordered_with_vnodes,
    final_groups,
  )
}

///|
/// Graphviz parity: class2 nlist/vnode output keeps GD_nlist order and vnode
/// creation sequence unchanged after cluster-flip adjustment.
/// Do not change behavior without updating fixtures/tests.
fn build_nlist_order_and_vnode_creation_order_output(
  nlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> (Array[String], Array[String]) {
  (nlist_order, vnode_creation_order)
}

///|
/// Graphviz parity: class2 creation and decompose build GD_nlist from cluster
/// skeletons + real-node/vnode creation order, with cluster-flip adjustment.
/// Do not change behavior without updating fixtures/tests.
fn build_nlist_order_and_vnode_creation_order(
  cluster_skeleton_creation : Array[String],
  creation_order : Array[String],
  vnode_creation_by_tail : Map[String, Array[String]],
  edge_creation_order : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  has_clusters : Bool,
  cluster_keys : Map[String, String],
) -> (Array[String], Array[String]) {
  // Graphviz parity: class2 creates cluster skeletons first, then interleaves
  // real nodes with their edge vnodes in agfstnode order.
  let (order_creation, vnode_creation_order) =
    build_order_creation_with_vnodes(
      cluster_skeleton_creation,
      creation_order,
      vnode_creation_by_tail,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let order_creation_joined = order_creation.join(" ")
    println("order_creation \{order_creation_joined}")
  }
  // Graphviz parity: decompose DFS starts from agfstnode (creation) order
  // regardless of rankdir flip.
  // Do not change behavior without updating fixtures/tests.
  let nlist_tail_order =
    if has_clusters {
      creation_order
    } else {
      order_creation
    }
  let nlist_order_raw =
    build_graphviz_nlist_order_from_edges(
      nlist_tail_order,
      order_creation,
      edge_creation_order,
      flat_rank_constraints,
    )
  let nlist_order =
    adjust_nlist_order_for_cluster_flip(
      nlist_order_raw,
      graphviz_flip,
      has_clusters,
      cluster_keys,
    )
  trace_nlist_order_debug(nlist_order)
  build_nlist_order_and_vnode_creation_order_output(nlist_order, vnode_creation_order)
}
