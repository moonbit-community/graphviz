///|
/// Stage C Phase C4 split: root-cluster reorder and
/// cluster-rank-order helpers for global cluster arrangement.



/// Graphviz parity: root cluster-rank-order phase output keeps root-rank keys
/// and ordered-root groups bundled for rank-transfer dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterRankOrderPhaseOutput {
  root_rank_keys : Array[Int]
  ordered_root : Map[Int, Array[String]]
}

fn has_multiple_non_empty_cluster_keys(
  order_cluster_keys : Map[String, String],
) -> Bool {
  let seen_cluster_keys : Map[String, Bool] = Map::new()
  for _name, key in order_cluster_keys {
    if key == "" || seen_cluster_keys.get(key) is Some(_) {
      continue
    }
    seen_cluster_keys[key] = true
    if seen_cluster_keys.length() > 1 {
      return true
    }
  }
  false
}

///|
/// Graphviz parity: root-only graphviz_flip gating enables root flip only when
/// capture-fixture mode is active or when at least two non-empty cluster keys
/// exist in the current ordering key map.
fn should_enable_root_flip(
  graphviz_flip : Bool,
  order_cluster_keys : Map[String, String],
) -> Bool {
  if !graphviz_flip {
    return false
  }
  if @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_) {
    return true
  }
  has_multiple_non_empty_cluster_keys(order_cluster_keys)
}

///|
/// Graphviz parity: root cluster-rank-order phase consumes root reorder tuple
/// and dispatch context without reordering Graphviz call arguments.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_order_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_reorder_output : @ordering.RootClusterReorderInputs,
) -> RootClusterRankOrderPhaseOutput {
  let reorder_setup = dispatch_context.reorder_setup
  // Graphviz parity: root-only reorder pass uses the same reorder_rank_groups
  // path as cluster-phase root bucket ordering, with root-flip guarding.
  let root_graphviz_flip =
    should_enable_root_flip(
      reorder_setup.graphviz_flip,
      pre_root_stage.order_cluster_keys,
    )
  let ordered_root =
    reorder_rank_groups(
      root_reorder_output.root_rank_keys,
      root_reorder_output.root_groups,
      root_reorder_output.root_edges_out,
      root_reorder_output.root_edge_tail_out,
      root_reorder_output.root_edge_head_out,
      root_reorder_output.root_edge_tail_port_x,
      root_reorder_output.root_edge_head_port_x,
      root_reorder_output.root_edge_tail_port_order,
      root_reorder_output.root_edge_head_port_order,
      root_reorder_output.root_parents,
      root_reorder_output.root_children,
      pre_root_stage.order_cluster_keys,
      dispatch_context.cluster_meta.rank_same_groups,
      dispatch_context.cluster_meta.rank_same_order,
      root_reorder_output.root_edge_order,
      root_reorder_output.root_node_order,
      pre_root_stage.order_sizes_out,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      Map::new(),
      pre_root_stage.order_cluster_skeleton,
      dispatch_context.cluster_meta.flat_constraints,
      graphviz_flip=root_graphviz_flip,
      coalesce_parallel_edges=true,
    )
  finalize_root_rank_order_phase_output(
    root_reorder_output.root_rank_keys,
    root_reorder_output.root_groups,
    ordered_root,
    pre_root_stage.order_cluster_keys,
    pre_root_stage.order_cluster_skeleton,
    reorder_setup.graphviz_flip,
  )
}

///|
/// Graphviz parity: graphviz_flip root output merge replays ordered root
/// membership from root mincross back into seeded root rank groups.
fn build_graphviz_flip_merged_root_groups(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let ordered_root_nodes =
    @ordering.build_order_nodes_from_groups(ordered_root, root_rank_keys)
  let ordered_root_mincross_nodes =
    @ordering.build_node_membership_set(ordered_root_nodes)
  @ordering.merge_root_mincross_groups(
    root_rank_keys,
    root_groups,
    ordered_root,
    ordered_root_mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: root rank-order output merge keeps non-flip output as-is,
/// and only replays root mincross membership back into seeded groups when
/// graphviz_flip was requested for this pass.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_rank_order_phase_output(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
) -> RootClusterRankOrderPhaseOutput {
  if !graphviz_flip {
    return {
      root_rank_keys,
      ordered_root,
    }
  }
  let merged_ordered_root =
    build_graphviz_flip_merged_root_groups(
      root_rank_keys,
      root_groups,
      ordered_root,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  {
    root_rank_keys,
    ordered_root: merged_ordered_root,
  }
}


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
/// Graphviz parity: root cluster-reorder phase keeps root input assembly and
/// root rank-order execution in one sequence for shared clustered consumers.
/// Do not change behavior without updating fixtures/tests.
fn run_root_reorder_and_rank_order_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (@ordering.RootClusterReorderInputs, RootClusterRankOrderPhaseOutput) {
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
  let root_rank_order_phase_output =
    run_root_rank_order_phase(
      dispatch_context,
      pre_root_stage,
      root_reorder_output,
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
