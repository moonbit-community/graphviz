///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let phase_context = build_clustered_ordering_stage_pre_root_and_root_phase_context(
    stage_dispatch_context.graph,
    stage_dispatch_context.nodes,
    stage_dispatch_context.edges,
    stage_dispatch_context.edge_tail,
    stage_dispatch_context.edge_head,
    stage_dispatch_context.ranks,
    stage_dispatch_context.node_order,
    stage_dispatch_context.order_sizes,
    stage_dispatch_context.nodesep_pt,
    stage_dispatch_context.has_edge_labels,
    stage_dispatch_context.cluster_meta,
    stage_dispatch_context.port_order_positions,
    stage_dispatch_context.port_order_contrib,
    stage_dispatch_context.runtime_context,
    stage_dispatch_context.reorder_setup,
    stage_dispatch_context.class2_data,
  )
  let stage_output = run_clustered_ordering_pre_root_and_root_stage_from_phase_context(
    phase_context,
  )
  let finalize_dispatch_context = build_clustered_ordering_stage_output_phase_dispatch_context(
    stage_dispatch_context.graph,
    stage_dispatch_context.edges,
    stage_dispatch_context.edge_tail,
    stage_dispatch_context.edge_head,
    stage_dispatch_context.edge_reversed,
    stage_dispatch_context.ranks,
    stage_dispatch_context.order_sizes,
    stage_dispatch_context.nodesep_pt,
    stage_dispatch_context.has_edge_labels,
    stage_dispatch_context.cluster_meta,
    stage_dispatch_context.port_order_positions,
    stage_dispatch_context.port_order_contrib,
    stage_dispatch_context.runtime_context,
    stage_dispatch_context.edge_port_data,
    stage_dispatch_context.reorder_setup,
    stage_dispatch_context.class2_data,
  )
  let (pre_root_stage, root_cluster_stage) = stage_output
  run_clustered_ordering_stage_from_phase_context(
    finalize_dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
}
