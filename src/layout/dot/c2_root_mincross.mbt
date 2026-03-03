///|
/// Stage C Phase C2 split: root mincross/replay helpers
/// for primary crossing-reduction ordering passes.

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  inputs : @ordering.RootMincrossReorderInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  // Graphviz parity: pass0 flat-seed capture wraps the root rank-reorder call,
  // then records the same stage snapshot before resetting capture state.
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  let result =
    @ordering.run_root_mincross_reorder(
      inputs,
      root_mincross_groups_override.val,
      (reorder_inputs, root_graphviz_flip, coalesce_parallel) =>
        reorder_rank_groups(
          reorder_inputs.order_rank_keys_for_mincross,
          reorder_inputs.order_groups_for_mincross,
          reorder_inputs.order_edges_out_mincross,
          reorder_inputs.order_edge_tail_out_mincross,
          reorder_inputs.order_edge_head_out_mincross,
          reorder_inputs.order_edge_tail_port_x_mincross,
          reorder_inputs.order_edge_head_port_x_mincross,
          reorder_inputs.order_edge_tail_port_order_mincross,
          reorder_inputs.order_edge_head_port_order_mincross,
          reorder_inputs.parents,
          reorder_inputs.children,
          reorder_inputs.order_cluster_keys,
          reorder_inputs.rank_same_groups,
          reorder_inputs.rank_same_order,
          reorder_inputs.edge_order,
          reorder_inputs.order_node_order,
          reorder_inputs.order_sizes_out,
          reorder_inputs.nodesep_pt,
          reorder_inputs.has_edge_labels,
          reorder_inputs.port_order_positions,
          reorder_inputs.port_order_contrib,
          reorder_inputs.preferred_positions,
          reorder_inputs.order_cluster_skeleton,
          reorder_inputs.order_flat_constraints,
          graphviz_out_neighbors=reorder_inputs.graphviz_out_neighbors,
          graphviz_in_neighbors=reorder_inputs.graphviz_in_neighbors,
          graphviz_flip=root_graphviz_flip,
          coalesce_parallel_edges=coalesce_parallel,
        ),
    )
  capture_pass0_flat_seed_groups_enabled.val = false
  let reorder_call_data = result.reorder_call_data
  // Graphviz parity: root reorder pass snapshot records the same mincross
  // edge projection and selected rank groups passed to reorder_rank_groups.
  capture_root_snapshot(
    reorder_call_data.order_rank_keys_for_mincross,
    result.order_groups_for_mincross,
    reorder_call_data.mincross_edge_data.order_edges_out_mincross,
    reorder_call_data.mincross_edge_data.order_edge_tail_out_mincross,
    reorder_call_data.mincross_edge_data.order_edge_head_out_mincross,
    reorder_call_data.mincross_edge_data.order_edge_tail_port_x_mincross,
    reorder_call_data.mincross_edge_data.order_edge_head_port_x_mincross,
    reorder_call_data.mincross_edge_data.order_edge_tail_port_order_mincross,
    reorder_call_data.mincross_edge_data.order_edge_head_port_order_mincross,
    inputs.order_cluster_keys,
    inputs.order_cluster_skeleton,
  )
  capture_pass0_flat_seed_groups_value.val = None
  (result.order_groups_for_mincross, result.ordered)
}
