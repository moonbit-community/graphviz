///|
/// Stage C Phase C4 split: root-cluster reorder and
/// cluster-rank-order helpers for global cluster arrangement.

///|
type OrderEdgeListsByTail = Map[
  String,
  Array[(String, String, Int, Bool, Double, Double, Double, Double)],
]

///|
/// Graphviz parity: root cluster-reorder base keeps static source snapshots
/// that are shared by both root phase and clustered finalize rank-order replay.
/// Do not change behavior without updating fixtures/tests.
priv struct RootReorderSourceBase {
  order_with_vnodes : Bool
  order_rank_keys : Array[Int]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  cluster_keys : Map[String, String]
  edge_vnodes : Map[String, Array[String]]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_order_keys_for_ordering : Map[String, Double]
  nlist_order : Array[String]
  ranks : Map[String, Int]
  skeleton_edge_creation : Array[(String, String)]
  root_edge_creation : Array[(String, String)]
  flat_rank_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: root cluster-rank-order base reuses one static source
/// payload plus one static rank-order context across both stage callers.
/// Do not change behavior without updating fixtures/tests.
priv struct RootRankOrderPhaseBase {
  order_with_clusters : Bool
  source_base : RootReorderSourceBase
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
  reorder_context : OrderReorderContext,
) -> RootRankOrderPhaseBase {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let source_base : RootReorderSourceBase =
    {
      order_with_vnodes: reorder_setup.order_with_vnodes,
      order_rank_keys: reorder_context.order_rank_keys,
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
  let root_rank_order_context : @ordering.RootRankOrderPhaseContext =
    {
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
    source_base,
    root_rank_order_context,
    order_edges_by_tail_root: class2_data.order_edges_by_tail_root,
  }
}

///|
/// Graphviz parity: root cluster-reorder source bundle is assembled from the
/// clustered dispatch/pre-root snapshots plus the selected rank groups source.
/// Do not change behavior without updating fixtures/tests.
fn build_root_reorder_sources(
  source_base : RootReorderSourceBase,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> @ordering.RootReorderBuildSources {
  {
    order_with_vnodes: source_base.order_with_vnodes,
    order_rank_keys: source_base.order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys: source_base.order_cluster_keys,
    order_cluster_skeleton: source_base.order_cluster_skeleton,
    edges: source_base.edges,
    edge_tail: source_base.edge_tail,
    edge_head: source_base.edge_head,
    cluster_keys: source_base.cluster_keys,
    edge_vnodes: source_base.edge_vnodes,
    vnodes_by_rank: source_base.vnodes_by_rank,
    vnode_order_keys_for_ordering: source_base.vnode_order_keys_for_ordering,
    nlist_order: source_base.nlist_order,
    ranks: source_base.ranks,
    skeleton_edge_creation: source_base.skeleton_edge_creation,
    root_edge_creation: source_base.root_edge_creation,
    flat_rank_constraints: source_base.flat_rank_constraints,
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
  pre_root_stage : ClusteredPreRootData,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (@ordering.RootClusterReorderInputs, @ordering.RootRankOrderPhaseOutput) {
  let root_rank_order_phase_base = pre_root_stage.root_rank_order_phase_base
  let root_reorder_sources =
    build_root_reorder_sources(
      root_rank_order_phase_base.source_base,
      order_groups_for_mincross,
    )
  @ordering.run_root_reorder_and_rank_order_phase(
    root_reorder_sources,
    root_rank_order_phase_base.root_rank_order_context,
    root_rank_order_phase_base.order_edges_by_tail_root,
    run_root_rank_order_reorder,
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
