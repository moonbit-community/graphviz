///|
/// Stage C Phase C5 split: clustered reorder-step finalize dispatch
/// helpers for input-phase output forwarding.

///|
/// Graphviz parity: clustered ReMincross reorder-step finalize dispatch reads
/// input-phase tuple and forwards values in Graphviz finalize-call order.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_finalize_phase_from_input_phase_output(
  dispatch_context : ClusteredReMincrossReorderStepFinalizeDispatchContext,
  input_phase_output : ClusteredReMincrossReorderStepInputsOutput,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  ) = input_phase_output
  run_clustered_remincross_reorder_step_finalize_phase(
    dispatch_context.rem_rank_keys,
    dispatch_context.rem_groups,
    dispatch_context.rem_edges_out,
    dispatch_context.rem_edge_tail_out,
    dispatch_context.rem_edge_head_out,
    dispatch_context.rem_edge_tail_port_x,
    dispatch_context.rem_edge_head_port_x,
    dispatch_context.rem_edge_tail_port_order,
    dispatch_context.rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    dispatch_context.cluster_meta,
    rem_edge_order,
    dispatch_context.rem_node_order,
    rem_sizes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    rem_flat_constraints,
    dispatch_context.graphviz_flip,
    dispatch_context.real_nodes,
  )
}
