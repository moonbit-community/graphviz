///|
/// Stage C clustered phase helpers: pre-root, local replay, root, snapshot,
/// and finalize.

type ClusteredPreRootData = @ordering.ClusteredPreRootStageOutput

///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root(
  dispatch_context : ClusteredDispatchContext,
) -> ClusteredPreRootData {
  let runtime_context = dispatch_context.runtime_context
  @ordering.run_clustered_pre_root_stage_from_sources(
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
}

type ClusteredRootPhaseOutput = @ordering.ClusteredRootPhaseStageOutput

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_root_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> ClusteredRootPhaseOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  let root_phase_sources =
    @ordering.build_clustered_root_phase_stage_sources(
      {
        reorder_setup,
        pre_root_stage,
        edges: dispatch_context.edges,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        edge_vnodes: runtime_context.vnode_info.edge_vnodes,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        ranks: dispatch_context.ranks,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        graph: dispatch_context.graph,
        cluster_order: dispatch_context.cluster_meta.cluster_order,
        cluster_parents: dispatch_context.cluster_meta.cluster_parents,
        intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
        flat_constraints: dispatch_context.cluster_meta.flat_constraints,
        vnode_ranks: runtime_context.vnode_info.vnode_ranks,
        vnode_clusters: runtime_context.vnode_info.vnode_clusters,
        vnode_sizes: runtime_context.vnode_info.vnode_sizes,
      },
    )
  @ordering.run_clustered_root_phase_stage_from_sources(
    root_phase_sources,
    @ordering.build_root_snapshot_capture_callback(@dot_shared.edge_xpenalty),
  )
}

///|
/// Stage C Phase C6 split: clustered finalize phase helpers.

///|
/// Graphviz parity: clustered finalize phase first applies root cluster-rank
/// ordering, then runs final clustered ReMincross with unchanged call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_finalize_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_phase_output : ClusteredRootPhaseOutput,
) -> OrderingDispatchOutput {
  let runtime_context = dispatch_context.runtime_context
  let finalize_sources =
    @ordering.build_clustered_finalize_stage_from_sources(
      {
        phase_base: root_phase_output.root_rank_order_phase_base,
        root_cluster_stage: root_phase_output.root_cluster_stage,
        root_tail_order_override: root_phase_output.root_tail_order_override,
        pre_root_stage,
        real_nodes: runtime_context.real_nodes,
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
        reorder_setup: dispatch_context.reorder_setup,
        local_cluster_order: runtime_context.local_cluster_order,
        cluster_order: dispatch_context.cluster_meta.cluster_order,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
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
        root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
      },
    )
  let finalize_output =
    @ordering.run_clustered_finalize_stage_from_root_phase_sources(
      finalize_sources,
      @ordering.build_remincross_snapshot_capture_callback(
        @dot_shared.edge_xpenalty,
      ),
      @ordering.run_remincross_cleanup_reorder,
    )
  {
    ordered_groups: finalize_output.ordered_groups,
    ordered_with_vnodes: finalize_output.ordered_with_vnodes,
  }
}
