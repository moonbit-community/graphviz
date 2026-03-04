///|
/// Stage C Phase C4 split: root+cluster build_ranks
/// and reorder helpers for root-cluster arrangement.

///|
/// Graphviz parity: clustered C4 stage views keep reorder setup, reorder
/// context, and materialized edge snapshots aligned across seeded/root/replay
/// context assembly.
priv struct ClusteredReorderStageViews {
  reorder_setup : @ordering.OrderingReorderSetup
  reorder_context : @ordering.OrderReorderContext
  materialized : @ordering.OrderMaterializationData
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
}

///|
/// Graphviz parity: clustered C4 stage views are read from dispatch/pre-root
/// snapshots once, then reused by all root+cluster rank context builders.
fn build_clustered_reorder_stage_views(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> ClusteredReorderStageViews {
  {
    reorder_setup: dispatch_context.reorder_setup,
    reorder_context: pre_root_stage.reorder_context,
    materialized: pre_root_stage.materialized,
    order_groups: pre_root_stage.order_groups,
    order_sizes_out: pre_root_stage.order_sizes_out,
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
  }
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  inputs : @ordering.RootMincrossReorderInputs,
  order_groups_override : Map[Int, Array[String]]?,
) -> @ordering.RootMincrossReorderResult {
  // Graphviz parity: pass0 flat-seed capture wraps the root rank-reorder call,
  // then records the same stage snapshot before resetting capture state.
  let result =
    @ordering.run_with_pass0_flat_seed_capture(() =>
      @ordering.run_root_mincross_reorder(
        inputs,
        order_groups_override,
      )
    )
  capture_root_mincross_pass_snapshot(result, inputs)
  result
}

///|
/// Graphviz parity: root-mincross reorder payload is assembled from clustered
/// pre-root snapshots after seeded build_ranks groups are produced.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_reorder_build_context(
  dispatch_context : ClusteredDispatchContext,
  stage_views : ClusteredReorderStageViews,
) -> @ordering.RootMincrossReorderBuildContext {
  {
    order_with_clusters: stage_views.reorder_setup.order_with_clusters,
    order_with_vnodes: stage_views.reorder_setup.order_with_vnodes,
    order_rank_keys: stage_views.reorder_context.order_rank_keys,
    order_ranks: stage_views.reorder_context.order_ranks,
    order_edges_out: stage_views.materialized.order_edges_out,
    order_edge_tail_out: stage_views.materialized.order_edge_tail_out,
    order_edge_head_out: stage_views.materialized.order_edge_head_out,
    order_edge_tail_port_x: stage_views.materialized.order_edge_tail_port_x,
    order_edge_head_port_x: stage_views.materialized.order_edge_head_port_x,
    order_edge_tail_port_order: stage_views.materialized.order_edge_tail_port_order,
    order_edge_head_port_order: stage_views.materialized.order_edge_head_port_order,
    order_cluster_keys: stage_views.order_cluster_keys,
    order_cluster_skeleton: stage_views.order_cluster_skeleton,
    rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
    rank_same_order: dispatch_context.cluster_meta.rank_same_order,
    vnode_order_keys_for_ordering:
      stage_views.reorder_setup.vnode_order_keys_for_ordering,
    order_node_order: stage_views.reorder_context.order_node_order,
    order_sizes_out: stage_views.order_sizes_out,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    order_flat_constraints: stage_views.materialized.order_flat_constraints,
    graphviz_out_neighbors: stage_views.materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: stage_views.materialized.graphviz_in_neighbors,
    graphviz_flip: stage_views.reorder_setup.graphviz_flip,
  }
}

