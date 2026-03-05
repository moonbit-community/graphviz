///|
/// Stage C Phase C3/C4/C6 split: clustered pre-root, root, and finalize
/// phase helpers.

///|
/// Graphviz parity: clustered pre-root stage output carries grouped sizes,
/// cluster skeleton maps, reorder context, and materialized edges unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredPreRootData {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  reorder_context : @ordering.OrderReorderContext
  materialized : @ordering.OrderMaterializationData
}

///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root(
  dispatch_context : ClusteredDispatchContext,
) -> ClusteredPreRootData {
  let runtime_context = dispatch_context.runtime_context
  let order_seed_stage =
    @ordering.build_clustered_order_seed_stage_from_sources(
      {
        reorder_setup: dispatch_context.reorder_setup,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        cluster_order: dispatch_context.cluster_meta.cluster_order,
        cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
        cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
        vnode_clusters: runtime_context.vnode_info.vnode_clusters,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        order_sizes: dispatch_context.order_sizes,
        vnode_sizes: runtime_context.vnode_info.vnode_sizes,
        // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
        skeleton_size: vnode_size_from_widths(1.0, 1.0),
      },
    )
  let order_groups = order_seed_stage.order_groups
  let order_sizes_out = order_seed_stage.order_sizes_out
  let order_cluster_keys = order_seed_stage.order_cluster_keys
  let order_cluster_skeleton = order_seed_stage.order_cluster_skeleton
  let materialized_stage =
    @ordering.build_clustered_materialized_stage_from_sources(
      {
        reorder_setup: dispatch_context.reorder_setup,
        class2_data: dispatch_context.reorder_setup.class2_data,
        order_groups,
        node_order: dispatch_context.node_order,
        real_nodes: runtime_context.real_nodes,
        has_clusters: dispatch_context.cluster_meta.has_clusters,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        port_edge_nodes: runtime_context.port_edge_nodes,
        flat_constraints: dispatch_context.cluster_meta.flat_constraints,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        nodes: dispatch_context.nodes,
        intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
      },
    )
  let reorder_context = materialized_stage.reorder_context
  let materialized = materialized_stage.materialized
  {
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
    reorder_context,
    materialized,
  }
}

///|
/// Graphviz parity: clustered root phase output carries root+cluster rank
/// groups together with optional root tail-order override for ReMincross.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredRootPhaseOutput {
  root_cluster_stage : @ordering.RootAndClusterRanksOutput
  root_tail_order_override : Array[String]?
  root_rank_order_phase_base : @ordering.RootRankOrderPhaseBase
}

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_root_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> ClusteredRootPhaseOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let root_rank_order_phase_base =
    @ordering.build_root_rank_order_phase_base_from_sources(
      {
        reorder_setup,
        class2_data: reorder_setup.class2_data,
        order_rank_keys: pre_root_stage.reorder_context.order_rank_keys,
        order_cluster_keys: pre_root_stage.order_cluster_keys,
        order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
        edges: dispatch_context.edges,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        edge_vnodes: dispatch_context.runtime_context.vnode_info.edge_vnodes,
        vnodes_by_rank: dispatch_context.runtime_context.vnode_info.vnodes_by_rank,
        ranks: dispatch_context.ranks,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        order_sizes_out: pre_root_stage.order_sizes_out,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        order_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
      },
    )
  let (root_reorder_output, root_rank_order_phase_output) =
    @ordering.run_root_reorder_and_rank_order_from_base(
      root_rank_order_phase_base,
      pre_root_stage.order_groups,
    )
  let root_phase_overrides =
    @ordering.build_clustered_root_phase_overrides(
      reorder_setup.order_with_clusters,
      root_reorder_output,
      root_rank_order_phase_output,
    )
  let root_cluster_stage =
    run_root_and_cluster_ranks(
      dispatch_context,
      pre_root_stage,
      root_phase_overrides.root_groups_override_for_root_pass,
    )
  {
    root_cluster_stage,
    root_tail_order_override: root_phase_overrides.root_tail_order_override,
    root_rank_order_phase_base,
  }
}

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
  let root_cluster_stage =
    @ordering.run_root_and_cluster_ranks_from_call_inputs_with_pass0_capture(
      call_inputs,
      capture_root_mincross_pass_snapshot,
    )
  apply_cluster_local_rank_replay_after_root(
    dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
  root_cluster_stage
}

///|
/// Stage C Phase C6 split: clustered finalize phase helpers.

///|
/// Graphviz parity: clustered finalize ReMincross source snapshot keeps
/// pre-root creation order and cluster/vnode metadata unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_finalize_remincross_sources(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_phase_output : ClusteredRootPhaseOutput,
) -> @ordering.ReMincrossPassBuildSources {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  {
    ratio: dispatch_context.graph.get_attr("ratio").unwrap_or_default(),
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    edge_reversed: dispatch_context.edge_reversed,
    edge_tail_port_x: dispatch_context.edge_port_data.edge_tail_port_x,
    edge_head_port_x: dispatch_context.edge_port_data.edge_head_port_x,
    edge_tail_port_order: dispatch_context.edge_port_data.edge_tail_port_order,
    edge_head_port_order: dispatch_context.edge_port_data.edge_head_port_order,
    ranks: dispatch_context.ranks,
    reorder_setup,
    creation_order: pre_root_stage.reorder_context.creation_order,
    edges_by_tail: reorder_setup.class2_data.edges_by_tail,
    cluster_order: dispatch_context.cluster_meta.cluster_order,
    cluster_keys: dispatch_context.cluster_meta.cluster_keys,
    intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
    local_cluster_order: runtime_context.local_cluster_order,
    cluster_parents: dispatch_context.cluster_meta.cluster_parents,
    cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
    cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
    cluster_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
    rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
    rank_same_order: dispatch_context.cluster_meta.rank_same_order,
    edge_vnodes: runtime_context.vnode_info.edge_vnodes,
    vnode_ranks: runtime_context.vnode_info.vnode_ranks,
    vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
    vnode_sizes: runtime_context.vnode_info.vnode_sizes,
    order_sizes: dispatch_context.order_sizes,
    rank_same_constraints: runtime_context.rank_same_constraints,
    ordered_with_vnodes: root_phase_output.root_cluster_stage.ordered_with_vnodes,
    real_nodes: runtime_context.real_nodes,
    root_tail_order_override: root_phase_output.root_tail_order_override,
    root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
  }
}

///|
/// Graphviz parity: clustered finalize phase first applies root cluster-rank
/// ordering, then runs final clustered ReMincross with unchanged call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_finalize_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_phase_output : ClusteredRootPhaseOutput,
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  let finalize_inputs =
    @ordering.build_clustered_finalize_inputs_from_root_phase_sources(
      {
        phase_base: root_phase_output.root_rank_order_phase_base,
        root_cluster_stage: root_phase_output.root_cluster_stage,
        order_cluster_keys: pre_root_stage.order_cluster_keys,
        order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
        real_nodes: runtime_context.real_nodes,
        reorder_setup,
        order_rank_keys: pre_root_stage.reorder_context.order_rank_keys,
        remincross_sources:
          build_clustered_finalize_remincross_sources(
            dispatch_context,
            pre_root_stage,
            root_phase_output,
          ),
      },
    )
  let finalize_output =
    @ordering.run_clustered_finalize_order_groups(
      finalize_inputs,
      build_vnode_order_keys,
      capture_remincross_snapshot,
      @ordering.run_remincross_cleanup_reorder,
    )
  {
    ordered_groups: finalize_output.ordered_groups,
    ordered_with_vnodes: finalize_output.ordered_with_vnodes,
  }
}
