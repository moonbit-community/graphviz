///|
/// Stage C Phase C3 split: cluster-local replay pass orchestration
/// and shared dispatch payload for local cluster rank reordering.

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
    @ordering.build_cluster_graph_order(
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