///|
/// Graphviz parity: root mincross output is replayed into clustered build_ranks
/// using unmapped order-edge arrays before final clustered cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_rank_replay_context(
  dispatch_context : ClusteredDispatchContext,
  stage_views : ClusteredReorderStageViews,
) -> ClusterLocalRankReplayContext {
  let runtime_context = dispatch_context.runtime_context
  {
    graph: dispatch_context.graph,
    cluster_meta: dispatch_context.cluster_meta,
    node_order: stage_views.reorder_context.order_node_order,
    order_edges: stage_views.materialized.order_edges_out_unmapped,
    order_edge_tail: stage_views.materialized.order_edge_tail_out_unmapped,
    order_edge_head: stage_views.materialized.order_edge_head_out_unmapped,
    order_edge_tail_port_x: stage_views.materialized.order_edge_tail_port_x_unmapped,
    order_edge_head_port_x: stage_views.materialized.order_edge_head_port_x_unmapped,
    order_edge_tail_port_order:
      stage_views.materialized.order_edge_tail_port_order_unmapped,
    order_edge_head_port_order:
      stage_views.materialized.order_edge_head_port_order_unmapped,
    graphviz_out_neighbors: stage_views.materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: stage_views.materialized.graphviz_in_neighbors,
    ranks: dispatch_context.ranks,
    order_sizes: stage_views.order_sizes_out,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    vnode_info: runtime_context.vnode_info,
    order_with_vnodes: stage_views.reorder_setup.order_with_vnodes,
  }
}

///|
/// Graphviz parity: clustered root phase seeds build_ranks using mapped order
/// edges plus Graphviz ND_out/ND_in neighbors before root-mincross reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_reorder_build_context(
  stage_views : ClusteredReorderStageViews,
) -> @ordering.SeededReorderBuildContext {
  {
    order_rank_keys: stage_views.reorder_context.order_rank_keys,
    order_groups: stage_views.order_groups,
    order_edge_tail_out: stage_views.materialized.order_edge_tail_out,
    order_edge_head_out: stage_views.materialized.order_edge_head_out,
    order_ranks: stage_views.reorder_context.order_ranks,
    order_node_order: stage_views.reorder_context.order_node_order,
    order_cluster_keys: stage_views.order_cluster_keys,
    order_cluster_skeleton: stage_views.order_cluster_skeleton,
    order_flat_constraints: stage_views.materialized.order_flat_constraints,
    graphviz_flip: stage_views.reorder_setup.graphviz_flip,
    graphviz_out_neighbors: stage_views.materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: stage_views.materialized.graphviz_in_neighbors,
    order_edges_out: stage_views.materialized.order_edges_out,
    order_edge_tail_port_x: stage_views.materialized.order_edge_tail_port_x,
    order_edge_head_port_x: stage_views.materialized.order_edge_head_port_x,
    flat_rank_constraints: stage_views.reorder_setup.flat_rank_constraints,
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
  let stage_views =
    build_clustered_reorder_stage_views(
      dispatch_context,
      pre_root_stage,
    )
  let seeded_build_context =
    build_seeded_reorder_build_context(
      stage_views,
    )
  let seeded_groups =
    @ordering.build_seeded_reorder_groups(
      seeded_build_context,
    )
  let root_reorder_context =
    build_root_mincross_reorder_build_context(
      dispatch_context,
      stage_views,
    )
  let root_mincross_reorder_inputs =
    @ordering.build_root_mincross_reorder_inputs(
      seeded_groups,
      root_reorder_context,
    )
  let reorder_setup = dispatch_context.reorder_setup
  let root_and_cluster_inputs : @ordering.RootAndClusterRanksInputs = {
    order_with_vnodes: reorder_setup.order_with_vnodes,
    graphviz_flip: reorder_setup.graphviz_flip,
    cluster_keys: dispatch_context.cluster_meta.cluster_keys,
    root_groups_override,
  }
  let root_reorder_result =
    run_root_mincross_reorder(
      root_mincross_reorder_inputs,
      root_groups_override,
    )
  let replay_context =
    build_cluster_local_rank_replay_context(
      dispatch_context,
      stage_views,
    )
  let root_cluster_stage =
    @ordering.run_root_and_cluster_ranks(
      root_and_cluster_inputs,
      root_reorder_result,
    )
  if reorder_setup.order_with_clusters {
    reorder_by_cluster_ranks(root_cluster_stage.ordered, replay_context)
  }
  root_cluster_stage
}
