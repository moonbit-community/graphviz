///|
/// Stage C Phase C4 split: root-cluster reorder and
/// cluster-rank-order helpers for global cluster arrangement.

///|
/// Graphviz parity: root cluster-reorder source bundle is assembled from the
/// clustered dispatch/pre-root snapshots plus the selected rank groups source.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_sources(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> @ordering.RootReorderBuildSources {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let reorder_context = pre_root_stage.reorder_context
  {
    order_with_vnodes: reorder_setup.order_with_vnodes,
    order_rank_keys: reorder_context.order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    cluster_keys: dispatch_context.cluster_meta.cluster_keys,
    edge_vnodes: runtime_context.vnode_info.edge_vnodes,
    vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
    vnode_order_keys_for_ordering: reorder_setup.vnode_order_keys_for_ordering,
    nlist_order: class2_data.nlist_order,
    ranks: dispatch_context.ranks,
    skeleton_edge_creation: class2_data.skeleton_edge_creation,
    root_edge_creation: class2_data.root_edge_creation,
    flat_rank_constraints: reorder_setup.flat_rank_constraints,
  }
}



///|
/// Graphviz parity: root cluster-rank-order input bundle is assembled from the
/// root reorder output plus clustered dispatch snapshots without reordering.
fn build_root_rank_order_phase_inputs(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_reorder_output : @ordering.RootClusterReorderInputs,
) -> @ordering.RootRankOrderPhaseInputs {
  {
    root_reorder_output,
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
    rank_same_order: dispatch_context.cluster_meta.rank_same_order,
    order_sizes_out: pre_root_stage.order_sizes_out,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    order_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
    graphviz_flip: dispatch_context.reorder_setup.graphviz_flip,
  }
}

///|
/// Graphviz parity: root cluster-rank-order pass uses reorder_rank_groups with
/// coalesced-parallel mode on root-only rematerialized edge arrays.
fn run_root_rank_order_reorder(
  call_inputs : @ordering.RootRankOrderCallInputs,
  root_graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    call_inputs.root_rank_keys,
    call_inputs.root_groups,
    call_inputs.root_edges_out,
    call_inputs.root_edge_tail_out,
    call_inputs.root_edge_head_out,
    call_inputs.root_edge_tail_port_x,
    call_inputs.root_edge_head_port_x,
    call_inputs.root_edge_tail_port_order,
    call_inputs.root_edge_head_port_order,
    call_inputs.root_parents,
    call_inputs.root_children,
    call_inputs.order_cluster_keys,
    call_inputs.rank_same_groups,
    call_inputs.rank_same_order,
    call_inputs.root_edge_order,
    call_inputs.root_node_order,
    call_inputs.order_sizes_out,
    call_inputs.nodesep_pt,
    call_inputs.has_edge_labels,
    call_inputs.port_order_positions,
    call_inputs.port_order_contrib,
    Map::new(),
    call_inputs.order_cluster_skeleton,
    call_inputs.order_flat_constraints,
    graphviz_flip=root_graphviz_flip,
    coalesce_parallel_edges=true,
  )
}

///|
/// Graphviz parity: root cluster-reorder phase keeps root input assembly and
/// root rank-order execution in one sequence for shared clustered consumers.
/// Do not change behavior without updating fixtures/tests.
fn run_root_reorder_and_rank_order_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (@ordering.RootClusterReorderInputs, @ordering.RootRankOrderPhaseOutput) {
  let root_reorder_sources =
    build_root_reorder_sources(
      dispatch_context,
      pre_root_stage,
      order_groups_for_mincross,
    )
  let root_reorder_output =
    @ordering.build_root_reorder_inputs(
      root_reorder_sources,
      dispatch_context.class2_data.order_edges_by_tail_root,
    )
  let root_rank_order_inputs =
    build_root_rank_order_phase_inputs(
      dispatch_context,
      pre_root_stage,
      root_reorder_output,
    )
  let root_rank_order_phase_output =
    @ordering.run_root_rank_order_phase(
      root_rank_order_inputs,
      run_root_rank_order_reorder,
    )
  (root_reorder_output, root_rank_order_phase_output)
}

///|
/// Graphviz parity: cluster-phase rank-order map is built from root-only
/// reorder pass (root/skeleton + root-vnodes) before local cluster bucket
/// reordering in final real-node groups.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : OrderRootClusterData,
) -> Map[Int, Map[String, Int]] {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  if !reorder_setup.order_with_clusters {
    return Map::new()
  }
  let (_root_reorder_output, root_rank_order_phase_output) =
    run_root_reorder_and_rank_order_phase(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage.order_groups_for_mincross,
    )
  @ordering.build_cluster_order_from_root(
    root_rank_order_phase_output.root_rank_keys,
    root_rank_order_phase_output.ordered_root,
    pre_root_stage.order_cluster_keys,
    pre_root_stage.order_cluster_skeleton,
    runtime_context.real_nodes,
  )
}
