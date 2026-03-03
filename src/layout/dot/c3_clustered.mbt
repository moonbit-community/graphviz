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
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
  root_rank_order_phase_base : RootRankOrderPhaseBase
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
  class2_data : @ordering.OrderingClass2Data
}

///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// pre-root/root/finalize stage orchestration helpers.

///|
/// Graphviz parity: clustered root phase output carries root+cluster rank
/// groups together with optional root tail-order override for ReMincross.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredRootPhaseOutput {
  root_cluster_stage : @ordering.RootAndClusterRanksOutput
  root_tail_order_override : Array[String]?
}

///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root(
  dispatch_context : ClusteredDispatchContext,
) -> ClusteredPreRootData {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let order_seed_output =
    build_order_seed_groups(
      reorder_setup.ordering_groups_base,
      reorder_setup.base_order_index,
      reorder_setup.order_with_vnodes,
      reorder_setup.order_with_clusters,
      dispatch_context.cluster_meta,
      runtime_context.vnode_info,
      reorder_setup.vnode_order_keys_for_ordering,
      dispatch_context.order_sizes,
    )
  let order_groups = order_seed_output.order_groups
  let order_sizes_out = order_seed_output.order_sizes_out
  let order_cluster_keys = order_seed_output.order_cluster_keys
  let order_cluster_skeleton = order_seed_output.order_cluster_skeleton
  let reorder_context =
    build_order_reorder_context(
      order_groups,
      class2_data.nlist_order,
      reorder_setup.gdnlist_order,
      dispatch_context.node_order,
      runtime_context.real_nodes,
      dispatch_context.cluster_meta.has_clusters,
      reorder_setup.base_order_index,
      dispatch_context.cluster_meta.rank_same_groups,
      dispatch_context.cluster_meta.rank_same_order,
      runtime_context.port_edge_nodes,
    )
  let materialized =
    build_materialized_inputs(
      class2_data.nlist_order,
      class2_data.order_edges_by_tail,
      reorder_context.order_graph,
      reorder_context.order_node_map,
      class2_data.order_edges_by_tail_unmapped,
      reorder_context.order_graph_unmapped,
      reorder_context.order_node_map_unmapped,
      runtime_context.real_nodes,
      reorder_context.order_nodes,
      class2_data.edge_creation_order,
      dispatch_context.cluster_meta,
      reorder_setup.gdnlist_order,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.nodes,
      reorder_context.order_node_order,
    )
  let root_rank_order_phase_base =
    build_root_rank_order_phase_base(
      dispatch_context,
      order_sizes_out,
      order_cluster_keys,
      order_cluster_skeleton,
      reorder_context,
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
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_root_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> ClusteredRootPhaseOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let (root_reorder_output, root_rank_order_phase_output) =
    run_root_reorder_and_rank_order_phase(
      pre_root_stage,
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
  let root_cluster_stage = root_phase_output.root_cluster_stage
  let cluster_rank_order =
    build_cluster_rank_order(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage,
    )
  let finalize_output =
    finalize_order_groups(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage,
      root_phase_output.root_tail_order_override,
      cluster_rank_order,
    )
  {
    ordered_groups: finalize_output.ordered_groups,
    ordered_with_vnodes: finalize_output.ordered_with_vnodes,
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
  let root_phase_output =
    run_clustered_root_phase(
      dispatch_context,
      pre_root_stage,
    )
  let output =
    run_clustered_finalize_phase(
      dispatch_context,
      pre_root_stage,
      root_phase_output,
    )
  output
}
