///|
/// Stage C Phase C4 split: root+cluster build_ranks
/// and reorder helpers for root-cluster arrangement.

///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks application on the unmapped order graph before final cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_ranks(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_groups_override : Map[Int, Array[String]]?,
) -> @ordering.RootAndClusterRanksOutput {
  let call_inputs =
    @ordering.build_root_and_cluster_ranks_call_inputs_from_sources(
      {
        reorder_setup: dispatch_context.reorder_setup,
        reorder_context: pre_root_stage.reorder_context,
        materialized: pre_root_stage.materialized,
        order_groups: pre_root_stage.order_groups,
        order_cluster_keys: pre_root_stage.order_cluster_keys,
        order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
        order_sizes_out: pre_root_stage.order_sizes_out,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        root_groups_override,
      },
    )
  let reorder_setup = dispatch_context.reorder_setup
  let root_reorder_result =
    @ordering.run_root_mincross_reorder_with_pass0_capture(
      call_inputs.root_mincross_reorder_inputs,
      root_groups_override,
      capture_root_mincross_pass_snapshot,
    )
  let replay_context =
    build_cluster_local_rank_replay_context(
      dispatch_context,
      pre_root_stage.reorder_context,
      pre_root_stage.materialized,
      pre_root_stage.order_sizes_out,
    )
  let root_cluster_stage =
    @ordering.run_root_and_cluster_ranks(
      call_inputs.root_and_cluster_inputs,
      root_reorder_result,
    )
  if reorder_setup.order_with_clusters {
    reorder_by_cluster_ranks(root_cluster_stage.ordered, replay_context)
  }
  root_cluster_stage
}
