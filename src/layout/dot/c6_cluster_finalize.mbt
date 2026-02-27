///|
/// Stage C Phase C6 split: cluster-rank finalize
/// and post-remincross cleanup helpers.

///|
/// Graphviz parity: finalize stage derives cluster-rank order from root-phase
/// reorder/materialized state before clustered ReMincross cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_for_finalize_stage_from_context(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_for_cluster_reorder(
    dispatch_context.order_with_clusters,
    dispatch_context.order_with_vnodes,
    dispatch_context.graphviz_flip,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.nlist_order,
    dispatch_context.ranks,
    stage_inputs.order_rank_keys,
    stage_inputs.order_groups_for_mincross,
    stage_inputs.order_cluster_keys,
    stage_inputs.order_cluster_skeleton,
    dispatch_context.order_edges_by_tail_root,
    dispatch_context.skeleton_edge_creation,
    dispatch_context.root_edge_creation,
    dispatch_context.flat_rank_constraints,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.vnode_order_keys_for_ordering,
    dispatch_context.real_nodes,
    stage_inputs.order_sizes_out,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
  )
}

///|
/// Graphviz parity: finalize stage applies derived cluster-rank order through
/// final-group cleanup + clustered ReMincross without argument reshuffling.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_remincross_finalize_stage_from_context(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
  cluster_rank_order : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let finalize_dispatch_context : FinalizeOrderGroupsDispatchContext = {
    order_with_clusters: dispatch_context.order_with_clusters,
    order_with_vnodes: dispatch_context.order_with_vnodes,
    cluster_rank_order,
    cluster_meta: dispatch_context.cluster_meta,
    local_cluster_order: dispatch_context.local_cluster_order,
    ordered_with_vnodes: stage_inputs.ordered_with_vnodes,
    graph: dispatch_context.graph,
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    edge_reversed: dispatch_context.edge_reversed,
    edge_tail_port_x: dispatch_context.edge_tail_port_x,
    edge_head_port_x: dispatch_context.edge_head_port_x,
    edge_tail_port_order: dispatch_context.edge_tail_port_order,
    edge_head_port_order: dispatch_context.edge_head_port_order,
    ranks: dispatch_context.ranks,
    flat_rank_constraints: dispatch_context.flat_rank_constraints,
    creation_order: stage_inputs.creation_order,
    edges_by_tail: dispatch_context.edges_by_tail,
    vnode_info: dispatch_context.vnode_info,
    order_sizes: dispatch_context.order_sizes,
    rank_same_constraints: dispatch_context.rank_same_constraints,
    real_nodes: dispatch_context.real_nodes,
    graphviz_flip: dispatch_context.graphviz_flip,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
  }
  finalize_order_groups_with_cluster_remincross(
    finalize_dispatch_context,
    stage_inputs.order_rank_keys,
    stage_inputs.ordered,
  )
}

///|
/// Graphviz parity: clustered cleanup applies root cluster-rank ordering,
/// then runs final clustered ReMincross via typed dispatch context.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let cluster_rank_order =
    build_cluster_rank_order_for_finalize_stage_from_context(
      dispatch_context,
      stage_inputs,
    )
  run_cluster_remincross_finalize_stage_from_context(
    dispatch_context,
    stage_inputs,
    cluster_rank_order,
  )
}
