///|
/// Stage C Phase C4 split: root-cluster reorder and
/// cluster-rank-order helpers for global cluster arrangement.

///|
type OrderEdgeListsByTail = Map[
  String,
  Array[(String, String, Int, Bool, Double, Double, Double, Double)],
]

///|
/// Graphviz parity: root cluster-rank-order base reuses one static source
/// payload plus one static rank-order context across both stage callers.
/// Do not change behavior without updating fixtures/tests.
priv struct RootRankOrderPhaseBase {
  order_with_clusters : Bool
  root_reorder_sources_base : @ordering.RootReorderBuildSources
  root_rank_order_context : @ordering.RootRankOrderPhaseContext
  order_edges_by_tail_root : OrderEdgeListsByTail
}

///|
/// Graphviz parity: root cluster-rank-order static source/context assembly is
/// shared by root-phase override derivation and finalize-time cluster replay.
/// Do not change behavior without updating fixtures/tests.
fn build_root_rank_order_phase_base(
  dispatch_context : ClusteredDispatchContext,
  order_sizes_out : Map[String, NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  reorder_context : @ordering.OrderReorderContext,
) -> RootRankOrderPhaseBase {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let root_reorder_sources_base : @ordering.RootReorderBuildSources = {
    order_with_vnodes: reorder_setup.order_with_vnodes,
    order_rank_keys: reorder_context.order_rank_keys,
    order_groups_for_mincross: Map::new(),
    order_cluster_keys,
    order_cluster_skeleton,
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
  let root_rank_order_context : @ordering.RootRankOrderPhaseContext = {
    order_cluster_keys,
    order_cluster_skeleton,
    rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
    rank_same_order: dispatch_context.cluster_meta.rank_same_order,
    order_sizes_out,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    order_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
    graphviz_flip: reorder_setup.graphviz_flip,
  }
  {
    order_with_clusters: reorder_setup.order_with_clusters,
    root_reorder_sources_base,
    root_rank_order_context,
    order_edges_by_tail_root: class2_data.order_edges_by_tail_root,
  }
}

///|
/// Graphviz parity: root cluster-reorder phase keeps root input assembly and
/// root rank-order execution in one sequence for shared clustered consumers.
/// Do not change behavior without updating fixtures/tests.
fn run_root_reorder_and_rank_order_phase(
  pre_root_stage : ClusteredPreRootData,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (@ordering.RootClusterReorderInputs, @ordering.RootRankOrderPhaseOutput) {
  let root_rank_order_phase_base = pre_root_stage.root_rank_order_phase_base
  let root_reorder_sources =
    @ordering.with_root_reorder_groups(
      root_rank_order_phase_base.root_reorder_sources_base,
      order_groups_for_mincross,
    )
  @ordering.run_root_reorder_and_rank_order_phase(
    root_reorder_sources,
    root_rank_order_phase_base.root_rank_order_context,
    root_rank_order_phase_base.order_edges_by_tail_root,
  )
}

///|
/// Graphviz parity: cluster-phase rank-order map is built from root-only
/// reorder pass (root/skeleton + root-vnodes) before local cluster bucket
/// reordering in final real-node groups.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order(
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : @ordering.RootAndClusterRanksOutput,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  if !pre_root_stage.root_rank_order_phase_base.order_with_clusters {
    return Map::new()
  }
  let (_root_reorder_output, root_rank_order_phase_output) =
    run_root_reorder_and_rank_order_phase(
      pre_root_stage,
      root_cluster_stage.order_groups_for_mincross,
    )
  @ordering.build_cluster_order_from_root(
    root_rank_order_phase_output.root_rank_keys,
    root_rank_order_phase_output.ordered_root,
    pre_root_stage.order_cluster_keys,
    pre_root_stage.order_cluster_skeleton,
    real_nodes,
  )
}
