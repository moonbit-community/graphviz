///|
/// Stage C Phase C5 split: remincross clustered pass output
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross output keeps vnode-augmented and
/// cleaned real-node groups in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  next_final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (next_ordered_with_vnodes, next_final_groups)
}

///|
/// Graphviz parity: clustered ReMincross pass derives rem_rank_keys from
/// vnode-augmented rem_groups before rank-count branch and cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_groups_output_from_rem_groups(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
  rem_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_rank_keys = collect_rank_keys(rem_groups)
  build_clustered_remincross_groups_output(
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_tail_port_x,
    dispatch_context.edge_head_port_x,
    dispatch_context.edge_tail_port_order,
    dispatch_context.edge_head_port_order,
    dispatch_context.ranks,
    dispatch_context.order_with_vnodes,
    dispatch_context.order_with_clusters,
    dispatch_context.flat_rank_constraints,
    dispatch_context.creation_order,
    dispatch_context.edges_by_tail,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    dispatch_context.ordered_with_vnodes,
    dispatch_context.base_groups,
    dispatch_context.real_nodes,
    dispatch_context.graphviz_flip,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
  )
}
