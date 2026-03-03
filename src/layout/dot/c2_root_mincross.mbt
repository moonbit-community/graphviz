///|
/// Stage C Phase C2 split: root mincross/replay helpers
/// for primary crossing-reduction ordering passes.

///|
/// Graphviz parity: root mincross reorder dispatch funnels both single- and
/// component-path payloads through one reorder_rank_groups call shape.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_reorder_call(
  inputs : @ordering.RootRankReorderInputs,
  root_graphviz_flip : Bool,
  coalesce_parallel : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    inputs.order_rank_keys_for_mincross,
    inputs.order_groups_for_mincross,
    inputs.order_edges_out_mincross,
    inputs.order_edge_tail_out_mincross,
    inputs.order_edge_head_out_mincross,
    inputs.order_edge_tail_port_x_mincross,
    inputs.order_edge_head_port_x_mincross,
    inputs.order_edge_tail_port_order_mincross,
    inputs.order_edge_head_port_order_mincross,
    inputs.parents,
    inputs.children,
    inputs.order_cluster_keys,
    inputs.rank_same_groups,
    inputs.rank_same_order,
    inputs.edge_order,
    inputs.order_node_order,
    inputs.order_sizes_out,
    inputs.nodesep_pt,
    inputs.has_edge_labels,
    inputs.port_order_positions,
    inputs.port_order_contrib,
    inputs.preferred_positions,
    inputs.order_cluster_skeleton,
    inputs.order_flat_constraints,
    graphviz_out_neighbors=inputs.graphviz_out_neighbors,
    graphviz_in_neighbors=inputs.graphviz_in_neighbors,
    graphviz_flip=root_graphviz_flip,
    coalesce_parallel_edges=coalesce_parallel,
  )
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  inputs : @ordering.RootMincrossReorderInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let order_groups_for_mincross =
    @ordering.resolve_root_mincross_input_groups(
      inputs.order_with_clusters,
      inputs.seeded_groups,
      inputs.order_cluster_keys,
      inputs.order_cluster_skeleton,
      root_mincross_groups_override.val,
    )
  // Graphviz parity: pass0 flat-seed capture wraps the root rank-reorder call,
  // then records the same stage snapshot before resetting capture state.
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  let pass_result =
    @ordering.run_root_reorder_for_groups(
      inputs,
      order_groups_for_mincross,
      run_root_rank_reorder_call,
    )
  capture_pass0_flat_seed_groups_enabled.val = false
  let reorder_call_data = pass_result.reorder_call_data
  // Graphviz parity: root reorder pass snapshot records the same mincross
  // edge projection and selected rank groups passed to reorder_rank_groups.
  capture_root_snapshot(
    reorder_call_data.order_rank_keys_for_mincross,
    order_groups_for_mincross,
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
  let ordered =
    @ordering.finalize_root_mincross_ordered_groups(
      inputs.order_with_clusters,
      inputs.order_rank_keys,
      inputs.seeded_groups,
      pass_result.ordered_mincross,
      reorder_call_data.mincross_nodes,
      inputs.order_cluster_keys,
      inputs.order_cluster_skeleton,
    )
  (order_groups_for_mincross, ordered)
}
