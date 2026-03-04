///|
/// Stage C Phase C6 split: cluster-rank finalize, finalize-order group cleanup,
/// and nlist creation helpers for Stage C outputs.

///|
/// Graphviz parity: clustered ReMincross cleanup reorder executes startpass=2
/// with coalesced-parallel mode on rematerialized edge arrays.
fn run_remincross_cleanup_reorder(
  reorder_inputs : @ordering.ReMincrossCleanupReorderInputs,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    reorder_inputs.rem_rank_keys,
    reorder_inputs.rem_groups,
    reorder_inputs.rem_edges_out,
    reorder_inputs.rem_edge_tail_out,
    reorder_inputs.rem_edge_head_out,
    reorder_inputs.rem_edge_tail_port_x,
    reorder_inputs.rem_edge_head_port_x,
    reorder_inputs.rem_edge_tail_port_order,
    reorder_inputs.rem_edge_head_port_order,
    reorder_inputs.rem_parents,
    reorder_inputs.rem_children,
    reorder_inputs.rem_cluster_keys,
    reorder_inputs.rank_same_groups,
    reorder_inputs.rank_same_order,
    reorder_inputs.rem_edge_order,
    reorder_inputs.rem_node_order,
    reorder_inputs.rem_sizes,
    reorder_inputs.nodesep_pt,
    reorder_inputs.has_edge_labels,
    reorder_inputs.port_order_positions,
    reorder_inputs.port_order_contrib,
    Map::new(),
    Map::new(),
    reorder_inputs.rem_flat_constraints,
    graphviz_flip=reorder_inputs.graphviz_flip,
    // Graphviz parity: ReMincross counts parallel chain segments once
    // with summed xpenalty before startpass=2 transposition.
    coalesce_parallel_edges=true,
    startpass=2,
    remincross_mode=true,
  )
}

///|
/// Graphviz parity: clustered finalize pass context keeps pre-root creation
/// order and cluster/vnode snapshots unchanged before ReMincross execution.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_pass_context(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : @ordering.RootAndClusterRanksOutput,
  root_tail_order_override : Array[String]?,
) -> @ordering.ReMincrossPassBuildContext {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  {
    ratio: dispatch_context.graph.get_attr("ratio").unwrap_or_default(),
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    edge_reversed: dispatch_context.edge_reversed,
    edge_tail_port_x: dispatch_context.edge_port_data.edge_tail_port_x,
    edge_head_port_x: dispatch_context.edge_port_data.edge_head_port_x,
    edge_tail_port_order: dispatch_context.edge_port_data.edge_tail_port_order,
    edge_head_port_order: dispatch_context.edge_port_data.edge_head_port_order,
    ranks: dispatch_context.ranks,
    order_with_vnodes: reorder_setup.order_with_vnodes,
    creation_order: pre_root_stage.reorder_context.creation_order,
    edges_by_tail: dispatch_context.class2_data.edges_by_tail,
    cluster_order: dispatch_context.cluster_meta.cluster_order,
    cluster_keys: dispatch_context.cluster_meta.cluster_keys,
    intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
    cluster_parents: dispatch_context.cluster_meta.cluster_parents,
    cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
    cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
    cluster_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
    rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
    rank_same_order: dispatch_context.cluster_meta.rank_same_order,
    edge_vnodes: runtime_context.vnode_info.edge_vnodes,
    vnode_ranks: runtime_context.vnode_info.vnode_ranks,
    vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
    vnode_sizes: runtime_context.vnode_info.vnode_sizes,
    order_sizes: dispatch_context.order_sizes,
    rank_same_constraints: runtime_context.rank_same_constraints,
    ordered_with_vnodes: root_cluster_stage.ordered_with_vnodes,
    real_nodes: runtime_context.real_nodes,
    root_tail_order_override,
    root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
    graphviz_flip: reorder_setup.graphviz_flip,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
  }
}

///|
/// Graphviz parity: clustered finalize local cluster reorder uses captured
/// local-cluster traversal order after cluster-rank bucket replay.
fn apply_local_cluster_order(
  dispatch_context : ClusteredDispatchContext,
  groups : Map[Int, Array[String]],
) -> Unit {
  let runtime_context = dispatch_context.runtime_context
  reorder_by_local_cluster(
    groups,
    dispatch_context.cluster_meta.cluster_keys,
    dispatch_context.cluster_meta.intercluster_keys,
    runtime_context.local_cluster_order,
  )
}

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
fn finalize_order_groups(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : @ordering.RootAndClusterRanksOutput,
  root_tail_order_override : Array[String]?,
  cluster_rank_order : Map[Int, Map[String, Int]],
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let remincross_context =
    build_remincross_pass_context(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage,
      root_tail_order_override,
    )
  let finalize_output =
    @ordering.run_clustered_finalize_order_groups(
      {
        order_with_clusters: reorder_setup.order_with_clusters,
        order_rank_keys: pre_root_stage.reorder_context.order_rank_keys,
        ordered: root_cluster_stage.ordered,
        cluster_rank_order,
        remincross_context,
      },
      (groups) =>
        apply_local_cluster_order(
          dispatch_context,
          groups,
        ),
      build_vnode_order_keys,
      capture_remincross_snapshot,
      run_remincross_cleanup_reorder,
    )
  {
    ordered_groups: finalize_output.ordered_groups,
    ordered_with_vnodes: finalize_output.ordered_with_vnodes,
  }
}
