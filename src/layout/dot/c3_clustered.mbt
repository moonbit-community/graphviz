///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// stage-dispatch type definitions for phase orchestration.

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
  root_rank_order_phase_base : @ordering.RootRankOrderPhaseBase
}

///|
/// Graphviz parity: clustered ordering stage dispatch context keeps complete
/// clustered ordering payload ordering unchanged before stage execution.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredDispatchContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  edge_port_data : @ordering.OrderingEdgePortData
  reorder_setup : @ordering.OrderingReorderSetup
}

///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// pre-root/root/finalize stage orchestration helpers.

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
  let root_rank_order_phase_base =
    @ordering.build_root_rank_order_phase_base_from_sources(
      {
        reorder_setup: dispatch_context.reorder_setup,
        class2_data: dispatch_context.reorder_setup.class2_data,
        order_rank_keys: reorder_context.order_rank_keys,
        order_cluster_keys,
        order_cluster_skeleton,
        edges: dispatch_context.edges,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        edge_vnodes: dispatch_context.runtime_context.vnode_info.edge_vnodes,
        vnodes_by_rank: dispatch_context.runtime_context.vnode_info.vnodes_by_rank,
        ranks: dispatch_context.ranks,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        order_sizes_out,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        order_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
      },
    )
  {
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
    reorder_context,
    materialized,
    root_rank_order_phase_base,
  }
}

///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let pre_root_stage = build_clustered_pre_root(dispatch_context)
  let root_phase_output = run_clustered_root_phase(dispatch_context, pre_root_stage)
  run_clustered_finalize_phase(
    dispatch_context,
    pre_root_stage,
    root_phase_output.root_cluster_stage,
    root_phase_output.root_tail_order_override,
  )
}
