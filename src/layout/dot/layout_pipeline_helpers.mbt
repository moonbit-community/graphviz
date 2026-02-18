///|
priv struct LayoutPrep {
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  splines : SplinesMode
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  has_dotted_edges : Bool
  has_port_edges : Bool
  has_edge_labels : Bool
  node_order : Map[String, Int]
  record_orientation : RecordOrientation
  output_sizes : Map[String, NodeSize]
  order_sizes : Map[String, NodeSize]
  sizes : Map[String, NodeSize]
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
priv struct RankData {
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  edge_in_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  all_ranks : Array[Int]
  self_edge_labels : Map[String, Double]
}

///|
priv struct RankHeights {
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  ranksep_pt : Double
}

///|
priv struct ClusterMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
priv struct OrderingResult {
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  vnode_info : EdgeVnodeInfo
  vnode_count : Int
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  edge_order : Map[String, Int]
  edge_cluster_keys : Map[String, String]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
priv struct OrderingEdgePortData {
  edge_order : Map[String, Int]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
priv struct OrderingClass2Data {
  edges_by_tail : Map[String, Array[Int]]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  root_edge_creation : Array[(String, String)]
  skeleton_edge_creation : Array[(String, String)]
  edge_creation_order : Array[(String, String)]
  nlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
priv struct OrderReorderContext {
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_nodes : Array[String]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  creation_order : Array[String]
  order_node_order : Map[String, Int]
}

///|
priv struct OrderMaterializationData {
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_edges_out_unmapped : Array[@cgraph.Edge]
  order_edge_tail_out_unmapped : Array[String]
  order_edge_head_out_unmapped : Array[String]
  order_edge_tail_port_x_unmapped : Array[Double]
  order_edge_head_port_x_unmapped : Array[Double]
  order_edge_tail_port_order_unmapped : Array[Double]
  order_edge_head_port_order_unmapped : Array[Double]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_flat_constraints : Map[String, Bool]
}

///|
priv struct OrderClusteredPreRootStageData {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
}

///|
priv struct OrderingBaseContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
}

///|
priv struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
  vnode_count : Int
}

///|
priv struct OrderingReorderSetup {
  ordering_groups_base : Map[Int, Array[String]]
  base_order_index : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  graphviz_flip : Bool
  flat_rank_constraints : Map[String, Bool]
  class2_data : OrderingClass2Data
  gdnlist_order : Array[String]
  vnode_order_keys_for_ordering : Map[String, Double]
}

///|
/// Graphviz parity: reorder-setup context keeps class2/mincross preparation
/// inputs in Graphviz ordering before setup-stage dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingReorderSetupContext {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  port_edge_nodes : Map[String, Bool]
  vnode_count : Int
  rankdir : RankDir
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: dispatch-setup context keeps edge-port extraction +
/// reorder-setup payload ordering unchanged before setup assembly.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingDispatchSetupContext {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  port_edge_nodes : Map[String, Bool]
  vnode_count : Int
  rankdir : RankDir
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
}

///|
priv struct OrderingDispatchSetup {
  edge_port_data : OrderingEdgePortData
  reorder_setup : OrderingReorderSetup
  nlist_order : Array[String]
  vnode_creation_order : Array[String]
  gdnlist_order : Array[String]
}

///|
/// Graphviz parity: clustered ordering pre-root/root phase context keeps
/// stage setup payload ordering unchanged before stage-phase dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredOrderingPreRootAndRootPhaseContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  reorder_setup : OrderingReorderSetup
  class2_data : OrderingClass2Data
}

///|
/// Graphviz parity: clustered ordering stage dispatch context keeps complete
/// clustered ordering payload ordering unchanged before stage execution.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredOrderingStageDispatchContext {
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
  edge_port_data : OrderingEdgePortData
  reorder_setup : OrderingReorderSetup
  class2_data : OrderingClass2Data
}

///|
/// Graphviz parity: ordering-stage dispatch context keeps clustered/non-cluster
/// branch payload ordering unchanged before dispatch-stage gating.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingStageDispatchContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  dispatch_setup : OrderingDispatchSetup
}

///|
/// Graphviz parity: ordering-dispatch execution context keeps stage inputs,
/// runtime context, and dispatch setup ordering unchanged before execution.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingDispatchPipelineExecutionContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  dispatch_setup : OrderingDispatchSetup
}

///|
/// Graphviz parity: ordering-dispatch pipeline context keeps ordering/runtime
/// payload ordering unchanged before dispatch-setup + execution stages.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingDispatchPipelineContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  rankdir : RankDir
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
}

///|
/// Graphviz parity: ordering+vnode compute input payload keeps ordering/rank/
/// port fields in Graphviz compute_ordering_and_vnodes call sequence.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingAndVnodesInputs {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  rankdir : RankDir
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered pre-root reorder/materialization context keeps
/// stage payload ordering unchanged before reorder/materialize dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredPreRootReorderMaterializedContext {
  order_groups : Map[Int, Array[String]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  base_order_index : Map[String, Int]
  cluster_meta : ClusterMetadata
  port_edge_nodes : Map[String, Bool]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  edge_creation_order : Array[(String, String)]
  edge_tail : Array[String]
  edge_head : Array[String]
  nodes : Array[@cgraph.Node]
}

///|
/// Graphviz parity: clustered pre-root stage context keeps order-group,
/// reorder/materialize, and vnode payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredOrderingPreRootStageContext {
  ordering_groups_base : Map[Int, Array[String]]
  base_order_index : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  vnode_order_keys_for_ordering : Map[String, Double]
  order_sizes : Map[String, NodeSize]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  port_edge_nodes : Map[String, Bool]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  edge_creation_order : Array[(String, String)]
  edge_tail : Array[String]
  edge_head : Array[String]
  nodes : Array[@cgraph.Node]
}

///|
priv struct OrderRootClusterStageData {
  order_groups_for_mincross : Map[Int, Array[String]]
  ordered : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: clustered finalize-stage input payload keeps rank/group,
/// cluster keys/skeleton, order sizes, and vnode ordering fields unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterFinalizeStageInputs {
  order_rank_keys : Array[Int]
  order_groups_for_mincross : Map[Int, Array[String]]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_sizes_out : Map[String, NodeSize]
  ordered : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
  creation_order : Array[String]
}

///|
/// Graphviz parity: finalize-pass dispatch context keeps clustered finalize
/// runtime payload ordering unchanged across cluster-rank/ReMincross phases.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterFinalizePassDispatchContext {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  graphviz_flip : Bool
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  nlist_order : Array[String]
  ranks : Map[String, Int]
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  skeleton_edge_creation : Array[(String, String)]
  root_edge_creation : Array[(String, String)]
  flat_rank_constraints : Map[String, Bool]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  vnode_order_keys_for_ordering : Map[String, Double]
  real_nodes : Map[String, Bool]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  local_cluster_order : Map[String, Int]
  graph : @cgraph.Graph
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  edges_by_tail : Map[String, Array[Int]]
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: final group cleanup dispatch context keeps cluster cleanup
/// branch payload ordering unchanged before clustered ReMincross dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct FinalizeOrderGroupsDispatchContext {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  cluster_rank_order : Map[Int, Map[String, Int]]
  cluster_meta : ClusterMetadata
  local_cluster_order : Map[String, Int]
  ordered_with_vnodes : Map[Int, Array[String]]
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  flat_rank_constraints : Map[String, Bool]
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: root+cluster build_ranks stage input payload keeps root
/// reorder/materialized artifacts and vnode groups unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterBuildRanksStageInputs {
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  order_rank_keys : Array[Int]
  order_groups : Map[Int, Array[String]]
  order_ranks : Map[String, Int]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_edges_out_unmapped : Array[@cgraph.Edge]
  order_edge_tail_out_unmapped : Array[String]
  order_edge_head_out_unmapped : Array[String]
  order_edge_tail_port_x_unmapped : Array[Double]
  order_edge_head_port_x_unmapped : Array[Double]
  order_edge_tail_port_order_unmapped : Array[Double]
  order_edge_head_port_order_unmapped : Array[Double]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: root+cluster build_ranks stage context keeps runtime
/// dispatch payload ordering unchanged across root-reorder/finalize phases.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterBuildRanksStageContext {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  graph : @cgraph.Graph
  cluster_meta : ClusterMetadata
  vnode_order_keys_for_ordering : Map[String, Double]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
  flat_rank_constraints : Map[String, Bool]
  ranks : Map[String, Int]
  vnode_info : EdgeVnodeInfo
}

///|
/// Graphviz parity: root+cluster root-reorder dispatch context keeps seeded
/// build_ranks and root ReMincross payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterRootReorderContext {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  cluster_meta : ClusterMetadata
  vnode_order_keys_for_ordering : Map[String, Double]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
  order_ranks : Map[String, Int]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  flat_rank_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: root ReMincross rank-reorder finalize dispatch context
/// keeps finalize-phase arguments in Graphviz ordering before tuple unpack.
/// Do not change behavior without updating fixtures/tests.
priv struct RootMincrossRankReorderFinalizeDispatchContext {
  order_groups_for_mincross : Map[Int, Array[String]]
  order_cluster_keys : Map[String, String]
  cluster_meta : ClusterMetadata
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: order-edge trace materialization dispatch context keeps
/// mapped/unmapped materialize+trace payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct MaterializeOrderEdgesWithTraceContext {
  nlist_order : Array[String]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  order_ranks : Map[String, Int]
  real_nodes : Map[String, Bool]
}

///|
/// Graphviz parity: clustered ReMincross multi-rank reorder-input context keeps
/// materialization flags, edge arrays, and metadata payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossMultiRankReorderInputsContext {
  creation_order : Array[String]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  flat_rank_constraints : Map[String, Bool]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
}

///|
/// Graphviz parity: clustered ReMincross multi-rank finalize context keeps
/// startpass=2 cleanup payload ordering unchanged before dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossMultiRankFinalizeContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  ranks : Map[String, Int]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: clustered ReMincross multi-rank dispatch context keeps
/// rematerialize + finalize payload ordering unchanged across phase helpers.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossMultiRankDispatchContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  flat_rank_constraints : Map[String, Bool]
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross pass dispatch context keeps
/// rematerialize+cleanup payload ordering unchanged before rank-count branch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossPassDispatchContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  flat_rank_constraints : Map[String, Bool]
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  base_groups : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross reorder-step finalize dispatch context
/// keeps cleanup reorder payload ordering unchanged before tuple unpack.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossReorderStepFinalizeDispatchContext {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  cluster_meta : ClusterMetadata
  rem_node_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
  real_nodes : Map[String, Bool]
}

///|
/// Graphviz parity: clustered ReMincross reorder-step context keeps remapped
/// edge arrays plus cleanup metadata in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossReorderStepContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  ranks : Map[String, Int]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  rem_nodes : Array[String]
  rem_ranks : Map[String, Int]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
}

///|
priv struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  cluster_bbox_heights : Map[String, (Double, Double)]
}

///|
priv struct XposComputationInput {
  x_sizes : Map[String, NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[(String, Int)]
  x_edge_vnodes : Map[String, Array[String]]
  x_slack_edges : Array[ConstraintEdge]
}

///|
priv struct XposVNodeOrderState {
  vnode_order_keys : Map[String, Double]
  has_vnode_order : Bool
}

///|
priv struct XposOrderEdgePortData {
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
}

///|
priv struct XPositionStageSeedData {
  has_vnode_order : Bool
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
priv struct XStageSeedGroupAndClusterData {
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
priv struct XStageSeedOrderAndVNodeData {
  order_index : Map[String, Int]
  vnode_order_state : XposVNodeOrderState
}

///|
priv struct XposFlatLabelAugmentation {
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
priv struct YPositionComputationData {
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
  cluster_bbox_heights : Map[String, (Double, Double)]
}

///|
priv struct PositionOutputMaps {
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
priv struct PositionBoundaryAndVnodeData {
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  vnode_positions : Map[String, @geom.Point]
}

///|
priv struct PositionProjectionData {
  rank_y : Map[Int, Double]
  cluster_bbox_heights : Map[String, (Double, Double)]
  position_output_maps : PositionOutputMaps
}

///|
priv struct XStageWithFlatLabelData {
  use_vnodes_for_xpos : Bool
  virtual_slack_edges : Array[ConstraintEdge]
  x_base_sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
priv struct XStageModeAndSlackData {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
  xpos_reorder_enabled : Bool
  virtual_slack_edges : Array[ConstraintEdge]
}

///|
priv struct XStageSeedAndFlatLabelData {
  x_base_sizes : Map[String, NodeSize]
  flat_label_augmentation : XposFlatLabelAugmentation
}

///|
priv struct XStageModeAndSeedData {
  mode_slack_data : XStageModeAndSlackData
  seed_flat_label_data : XStageSeedAndFlatLabelData
}

///|
priv struct PositionModeFlags {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
  xpos_reorder_enabled : Bool
}

///|
priv struct PositionModeGateValues {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
}

///|
priv struct XposClusteredReorderSeedData {
  order_groups : Map[Int, Array[String]]
  order_sizes : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_node_order : Map[String, Int]
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_nodes : Array[String]
}

///|
priv struct XposClusteredReorderEdgesData {
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
priv struct XposClusteredInputEdgeData {
  tail : String
  head : String
  penalty : Int
  constraint : Bool
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
  vnodes : Array[String]
}

///|
priv struct NonclusterXposReorderInputs {
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  tmp_rank_keys : Array[Int]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: non-cluster ordering stage dispatch context keeps
/// single-pass mincross payload ordering unchanged before stage helpers.
/// Do not change behavior without updating fixtures/tests.
priv struct NonclusterOrderingStageDispatchContext {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  nlist_order : Array[String]
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  cluster_meta : ClusterMetadata
  edge_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
}

///|
priv struct XposTransposeCleanupInputs {
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  tmp_rank_keys : Array[Int]
  tmp_ranks : Map[String, Int]
}

///|
priv struct PositionRankHeightMaps {
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
priv struct ProjectionFromXStageData {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  virtual_slack_edges : Array[ConstraintEdge]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
/// Graphviz parity: rankdir resolution uses option override first, then
/// graph attribute parsing with TB fallback (dotinit/input behavior).
/// Do not change behavior without updating fixtures/tests.
fn resolve_rankdir_for_layout_inputs(
  graph : @cgraph.Graph,
  option_rankdir : RankDir?,
) -> RankDir {
  match option_rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
}

///|
/// Graphviz parity: nodesep/ranksep parse option overrides first, then graph
/// attributes, reject negatives, and clamp with Graphviz minima.
/// Do not change behavior without updating fixtures/tests.
fn resolve_spacing_for_layout_inputs(
  graph : @cgraph.Graph,
  option_nodesep : Double?,
  option_ranksep : Double?,
) -> (Double, Double) raise DotLayoutError {
  let nodesep_raw = match option_nodesep {
    Some(value) => value
    None =>
      match graph.get_attr("nodesep") {
        Some(value) => parse_first_double(value, default_nodesep_in())
        None => default_nodesep_in()
      }
  }
  if nodesep_raw < 0.0 {
    raise DotLayoutError::InvalidGraph(message="nodesep must be non-negative")
  }
  // Graphviz parity: late_double clamps nodesep to MIN_NODESEP.
  let nodesep_in =
    if nodesep_raw < MIN_NODESEP_IN { MIN_NODESEP_IN } else { nodesep_raw }
  let ranksep_raw = match option_ranksep {
    Some(value) => value
    None =>
      match graph.get_attr("ranksep") {
        Some(value) => parse_first_double(value, default_ranksep_in())
        None => default_ranksep_in()
      }
  }
  if ranksep_raw < 0.0 {
    raise DotLayoutError::InvalidGraph(message="ranksep must be non-negative")
  }
  // Graphviz parity: ranksep clamps to MIN_RANKSEP.
  let ranksep_in =
    if ranksep_raw < MIN_RANKSEP_IN { MIN_RANKSEP_IN } else { ranksep_raw }
  (nodesep_in, ranksep_in)
}

///|
/// Graphviz parity: splines mode resolution uses option override first, then
/// graph attribute parsing with Spline fallback.
/// Do not change behavior without updating fixtures/tests.
fn resolve_splines_for_layout_inputs(
  graph : @cgraph.Graph,
  option_splines : SplinesMode?,
) -> SplinesMode {
  match option_splines {
    Some(value) => value
    None =>
      match graph.get_attr("splines") {
        Some(value) =>
          match parse_splines(value) {
            Some(parsed) => parsed
            None => SplinesMode::Spline
          }
        None => SplinesMode::Spline
      }
  }
}

///|
/// Graphviz parity: edge flag scan checks dotted style and explicit ports in
/// edge creation order before downstream ordering setup.
/// Do not change behavior without updating fixtures/tests.
fn scan_edge_flags_for_layout_inputs(
  edges : Array[@cgraph.Edge],
) -> (Bool, Bool) {
  let mut has_dotted_edges = false
  let mut has_port_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
        }
      None => ()
    }
    if !has_port_edges {
      let tail_port = port_is_explicit(edge.tail_port())
      let head_port = port_is_explicit(edge.head_port())
      if tail_port || head_port {
        has_port_edges = true
      }
    }
  }
  (has_dotted_edges, has_port_edges)
}


///|
/// Graphviz parity: node-order seeds follow GD_nlist creation order and apply
/// RL reversal after seeding (matching Graphviz ordering behavior).
/// Do not change behavior without updating fixtures/tests.
fn build_node_order_for_layout_inputs(
  nodes : Array[@cgraph.Node],
  rankdir : RankDir,
) -> Map[String, Int] {
  let node_order : Map[String, Int] = Map::new()
  let nlist_nodes = nodes
  let mut order_idx = 0
  while order_idx < nlist_nodes.length() {
    node_order[nlist_nodes[order_idx].name()] = order_idx
    order_idx = order_idx + 1
  }
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_names : Array[String] = [
      "z_req",
      "z_req1",
      "handle_x",
      "handle_1",
      "mobvm_a_req",
      "mobvm_a_req1",
    ]
    for name in debug_names {
      match node_order.get(name) {
        Some(value) => println("raw_node_order \{name}=\{value}")
        None => ()
      }
    }
  }
  if rankdir == RankDir::RL {
    let total = nodes.length()
    for node in nodes {
      let name = node.name()
      let base = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = total - 1 - base
    }
  }
  node_order
}

///|
/// Graphviz parity: node size maps for output/order/layout are derived once
/// per node, with LR/RL swapping only applied to layout-time sizes.
/// Do not change behavior without updating fixtures/tests.
fn build_size_maps_for_layout_inputs(
  nodes : Array[@cgraph.Node],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> (Map[String, NodeSize], Map[String, NodeSize], Map[String, NodeSize]) {
  let output_sizes : Map[String, NodeSize] = Map::new()
  let order_sizes : Map[String, NodeSize] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = node_size(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      swap_node_size(size)
    } else {
      size
    }
  }
  (output_sizes, order_sizes, sizes)
}

///|
/// Graphviz parity: record/html nodes expose per-port horizontal order offsets
/// (layout_port_offset.x) used by later opposite-endpoint averaging.
/// Do not change behavior without updating fixtures/tests.
fn build_record_port_order_map_for_layout_inputs(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, Map[String, Double]] {
  let record_port_order : Map[String, Map[String, Double]] = Map::new()
  for node in nodes {
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    if has_html || is_record_shape(node) {
      let name = node.name()
      let size = match output_sizes.get(name) {
        Some(value) => value
        None => node_size(node, record_orientation)
      }
      let raw_ports =
        if has_html {
          html_ports(node, { x: 0.0, y: 0.0 }, size)
        } else {
          record_ports(node, { x: 0.0, y: 0.0 }, size, record_orientation)
        }
      let order_map : Map[String, Double] = Map::new()
      for port_name, port in raw_ports {
        let offset = layout_port_offset(port.center, rankdir)
        order_map[port_name] = offset.x
      }
      record_port_order[name] = order_map
    }
  }
  record_port_order
}


///|
/// Graphviz parity: edge-side port-order contributions are accumulated from
/// explicit record/html ports onto opposite endpoints before averaging.
/// Do not change behavior without updating fixtures/tests.
fn accumulate_port_order_contrib_for_layout_inputs(
  edges : Array[@cgraph.Edge],
  record_port_order : Map[String, Map[String, Double]],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[String, (Double, Int)] {
  let order_sum : Map[String, (Double, Int)] = Map::new()
  let update_order = (target : String, anchor : String, port : @cgraph.Port?) => {
    match port {
      Some(value) =>
        match value.name {
          Some(port_name) =>
            match record_port_order.get(anchor) {
              Some(ports) =>
                match ports.get(port_name) {
                  Some(order) => {
                    let (sum, count) = match order_sum.get(target) {
                      Some(value) => value
                      None => (0.0, 0)
                    }
                    order_sum[target] = (sum + order, count + 1)
                    match port_order_contrib.get(target) {
                      Some(list) => list.push((anchor, order))
                      None => port_order_contrib[target] = [(anchor, order)]
                    }
                  }
                  None => ()
                }
              None => ()
            }
          None => ()
        }
      None => ()
    }
  }
  for edge in edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    if port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
      update_order(head_name, tail_name, edge.tail_port())
    }
    if port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
      update_order(tail_name, head_name, edge.head_port())
    }
  }
  order_sum
}


///|
/// Graphviz parity: record/html port order hints are collected for LR/RL only
/// when explicit ports exist, then averaged onto opposite endpoints.
/// Do not change behavior without updating fixtures/tests.
fn build_port_order_metadata_for_layout_inputs(
  rankdir : RankDir,
  has_port_edges : Bool,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> (Map[String, Double], Map[String, Array[(String, Double)]]) {
  let port_order_positions : Map[String, Double] = Map::new()
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) && has_port_edges {
    let record_port_order =
      build_record_port_order_map_for_layout_inputs(
        nodes,
        output_sizes,
        rankdir,
        record_orientation,
      )
    let order_sum =
      accumulate_port_order_contrib_for_layout_inputs(
        edges,
        record_port_order,
        port_order_contrib,
      )
    for name, entry in order_sum {
      let (sum, count) = entry
      if count > 0 {
        port_order_positions[name] = sum / count.to_double()
      }
    }
  }
  (port_order_positions, port_order_contrib)
}


///|
/// Graphviz parity: layout input preparation returns fields in fixed LayoutPrep
/// order consumed by later pipeline stages.
/// Do not change behavior without updating fixtures/tests.
fn build_layout_prep_output(
  rankdir : RankDir,
  nodesep_in : Double,
  ranksep_in : Double,
  splines : SplinesMode,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_dotted_edges : Bool,
  has_port_edges : Bool,
  has_edge_labels : Bool,
  node_order : Map[String, Int],
  record_orientation : RecordOrientation,
  output_sizes : Map[String, NodeSize],
  order_sizes : Map[String, NodeSize],
  sizes : Map[String, NodeSize],
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> LayoutPrep {
  {
    rankdir,
    nodesep_in,
    ranksep_in,
    splines,
    nodes,
    edges,
    has_dotted_edges,
    has_port_edges,
    has_edge_labels,
    node_order,
    record_orientation,
    output_sizes,
    order_sizes,
    sizes,
    port_order_positions,
    port_order_contrib,
  }
}


///|
/// Graphviz parity: layout attribute parsing aligned to refs/graphviz/lib/dotgen/dotinit.c + lib/common/input.c.
/// Do not change behavior without updating fixtures/tests.
fn prepare_layout_inputs(
  graph : @cgraph.Graph,
  opts : DotLayoutOptions,
) -> LayoutPrep raise DotLayoutError {
  let rankdir = resolve_rankdir_for_layout_inputs(graph, opts.rankdir)
  let (nodesep_in, ranksep_in) =
    resolve_spacing_for_layout_inputs(graph, opts.nodesep, opts.ranksep)
  let splines = resolve_splines_for_layout_inputs(graph, opts.splines)
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  dot_trace("layout_dot: start nodes=\{nodes.length()} edges=\{edges.length()}")
  let (has_dotted_edges, has_port_edges) =
    scan_edge_flags_for_layout_inputs(edges)
  let has_edge_labels = graph_has_edge_labels(edges)
  let node_order = build_node_order_for_layout_inputs(nodes, rankdir)
  let record_orientation = record_layout_orientation(rankdir)
  let (output_sizes, order_sizes, sizes) =
    build_size_maps_for_layout_inputs(nodes, rankdir, record_orientation)
  let (port_order_positions, port_order_contrib) =
    build_port_order_metadata_for_layout_inputs(
      rankdir,
      has_port_edges,
      nodes,
      edges,
      output_sizes,
      record_orientation,
    )
  build_layout_prep_output(
    rankdir,
    nodesep_in,
    ranksep_in,
    splines,
    nodes,
    edges,
    has_dotted_edges,
    has_port_edges,
    has_edge_labels,
    node_order,
    record_orientation,
    output_sizes,
    order_sizes,
    sizes,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: undirected graphs seed in/out edge-order buckets in
/// original endpoint order from edge_endpoints_from_edges.
/// Do not change behavior without updating fixtures/tests.
fn build_undirected_edge_order_maps_for_rank_data(
  nodes : Array[@cgraph.Node],
  tail : Array[String],
  head : Array[String],
) -> (Map[String, Array[Int]], Map[String, Array[Int]]) {
  let edge_out_order : Map[String, Array[Int]] = Map::new()
  let edge_in_order : Map[String, Array[Int]] = Map::new()
  for node in nodes {
    let name = node.name()
    edge_out_order[name] = []
    edge_in_order[name] = []
  }
  for i in 0..<tail.length() {
    let t = tail[i]
    let h = head[i]
    match edge_out_order.get(t) {
      Some(list) => list.push(i)
      None => edge_out_order[t] = [i]
    }
    match edge_in_order.get(h) {
      Some(list) => list.push(i)
      None => edge_in_order[h] = [i]
    }
  }
  (edge_out_order, edge_in_order)
}

///|
/// Graphviz parity: directed edge direction/order comes from acyclic.c,
/// while undirected graphs seed in/out orders by original edge endpoints.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_direction_and_order_maps_for_rank_data(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> (
  Array[String],
  Array[String],
  Array[Bool],
  Map[String, Array[Int]],
  Map[String, Array[Int]],
) {
  if graph.kind() == @cgraph.GraphKind::Directed {
    let edge_out_order : Map[String, Array[Int]] = Map::new()
    let edge_in_order : Map[String, Array[Int]] = Map::new()
    let (tail, head, reversed, out_edges, in_edges) =
      acyclic_edge_directions_with_order(graph, nodes, edges)
    for i in 0..<nodes.length() {
      let name = nodes[i].name()
      edge_out_order[name] = out_edges[i].copy()
      edge_in_order[name] = in_edges[i].copy()
    }
    (tail, head, reversed, edge_out_order, edge_in_order)
  } else {
    let (tail, head, reversed) = edge_endpoints_from_edges(edges)
    let (edge_out_order, edge_in_order) =
      build_undirected_edge_order_maps_for_rank_data(nodes, tail, head)
    (tail, head, reversed, edge_out_order, edge_in_order)
  }
}



///|
/// Graphviz parity: undirected rank preprocessing assigns all nodes rank 0,
/// mirroring Graphviz single-rank behavior before ordering stages.
/// Do not change behavior without updating fixtures/tests.
fn build_undirected_zero_ranks_for_rank_data(
  nodes : Array[@cgraph.Node],
) -> Map[String, Int] {
  let base : Map[String, Int] = Map::new()
  for node in nodes {
    base[node.name()] = 0
  }
  base
}

///|
/// Graphviz parity: directed graphs run rank.c flow, while undirected
/// graphs stay on a single rank as in Graphviz dot preprocessing.
/// Do not change behavior without updating fixtures/tests.
fn compute_ranks_for_rank_data(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
) -> Map[String, Int] {
  if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(
      graph,
      nodes,
      edges,
      has_edge_labels,
      edge_tail,
      edge_head,
      edge_reversed,
    )
  } else {
    build_undirected_zero_ranks_for_rank_data(nodes)
  }
}



///|
/// Graphviz parity: rank sweep iterates the closed min..max rank interval from
/// sorted rank keys, including missing intermediate ranks.
/// Do not change behavior without updating fixtures/tests.
fn build_all_ranks_span_for_rank_data(rank_keys : Array[Int]) -> Array[Int] {
  let all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let min_rank = rank_keys[0]
    let max_rank = rank_keys[rank_keys.length() - 1]
    for rank in min_rank..=max_rank {
      all_ranks.push(rank)
    }
  }
  all_ranks
}

///|
/// Graphviz parity: rank groups expand to a continuous rank interval
/// from min to max rank before later per-rank passes.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_keys_and_all_ranks_for_rank_data(
  groups : Map[Int, Array[String]],
) -> (Array[Int], Array[Int]) {
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let all_ranks = build_all_ranks_span_for_rank_data(rank_keys)
  (rank_keys, all_ranks)
}



///|
/// Graphviz parity: rank preprocessing stages consume RankData fields in
/// fixed order for ranking, ordering, and position pipeline steps.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_data_output(
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  edge_in_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  all_ranks : Array[Int],
  self_edge_labels : Map[String, Double],
) -> RankData {
  {
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    edge_in_order,
    ranks,
    groups,
    rank_keys,
    all_ranks,
    self_edge_labels,
  }
}



///|
/// Graphviz parity: rank direction + acyclic edge directions aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/acyclic.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_data(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
) -> RankData {
  let (edge_tail, edge_head, edge_reversed, edge_out_order, edge_in_order) =
    build_edge_direction_and_order_maps_for_rank_data(graph, nodes, edges)
  let ranks = compute_ranks_for_rank_data(
    graph,
    nodes,
    edges,
    has_edge_labels,
    edge_tail,
    edge_head,
    edge_reversed,
  )
  let groups = build_rank_groups(nodes, ranks)
  let (rank_keys, all_ranks) =
    build_rank_keys_and_all_ranks_for_rank_data(groups)
  let self_edge_labels = self_edge_label_half_heights(edges)
  build_rank_data_output(
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    edge_in_order,
    ranks,
    groups,
    rank_keys,
    all_ranks,
    self_edge_labels,
  )
}

///|
/// Graphviz parity: long-edge label midpoint contributes half height to the
/// midpoint rank slot before rank height normalization.
/// Do not change behavior without updating fixtures/tests.
fn update_rank_pht_for_edge_label_midpoint(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rankdir : RankDir,
) -> Unit {
  if !edge_has_label(edge) {
    return
  }
  let tail = edge.tail().name()
  let head = edge.head().name()
  let tail_rank = match ranks.get(tail) {
    Some(value) => value
    None => return
  }
  let head_rank = match ranks.get(head) {
    Some(value) => value
    None => return
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  if max_rank - min_rank <= 1 {
    return
  }
  let label_rank = (min_rank + max_rank) / 2
  let half_height = match edge_mid_label_metrics(edge) {
    Some((width, height)) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        width / 2.0
      } else {
        height / 2.0
      }
    None => 0.0
  }
  let current = match rank_pht.get(label_rank) {
    Some(value) => value
    None => 0.0
  }
  if half_height > current {
    rank_pht[label_rank] = half_height
  }
}



///|
/// Graphviz parity: edge labels can raise intermediate rank half-heights
/// for long edges before vnode rank expansion in rank.c/position.c flow.
/// Do not change behavior without updating fixtures/tests.
fn apply_edge_label_half_heights_for_rank_pht(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rankdir : RankDir,
  has_edge_labels : Bool,
) -> Unit {
  if has_edge_labels {
    for edge in edges {
      update_rank_pht_for_edge_label_midpoint(edge, ranks, rank_pht, rankdir)
    }
  }
}

///|
/// Graphviz parity: initial per-rank half-heights come from the tallest
/// real node (plus self-edge label inflation) in each rank.
/// Do not change behavior without updating fixtures/tests.
fn build_initial_rank_pht_for_rank_heights(
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Map[Int, Double] {
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height = node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
  rank_pht
}



///|
/// Graphviz parity: long edges reserve vnode half-height across intermediate
/// ranks before cluster rank height adjustments.
/// Do not change behavior without updating fixtures/tests.
fn apply_vnode_half_heights_for_rank_pht(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
) -> Unit {
  let vnode_half_height = VNODE_HEIGHT_PT / 2.0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      continue
    }
    for rank in (min_rank + 1)..<max_rank {
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if vnode_half_height > current {
        rank_pht[rank] = vnode_half_height
      }
    }
  }
}



///|
/// Graphviz parity: rank_ht1/rank_ht2 start as symmetric copies of rank_pht
/// before cluster-specific adjustments.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_ht_maps_from_rank_pht(
  all_ranks : Array[Int],
  rank_pht : Map[Int, Double],
) -> (Map[Int, Double], Map[Int, Double]) {
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  (rank_ht1, rank_ht2)
}



///|
/// Graphviz parity: nodesep/ranksep convert from inches to points, and
/// ranksep is halved (rounded) when edge labels participate.
/// Do not change behavior without updating fixtures/tests.
fn resolve_nodesep_and_ranksep_pt_for_rank_heights(
  nodesep_in : Double,
  ranksep_in : Double,
  has_edge_labels : Bool,
) -> (Double, Double) {
  let nodesep_pt = round_int(nodesep_in * 72.0).to_double()
  let mut ranksep_pt_int = round_int(ranksep_in * 72.0)
  if has_edge_labels {
    ranksep_pt_int = (ranksep_pt_int + 1) / 2
  }
  let ranksep_pt = ranksep_pt_int.to_double()
  (nodesep_pt, ranksep_pt)
}



///|
/// Graphviz parity: rank height stage returns fixed RankHeights fields used
/// by downstream y-position and spacing computations.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_heights_output(
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  nodesep_pt : Double,
  ranksep_pt : Double,
) -> RankHeights {
  { rank_pht, rank_ht1, rank_ht2, nodesep_pt, ranksep_pt }
}



///|
/// Graphviz parity: rank height/spacing aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_heights(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rankdir : RankDir,
  nodesep_in : Double,
  ranksep_in : Double,
  has_edge_labels : Bool,
) -> RankHeights {
  let rank_pht = build_initial_rank_pht_for_rank_heights(
    groups,
    rank_keys,
    all_ranks,
    sizes,
    self_edge_labels,
  )
  apply_edge_label_half_heights_for_rank_pht(
    edges,
    ranks,
    rank_pht,
    rankdir,
    has_edge_labels,
  )
  apply_vnode_half_heights_for_rank_pht(edges, ranks, rank_pht)
  let (rank_ht1, rank_ht2) =
    build_rank_ht_maps_from_rank_pht(all_ranks, rank_pht)
  let _ = apply_cluster_rank_heights(
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2, rankdir,
  )
  let (nodesep_pt, ranksep_pt) =
    resolve_nodesep_and_ranksep_pt_for_rank_heights(
      nodesep_in,
      ranksep_in,
      has_edge_labels,
    )
  build_rank_heights_output(
    rank_pht,
    rank_ht1,
    rank_ht2,
    nodesep_pt,
    ranksep_pt,
  )
}

///|
/// Graphviz parity: cluster subgraph node order follows GD_nlist traversal
/// direction and rankdir flip behavior from dotgen cluster ordering.
/// Do not change behavior without updating fixtures/tests.
fn assign_cluster_node_order_for_metadata(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  node_order : Map[String, Int],
  graphviz_flip : Bool,
) -> Unit {
  let creation_order : Map[String, Int] = Map::new()
  for i, node in nodes {
    creation_order[node.name()] = i
  }
  let total_nodes = nodes.length()
  for node in nodes {
    let name = node.name()
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    let base_order = match creation_order.get(name) {
      Some(value) => value
      None => 0
    }
    let order_value =
      if graphviz_flip {
      total_nodes - 1 - base_order
    } else {
      base_order
    }
    node_order[name] = order_value
  }
}

///|
/// Graphviz parity: each cluster contributes one skeleton node per rank
/// (first node encountered in rank order).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_skeleton_for_metadata(
  groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[String, Bool] {
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rank_seen : Map[String, Bool] = Map::new()
  for rank, names in groups {
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let key = "\{cluster}@\{rank}"
      if cluster_rank_seen.get(key) is None {
        cluster_rank_seen[key] = true
        cluster_skeleton[name] = true
      }
    }
  }
  cluster_skeleton
}

///|
/// Graphviz parity: same-rank edges are promoted to flat ordering
/// constraints for clustered metadata reorder paths.
/// Do not change behavior without updating fixtures/tests.
fn append_same_rank_flat_constraints_for_metadata(
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  flat_constraints : Map[String, Bool],
) -> Unit {
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
      let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
      if tail_rank == head_rank {
        flat_constraints["\{tail}|\{head}"] = true
      }
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: cluster min/max rank and first order are collected
/// from cluster member nodes before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_rank_bounds_for_metadata(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  cluster_first_order : Map[String, Int],
) -> Unit {
  for node in nodes {
    let name = node.name()
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    match cluster_max_rank.get(cluster) {
      Some(current) => if rank > current { cluster_max_rank[cluster] = rank }
      None => cluster_max_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      cluster_first_order[cluster] = order_value
    }
  }
}

///|
/// Graphviz parity: cluster rank bounds are collected from member node rank
/// and first appearance order before cluster-order base expansion.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_bounds_for_metadata(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> (Map[String, Int], Map[String, Int], Map[String, Int]) {
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
  collect_cluster_rank_bounds_for_metadata(
    nodes,
    cluster_keys,
    ranks,
    node_order,
    cluster_min_rank,
    cluster_max_rank,
    cluster_first_order,
  )
  (cluster_min_rank, cluster_max_rank, cluster_first_order)
}



///|
/// Graphviz parity: optional cluster order base expansion follows the
/// DOT_CLUSTER_ORDER_BASE debug path used for deterministic cluster spacing.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_order_base_for_metadata(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_first_order : Map[String, Int],
  node_order : Map[String, Int],
) -> Unit {
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = match cluster_first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    cluster_order_list.push((cluster, rank, order))
  }
  let cluster_order_base : Map[String, Int] = Map::new()
  if cluster_order_list.length() > 1 &&
    @sys.get_env_var("DOT_CLUSTER_ORDER_BASE") is Some(_) {
    cluster_order_list.sort_by((a, b) => {
      let (_name_a, rank_a, order_a) = a
      let (_name_b, rank_b, order_b) = b
      if rank_a < rank_b {
        -1
      } else if rank_a > rank_b {
        1
      } else if order_a < order_b {
        -1
      } else if order_a > order_b {
        1
      } else {
        0
      }
    })
    let step = nodes.length() + 1
    let mut base = 0
    for entry in cluster_order_list {
      let (cluster, _rank, _order) = entry
      cluster_order_base[cluster] = base
      base = base + step
    }
    for node in nodes {
      let name = node.name()
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let base_order = match cluster_order_base.get(cluster) {
        Some(value) => value
        None => 0
      }
      let inner = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = base_order + inner
    }
  }
}

///|
/// Graphviz parity: intercluster keys mirror local cluster membership
/// used by Graphviz compound edge ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_intercluster_keys_for_metadata(
  nodes : Array[@cgraph.Node],
) -> Map[String, String] {
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    intercluster_keys[node.name()] = node_local_cluster_key(node)
  }
  intercluster_keys
}

///|
/// Graphviz parity: cluster order and parent map are collected from
/// Graphviz cluster traversal before clustered ordering stages.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_order_and_parents_for_metadata(
  graph : @cgraph.Graph,
) -> (Array[String], Map[String, String?]) {
  let cluster_order : Array[String] = []
  collect_cluster_names_graphviz_order(graph, cluster_order)
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) && cluster_order.length() > 0 {
    let joined = cluster_order.join(" ")
    println("cluster_order \{joined}")
  }
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  (cluster_order, cluster_parents)
}

///|
/// Graphviz parity: cluster key map comes from per-node cluster ownership
/// used throughout clustered ordering and compound-edge setup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_keys_for_metadata(
  nodes : Array[@cgraph.Node],
) -> Map[String, String] {
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = node_cluster_key(node)
  }
  cluster_keys
}



///|
/// Graphviz parity: rank=same groups/order are collected once for clustered
/// ordering constraints, matching Graphviz same-rank preprocessing.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_same_maps_for_metadata(
  graph : @cgraph.Graph,
) -> (Map[String, Int], Map[String, Int]) {
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  (rank_same_groups, rank_same_order)
}



///|
/// Graphviz parity: flat ordering constraints include Graphviz ordering attrs
/// plus same-rank edge constraints before clustered reorder dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_constraints_for_cluster_metadata(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  cluster_keys : Map[String, String],
) -> (Map[String, Bool], Bool) {
  let (flat_constraints, ordering_set) = build_ordering_flat_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    cluster_keys,
  )
  append_same_rank_flat_constraints_for_metadata(
    edge_tail,
    edge_head,
    ranks,
    flat_constraints,
  )
  (flat_constraints, ordering_set)
}



///|
/// Graphviz parity: clustered ordering stage consumes a fixed ClusterMetadata
/// field set assembled from preprocessing helpers.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_metadata_output(
  has_clusters : Bool,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  cluster_order : Array[String],
  cluster_parents : Map[String, String?],
  intercluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  flat_constraints : Map[String, Bool],
  ordering_set : Bool,
) -> ClusterMetadata {
  {
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    cluster_parents,
    intercluster_keys,
    rank_same_groups,
    rank_same_order,
    flat_constraints,
    ordering_set,
  }
}



///|
/// Graphviz parity: cluster metadata/order aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/compound.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_metadata(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  graphviz_flip : Bool,
) -> ClusterMetadata {
  let has_clusters = graph_has_cluster(graph)
  let cluster_keys = build_cluster_keys_for_metadata(nodes)
  assign_cluster_node_order_for_metadata(
    nodes,
    cluster_keys,
    node_order,
    graphviz_flip,
  )
  let cluster_skeleton = build_cluster_skeleton_for_metadata(groups, cluster_keys)
  let (cluster_min_rank, cluster_max_rank, cluster_first_order) =
    build_cluster_rank_bounds_for_metadata(
      nodes,
      cluster_keys,
      ranks,
      node_order,
    )
  let (cluster_order, cluster_parents) = build_cluster_order_and_parents_for_metadata(
    graph,
  )
  apply_cluster_order_base_for_metadata(
    nodes,
    cluster_keys,
    cluster_min_rank,
    cluster_first_order,
    node_order,
  )
  let intercluster_keys = build_intercluster_keys_for_metadata(nodes)
  let (rank_same_groups, rank_same_order) =
    build_rank_same_maps_for_metadata(graph)
  let (flat_constraints, ordering_set) =
    build_flat_constraints_for_cluster_metadata(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      ranks,
      cluster_keys,
    )
  build_cluster_metadata_output(
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    cluster_parents,
    intercluster_keys,
    rank_same_groups,
    rank_same_order,
    flat_constraints,
    ordering_set,
  )
}

///|
/// Graphviz parity: local cluster ordering seeds per-cluster minimum rank and
/// first-seen node order prior to stable cluster sorting.
/// Do not change behavior without updating fixtures/tests.
fn collect_local_cluster_rank_and_first_order(
  nodes : Array[@cgraph.Node],
  local_cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> (Map[String, Int], Map[String, Int]) {
  let min_rank : Map[String, Int] = Map::new()
  let first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = match local_cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match min_rank.get(cluster) {
      Some(current) => if rank < current { min_rank[cluster] = rank }
      None => min_rank[cluster] = rank
    }
    if first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      first_order[cluster] = order_value
    }
  }
  (min_rank, first_order)
}



///|
/// Graphviz parity: local cluster order entries are sorted by min rank, then
/// first node order, then cluster name for deterministic stable ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_sorted_local_cluster_entries(
  min_rank : Map[String, Int],
  first_order : Map[String, Int],
) -> Array[(String, Int, Int)] {
  let entries : Array[(String, Int, Int)] = []
  for cluster, rank in min_rank {
    let order = match first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    entries.push((cluster, rank, order))
  }
  entries.sort_by((a, b) => {
    let (name_a, rank_a, order_a) = a
    let (name_b, rank_b, order_b) = b
    if rank_a < rank_b {
      -1
    } else if rank_a > rank_b {
      1
    } else if order_a < order_b {
      -1
    } else if order_a > order_b {
      1
    } else if name_a < name_b {
      -1
    } else if name_a > name_b {
      1
    } else {
      0
    }
  })
  entries
}



///|
/// Graphviz parity: sorted local cluster entries are assigned contiguous order
/// ids in traversal order for clustered mincross passes.
/// Do not change behavior without updating fixtures/tests.
fn build_local_cluster_order_map_from_entries(
  entries : Array[(String, Int, Int)],
) -> Map[String, Int] {
  let order_map : Map[String, Int] = Map::new()
  let mut idx = 0
  for entry in entries {
    let (cluster, _rank, _order) = entry
    if order_map.get(cluster) is None {
      order_map[cluster] = idx
      idx = idx + 1
    }
  }
  order_map
}



///|
/// Graphviz parity: local cluster ordering uses minrank + first node order (cluster.c).
/// Do not change behavior without updating fixtures/tests.
fn build_local_cluster_order(
  nodes : Array[@cgraph.Node],
  local_cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> Map[String, Int] {
  let (min_rank, first_order) = collect_local_cluster_rank_and_first_order(
    nodes,
    local_cluster_keys,
    ranks,
    node_order,
  )
  let entries = build_sorted_local_cluster_entries(min_rank, first_order)
  build_local_cluster_order_map_from_entries(entries)
}

///|
/// Graphviz parity: cluster parent lookup prefers explicit traversal hints
/// and falls back to collected parent graph edges.
/// Do not change behavior without updating fixtures/tests.
fn resolve_cluster_parent_for_order(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
) -> String? {
  match parents.get(cluster) {
    Some(value) => value
    None =>
      match fallback_parents.get(cluster) {
        Some(value) => value
        None => None
      }
  }
}



///|
fn cluster_depth_for_order(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
  memo : Map[String, Int],
) -> Int {
  match memo.get(cluster) {
    Some(value) => value
    None => {
      let parent_opt =
        resolve_cluster_parent_for_order(cluster, parents, fallback_parents)
      let depth = match parent_opt {
        Some(parent) => cluster_depth_for_order(parent, parents, fallback_parents, memo) + 1
        None => 0
      }
      memo[cluster] = depth
      depth
    }
  }
}

///|
/// Graphviz parity: cluster traversal order index is seeded from Graphviz
/// cluster_order for tie-breaking during local cluster passes.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_index_for_local_reorder(
  cluster_order : Array[String],
) -> Map[String, Int] {
  let cluster_index : Map[String, Int] = Map::new()
  for idx, name in cluster_order {
    cluster_index[name] = idx
  }
  cluster_index
}



///|
/// Graphviz parity: clusters not present in cluster_order sort after known
/// clusters using a stable default index.
/// Do not change behavior without updating fixtures/tests.
fn cluster_index_or_default_for_local_reorder(
  name : String,
  cluster_index : Map[String, Int],
) -> Int {
  match cluster_index.get(name) {
    Some(value) => value
    None => cluster_index.length() + 1
  }
}



///|
/// Graphviz parity: local cluster pass begins from collected cluster names
/// before depth/index tie-break sorting.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_name_list_for_local_reorder(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Array[String] {
  let cluster_names : Array[String] = []
  for name, _ in cluster_graphs {
    cluster_names.push(name)
  }
  cluster_names
}



///|
/// Graphviz parity: cluster-local pass iterates cluster subgraphs in
/// depth-first parent order with cluster_order tie-breaking (cluster.c path).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_graph_order_for_local_reorder(
  graph : @cgraph.Graph,
  cluster_order : Array[String],
  cluster_parents_hint : Map[String, String?],
) -> (Map[String, @cgraph.Graph], Array[String]) {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  let cluster_names = build_cluster_name_list_for_local_reorder(cluster_graphs)
  if cluster_graphs.length() == 0 {
    return (cluster_graphs, cluster_names)
  }
  let cluster_index = build_cluster_index_for_local_reorder(cluster_order)
  let cluster_depth : Map[String, Int] = Map::new()
  if cluster_names.length() > 1 {
    cluster_names.sort_by((a, b) => {
      let a_depth =
        cluster_depth_for_order(a, cluster_parents_hint, cluster_parents, cluster_depth)
      let b_depth =
        cluster_depth_for_order(b, cluster_parents_hint, cluster_parents, cluster_depth)
      if a_depth < b_depth {
        -1
      } else if a_depth > b_depth {
        1
      } else {
        let a_idx = cluster_index_or_default_for_local_reorder(a, cluster_index)
        let b_idx = cluster_index_or_default_for_local_reorder(b, cluster_index)
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
  }
  (cluster_graphs, cluster_names)
}

///|
/// Graphviz parity: local cluster pass pins both real-node and vnode ranks
/// so per-cluster reorder cannot move nodes across global rank slots.
/// Do not change behavior without updating fixtures/tests.
fn build_fixed_ranks_with_vnodes_for_cluster_local_reorder(
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Map[String, Int] {
  let fixed_ranks : Map[String, Int] = Map::new()
  for name, rank in ranks {
    fixed_ranks[name] = rank
  }
  for name, rank in vnode_ranks {
    fixed_ranks[name] = rank
  }
  fixed_ranks
}



///|
/// Graphviz parity: cluster-local mincross keeps global fixed positions and
/// fixed ranks (including vnodes) for constrained reorder passes.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_fixed_positions_and_ranks(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> (Map[String, Double], Map[String, Int]) {
  let fixed_positions = order_positions_from_groups(groups)
  let fixed_ranks = build_fixed_ranks_with_vnodes_for_cluster_local_reorder(
    ranks,
    vnode_ranks,
  )
  (fixed_positions, fixed_ranks)
}

///|
/// Graphviz parity: cluster-local node set uses global node_order as stable
/// seed to create deterministic local node indices.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_nodes_and_order(
  cluster_node_set : Map[String, Bool],
  node_order : Map[String, Int],
) -> (Array[String], Map[String, Int]) {
  let cluster_nodes : Array[String] = []
  for name, _ in cluster_node_set {
    cluster_nodes.push(name)
  }
  let cluster_node_order : Map[String, Int] = Map::new()
  let cluster_ordered_nodes = cluster_nodes.copy()
  if cluster_ordered_nodes.length() > 1 {
    cluster_ordered_nodes.sort_by((a, b) => {
      let a_idx = match node_order.get(a) {
        Some(value) => value
        None => 0
      }
      let b_idx = match node_order.get(b) {
        Some(value) => value
        None => 0
      }
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else if a < b {
        -1
      } else if a > b {
        1
      } else {
        0
      }
    })
  }
  let mut order_idx = 0
  for name in cluster_ordered_nodes {
    cluster_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  (cluster_nodes, cluster_node_order)
}



///|
/// Graphviz parity: local cluster rank groups include only cluster members
/// and keep cluster-local node order as stable sort key.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_rank_groups(
  groups : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
  cluster_node_order : Map[String, Int],
) -> Map[Int, Array[String]] {
  let cluster_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    let list : Array[String] = []
    for name in names {
      if cluster_node_set.get(name) is Some(_) {
        list.push(name)
      }
    }
    if list.length() > 1 {
      let real_nodes : Array[String] = []
      for name in list {
        if !is_edge_vnode_name(name) {
          real_nodes.push(name)
        }
      }
      if real_nodes.length() > 1 {
        real_nodes.sort_by((a, b) => {
          let a_idx = match cluster_node_order.get(a) {
            Some(value) => value
            None => 0
          }
          let b_idx = match cluster_node_order.get(b) {
            Some(value) => value
            None => 0
          }
          if a_idx < b_idx {
            -1
          } else if a_idx > b_idx {
            1
          } else if a < b {
            -1
          } else if a > b {
            1
          } else {
            0
          }
        })
        let mut real_idx = 0
        for i in 0..<list.length() {
          if is_edge_vnode_name(list[i]) {
            continue
          }
          list[i] = real_nodes[real_idx]
          real_idx = real_idx + 1
        }
      }
    }
    if list.length() > 0 {
      cluster_groups[rank] = list
    }
  }
  cluster_groups
}



///|
/// Graphviz parity: cluster-local rank groups follow global node-order seeds
/// before running local mincross in expanded cluster context.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_rank_groups_and_order(
  groups : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
  node_order : Map[String, Int],
) -> (
  Array[String],
  Map[String, Int],
  Map[Int, Array[String]],
  Array[Int],
) {
  if cluster_node_set.length() <= 1 {
    return ([], Map::new(), Map::new(), [])
  }
  let (cluster_nodes, cluster_node_order) =
    build_cluster_local_nodes_and_order(cluster_node_set, node_order)
  let cluster_groups = build_cluster_local_rank_groups(
    groups,
    cluster_node_set,
    cluster_node_order,
  )
  let cluster_rank_keys = collect_rank_keys(cluster_groups)
  (cluster_nodes, cluster_node_order, cluster_groups, cluster_rank_keys)
}

///|
/// Graphviz parity: cluster-local reorder keeps only edges whose endpoints
/// are both inside the expanded cluster graph.
/// Do not change behavior without updating fixtures/tests.
fn collect_internal_cluster_edges_for_local_bundle(
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_node_set : Map[String, Bool],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let cluster_edges : Array[@cgraph.Edge] = []
  let cluster_edge_tail : Array[String] = []
  let cluster_edge_head : Array[String] = []
  let cluster_edge_tail_port_x : Array[Double] = []
  let cluster_edge_head_port_x : Array[Double] = []
  let cluster_edge_tail_port_order : Array[Double] = []
  let cluster_edge_head_port_order : Array[Double] = []
  for i in 0..<order_edges.length() {
    let tail = order_edge_tail[i]
    let head = order_edge_head[i]
    let tail_in = cluster_node_set.get(tail) is Some(_)
    let head_in = cluster_node_set.get(head) is Some(_)
    // Graphviz parity: cluster-local mincross only sees edges whose endpoints
    // are inside the expanded cluster graph (expand_cluster/interclexp).
    if !(tail_in && head_in) {
      continue
    }
    cluster_edges.push(order_edges[i])
    cluster_edge_tail.push(tail)
    cluster_edge_head.push(head)
    cluster_edge_tail_port_x.push(order_edge_tail_port_x[i])
    cluster_edge_head_port_x.push(order_edge_head_port_x[i])
    cluster_edge_tail_port_order.push(order_edge_tail_port_order[i])
    cluster_edge_head_port_order.push(order_edge_head_port_order[i])
  }
  (
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
  )
}



///|
/// Graphviz parity: local cluster edge bundle derives neighbor maps and edge
/// ordering from the filtered in-cluster edge list.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_edge_index_and_order(
  cluster_nodes : Array[String],
  cluster_edges : Array[@cgraph.Edge],
  cluster_edge_tail : Array[String],
  cluster_edge_head : Array[String],
  fixed_ranks : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  let (parents, children) = build_edge_index_for_order_names(
    cluster_nodes,
    cluster_edge_tail,
    cluster_edge_head,
    fixed_ranks,
  )
  let edge_order = collect_edge_order(cluster_edges)
  (parents, children, edge_order)
}



///|
/// Graphviz parity: cluster-local edge bundle keeps only internal expanded
/// cluster edges, preserving per-edge port hints and edge-order indexing.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_edge_bundle(
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_node_set : Map[String, Bool],
  cluster_nodes : Array[String],
  fixed_ranks : Map[String, Int],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
) {
  let (
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
  ) =
    collect_internal_cluster_edges_for_local_bundle(
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      cluster_node_set,
    )
  let (parents, children, edge_order) =
    build_cluster_local_edge_index_and_order(
      cluster_nodes,
      cluster_edges,
      cluster_edge_tail,
      cluster_edge_head,
      fixed_ranks,
    )
  (
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    edge_order,
  )
}

///|
/// Graphviz parity: cluster-local reorder only considers nodes that are
/// present in rank groups and belong to the current cluster (plus local
/// virtual nodes when enabled). Do not change behavior without updating fixtures/tests.
fn build_cluster_local_node_set_for_reorder(
  cluster_graph : @cgraph.Graph,
  cluster : String,
  groups : Map[Int, Array[String]],
  vnode_clusters : Map[String, String],
  order_with_vnodes : Bool,
) -> Map[String, Bool] {
  let cluster_nodes_set : Map[String, Bool] = Map::new()
  let cluster_graph_node_order : Array[String] = []
  for node in cluster_graph.nodes() {
    cluster_nodes_set[node.name()] = true
    cluster_graph_node_order.push(node.name())
  }
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let joined = cluster_graph_node_order.join(" ")
    println("cluster_graph_nodes \{cluster}: \{joined}")
  }
  if order_with_vnodes {
    for vnode, vnode_cluster in vnode_clusters {
      if vnode_cluster == cluster {
        cluster_nodes_set[vnode] = true
      }
    }
  }
  let cluster_node_set : Map[String, Bool] = Map::new()
  for _rank, names in groups {
    for name in names {
      if cluster_nodes_set.get(name) is Some(_) {
        cluster_node_set[name] = true
      }
    }
  }
  cluster_node_set
}

///|
/// Graphviz parity: cluster-local reorder metadata keeps node sizes,
/// local cluster keys, and same-rank flat constraints scoped to the cluster.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_reorder_metadata(
  cluster_node_set : Map[String, Bool],
  order_sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  intercluster_keys : Map[String, String],
  vnode_clusters : Map[String, String],
  flat_constraints : Map[String, Bool],
) -> (Map[String, NodeSize], Map[String, String], Map[String, Bool]) {
  let cluster_sizes : Map[String, NodeSize] = Map::new()
  for name, _ in cluster_node_set {
    match order_sizes.get(name) {
      Some(size) => cluster_sizes[name] = size
      None =>
        match vnode_sizes.get(name) {
          Some(size) => cluster_sizes[name] = size
          None => ()
        }
    }
  }
  let cluster_keys : Map[String, String] = Map::new()
  for name, _ in cluster_node_set {
    let key = match intercluster_keys.get(name) {
      Some(value) => value
      None =>
        match vnode_clusters.get(name) {
          Some(value) => value
          None => ""
        }
    }
    cluster_keys[name] = key
  }
  let cluster_flat_constraints : Map[String, Bool] = Map::new()
  for key, value in flat_constraints {
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        if cluster_node_set.get(tail) is Some(_) &&
          cluster_node_set.get(head) is Some(_) {
          cluster_flat_constraints[key] = value
        }
      }
      None => ()
    }
  }
  (cluster_sizes, cluster_keys, cluster_flat_constraints)
}

///|
/// Graphviz parity: cluster-local reorder writes only cluster members back to
/// existing rank slots, preserving non-cluster node positions.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_local_rank_order_to_groups(
  groups : Map[Int, Array[String]],
  cluster_rank_keys : Array[Int],
  ordered_cluster : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
) -> Unit {
  for rank in cluster_rank_keys {
    let desired = match ordered_cluster.get(rank) {
      Some(list) => list
      None => []
    }
    if desired.length() <= 1 {
      continue
    }
    let names = match groups.get(rank) {
      Some(list) => list
      None => continue
    }
    let mut idx = 0
    let mut pos = 0
    while pos < names.length() && idx < desired.length() {
      if cluster_node_set.get(names[pos]) is Some(_) {
        names[pos] = desired[idx]
        idx = idx + 1
      }
      pos = pos + 1
    }
  }
}

///|
/// Graphviz parity: cluster-local mincross runs only when a cluster has
/// internal ordering constraints; otherwise the input order is preserved.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_local_rank_reorder(
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
  cluster_edges : Array[@cgraph.Edge],
  cluster_edge_tail : Array[String],
  cluster_edge_head : Array[String],
  cluster_edge_tail_port_x : Array[Double],
  cluster_edge_head_port_x : Array[Double],
  cluster_edge_tail_port_order : Array[Double],
  cluster_edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  cluster_node_order : Map[String, Int],
  cluster_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  empty_cluster_skeleton : Map[String, Bool],
  cluster_flat_constraints : Map[String, Bool],
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
) -> (Bool, Map[Int, Array[String]]) {
  if cluster_edges.length() == 0 && cluster_flat_constraints.length() == 0 {
    return (false, Map::new())
  }
  let seeded_by_vnode_interp =
    seed_cluster_local_groups_by_vnode_interpolation(
      cluster_rank_keys,
      cluster_groups,
      fixed_ranks,
      parents,
      children,
    )
  // Graphviz parity: mincross_clust() runs flat_reorder before mincross(g,2).
  let seeded_cluster_groups =
    flat_reorder_rank_groups_graphviz(
      cluster_rank_keys,
      seeded_by_vnode_interp,
      fixed_ranks,
      cluster_flat_constraints,
      false,
    )
  dot_trace_groups("cluster_local_mincross_input", seeded_cluster_groups)
  let ordered_cluster =
    reorder_rank_groups(
      cluster_rank_keys,
      seeded_cluster_groups,
      cluster_edges,
      cluster_edge_tail,
      cluster_edge_head,
      cluster_edge_tail_port_x,
      cluster_edge_head_port_x,
      cluster_edge_tail_port_order,
      cluster_edge_head_port_order,
      parents,
      children,
      cluster_keys,
      rank_same_groups,
      rank_same_order,
      edge_order,
      cluster_node_order,
      cluster_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      Map::new(),
      empty_cluster_skeleton,
      cluster_flat_constraints,
      // Graphviz parity: subgraphs use effective rankdir=TB, so flip is false.
      fixed_positions=fixed_positions,
      fixed_ranks=fixed_ranks,
      graphviz_flip=false,
      // Graphviz parity: cluster-local startpass=2 mincross coalesces
      // parallel edge segments by endpoint+port order and sums xpenalty.
      coalesce_parallel_edges=true,
      startpass=2,
    )
  dot_trace_groups("cluster_local_mincross_output", ordered_cluster)
  (true, ordered_cluster)
}

///|
/// Graphviz parity: cluster-local ND_order seeds vnode positions by
/// interpolating between current tail/head orders inside the cluster.
/// Do not change behavior without updating fixtures/tests.
fn seed_cluster_local_groups_by_vnode_interpolation(
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let order_index : Map[String, Int] = Map::new()
  for rank in cluster_rank_keys {
    let names = match cluster_groups.get(rank) {
      Some(list) => list
      None => []
    }
    for idx, name in names {
      order_index[name] = idx
    }
  }
  let seeded : Map[Int, Array[String]] = Map::new()
  for rank in cluster_rank_keys {
    let names = match cluster_groups.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() <= 1 {
      if names.length() > 0 {
        seeded[rank] = names.copy()
      }
      continue
    }
    let items : Array[(Double, Int, String)] = []
    for idx, name in names {
      let base_order = match order_index.get(name) {
        Some(value) => value
        None => idx
      }
      let mut key = Double::from_int(base_order)
      if is_edge_vnode_name(name) {
        let vnode_rank = match ranks.get(name) {
          Some(value) => value
          None => rank
        }
        let parent_name =
          match parents.get(name) {
            Some(list) => {
              let mut selected : String? = None
              for candidate in list {
                let candidate_rank = match ranks.get(candidate) {
                  Some(value) => value
                  None => vnode_rank - 1
                }
                if candidate_rank < vnode_rank {
                  selected = Some(candidate)
                  break
                }
              }
              match selected {
                Some(value) => value
                None =>
                  if list.length() > 0 { list[0] } else { "" }
              }
            }
            None => ""
          }
        let child_name =
          match children.get(name) {
            Some(list) => {
              let mut selected : String? = None
              for candidate in list {
                let candidate_rank = match ranks.get(candidate) {
                  Some(value) => value
                  None => vnode_rank + 1
                }
                if candidate_rank > vnode_rank {
                  selected = Some(candidate)
                  break
                }
              }
              match selected {
                Some(value) => value
                None =>
                  if list.length() > 0 { list[0] } else { "" }
              }
            }
            None => ""
          }
        if parent_name != "" && child_name != "" {
          let parent_rank = match ranks.get(parent_name) {
            Some(value) => value
            None => vnode_rank - 1
          }
          let child_rank = match ranks.get(child_name) {
            Some(value) => value
            None => vnode_rank + 1
          }
          let parent_order = match order_index.get(parent_name) {
            Some(value) => value
            None => base_order
          }
          let child_order = match order_index.get(child_name) {
            Some(value) => value
            None => base_order
          }
          let (low_rank, high_rank, low_order, high_order) =
            if parent_rank <= child_rank {
              (parent_rank, child_rank, parent_order, child_order)
            } else {
              (child_rank, parent_rank, child_order, parent_order)
            }
          let span = high_rank - low_rank
          if span > 0 {
            let t = Double::from_int(vnode_rank - low_rank) / Double::from_int(span)
            if low_order == high_order {
              key = Double::from_int(low_order) - (1.0 - t)
            } else {
              key =
                Double::from_int(low_order) +
                Double::from_int(high_order - low_order) * t
            }
          }
        }
      }
      items.push((key, idx, name))
    }
    if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
      let parts : Array[String] = []
      for item in items {
        let (k, _i, n) = item
        parts.push("\{n}=\{k}")
      }
      let joined = parts.join(" ")
      println("cluster_local_seed_keys rank \{rank}: \{joined}")
    }
    items.sort_by((a, b) => {
      let (a_key, a_idx, _a_name) = a
      let (b_key, b_idx, _b_name) = b
      let diff = a_key - b_key
      if diff < -0.000000001 {
        -1
      } else if diff > 0.000000001 {
        1
      } else if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
    let reordered : Array[String] = []
    for item in items {
      let (_key, _idx, name) = item
      reordered.push(name)
    }
    seeded[rank] = reordered
  }
  seeded
}

///|
/// Graphviz parity: cluster-local reorder seeds node/rank subsets from the
/// cluster graph before running mincross on local groups only.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_rank_reorder_seed(
  cluster_graph : @cgraph.Graph,
  cluster : String,
  groups : Map[Int, Array[String]],
  vnode_clusters : Map[String, String],
  order_with_vnodes : Bool,
  node_order : Map[String, Int],
) ->
  (
    Map[String, Bool],
    Array[String],
    Map[String, Int],
    Map[Int, Array[String]],
    Array[Int],
  ) {
  let cluster_node_set = build_cluster_local_node_set_for_reorder(
    cluster_graph,
    cluster,
    groups,
    vnode_clusters,
    order_with_vnodes,
  )
  let (
    cluster_nodes,
    cluster_node_order,
    cluster_groups,
    cluster_rank_keys,
  ) =
    build_cluster_local_rank_groups_and_order(
      groups,
      cluster_node_set,
      node_order,
    )
  (
    cluster_node_set,
    cluster_nodes,
    cluster_node_order,
    cluster_groups,
    cluster_rank_keys,
  )
}

///|
/// Graphviz parity: cluster-local reorder edge-bundle phase filters local
/// edges/ports and parent-child maps from the cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_reorder_run_inputs_edge_bundle_phase(
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_node_set : Map[String, Bool],
  cluster_nodes : Array[String],
  fixed_ranks : Map[String, Int],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
) {
  build_cluster_local_edge_bundle(
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    cluster_node_set,
    cluster_nodes,
    fixed_ranks,
  )
}


///|
/// Graphviz parity: cluster-local reorder metadata phase builds cluster-only
/// sizes, cluster keys, and flat-constraint map from filtered node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_reorder_run_inputs_metadata_phase(
  cluster_node_set : Map[String, Bool],
  order_sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  intercluster_keys : Map[String, String],
  vnode_clusters : Map[String, String],
  flat_constraints : Map[String, Bool],
) -> (Map[String, NodeSize], Map[String, String], Map[String, Bool]) {
  build_cluster_local_reorder_metadata(
    cluster_node_set,
    order_sizes,
    vnode_sizes,
    intercluster_keys,
    vnode_clusters,
    flat_constraints,
  )
}


///|
/// Graphviz parity: cluster-local reorder input-output context keeps edge
/// bundle arrays/maps and metadata tuple ordering for local mincross call.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderRunInputsOutputContext {
  cluster_edges : Array[@cgraph.Edge]
  cluster_edge_tail : Array[String]
  cluster_edge_head : Array[String]
  cluster_edge_tail_port_x : Array[Double]
  cluster_edge_head_port_x : Array[Double]
  cluster_edge_tail_port_order : Array[Double]
  cluster_edge_head_port_order : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  edge_order : Map[String, Int]
  cluster_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  cluster_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: cluster-local reorder run-input output tuple alias keeps
/// edge/metadata tuple ordering shared across input/apply dispatch steps.
/// Do not change behavior without updating fixtures/tests.
type ClusterLocalReorderRunInputsOutput = (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, NodeSize],
  Map[String, String],
  Map[String, Bool],
)

///|
/// Graphviz parity: cluster-local reorder input output preserves edge bundle
/// arrays/maps followed by metadata tuple ordering for local mincross call.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_reorder_run_inputs_output(
  context : ClusterLocalReorderRunInputsOutputContext,
) -> ClusterLocalReorderRunInputsOutput {
  (
    context.cluster_edges,
    context.cluster_edge_tail,
    context.cluster_edge_head,
    context.cluster_edge_tail_port_x,
    context.cluster_edge_head_port_x,
    context.cluster_edge_tail_port_order,
    context.cluster_edge_head_port_order,
    context.parents,
    context.children,
    context.edge_order,
    context.cluster_sizes,
    context.cluster_keys,
    context.cluster_flat_constraints,
  )
}


///|
/// Graphviz parity: cluster-local reorder context keeps edge bundle and
/// metadata inputs unchanged before local mincross preprocessing.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderRunInputsContext {
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  cluster_node_set : Map[String, Bool]
  cluster_nodes : Array[String]
  fixed_ranks : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  vnode_sizes : Map[String, NodeSize]
  intercluster_keys : Map[String, String]
  vnode_clusters : Map[String, String]
  flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: cluster-local reorder apply dispatch context keeps
/// tuple-independent apply-phase payload in Graphviz ordering.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderApplyDispatchContext {
  groups : Map[Int, Array[String]]
  cluster_rank_keys : Array[Int]
  cluster_groups : Map[Int, Array[String]]
  cluster_meta : ClusterMetadata
  cluster_node_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  empty_cluster_skeleton : Map[String, Bool]
  fixed_positions : Map[String, Double]
  fixed_ranks : Map[String, Int]
  cluster_node_set : Map[String, Bool]
}


///|
/// Graphviz parity: cluster-local reorder builds internal edge bundle and
/// metadata maps from the same filtered cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_reorder_run_inputs(
  context : ClusterLocalReorderRunInputsContext,
) -> ClusterLocalReorderRunInputsOutput {
  let (
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    edge_order,
  ) =
    build_cluster_local_reorder_run_inputs_edge_bundle_phase(
      context.order_edges,
      context.order_edge_tail,
      context.order_edge_head,
      context.order_edge_tail_port_x,
      context.order_edge_head_port_x,
      context.order_edge_tail_port_order,
      context.order_edge_head_port_order,
      context.cluster_node_set,
      context.cluster_nodes,
      context.fixed_ranks,
    )
  let (cluster_sizes, cluster_keys, cluster_flat_constraints) =
    build_cluster_local_reorder_run_inputs_metadata_phase(
      context.cluster_node_set,
      context.order_sizes,
      context.vnode_sizes,
      context.intercluster_keys,
      context.vnode_clusters,
      context.flat_constraints,
    )
  let output_context : ClusterLocalReorderRunInputsOutputContext = {
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    edge_order,
    cluster_sizes,
    cluster_keys,
    cluster_flat_constraints,
  }
  build_cluster_local_reorder_run_inputs_output(output_context)
}

///|
/// Graphviz parity: each cluster-local reorder pass reuses global fixed slots,
/// but only mutates rank entries that belong to that cluster.
/// Do not change behavior without updating fixtures/tests.
fn reorder_single_cluster_rank_groups(
  cluster : String,
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
  empty_cluster_skeleton : Map[String, Bool],
  order_with_vnodes : Bool,
) -> Unit {
  let (
    cluster_node_set,
    cluster_nodes,
    cluster_node_order,
    cluster_groups,
    cluster_rank_keys,
  ) =
    build_cluster_local_rank_reorder_seed(
      cluster_graph,
      cluster,
      groups,
      vnode_info.vnode_clusters,
      order_with_vnodes,
      node_order,
    )
  if cluster_rank_keys.length() == 0 {
    return ()
  }
  run_cluster_local_rank_reorder_execution_phase(
    groups,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    cluster_meta,
    vnode_info,
    fixed_positions,
    fixed_ranks,
    empty_cluster_skeleton,
    cluster_node_set,
    cluster_nodes,
    cluster_node_order,
    cluster_groups,
    cluster_rank_keys,
  )
}

///|
/// Graphviz parity: cluster-local reorder execution input phase builds
/// cluster-scoped edge and metadata tuples before local apply phase.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_local_rank_reorder_execution_phase_input_phase(
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_node_set : Map[String, Bool],
  cluster_nodes : Array[String],
  fixed_ranks : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> ClusterLocalReorderRunInputsOutput {
  let input_context : ClusterLocalReorderRunInputsContext = {
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    cluster_node_set,
    cluster_nodes,
    fixed_ranks,
    order_sizes,
    vnode_sizes: vnode_info.vnode_sizes,
    intercluster_keys: cluster_meta.intercluster_keys,
    vnode_clusters: vnode_info.vnode_clusters,
    flat_constraints: cluster_meta.flat_constraints,
  }
  build_cluster_local_reorder_run_inputs(input_context)
}


///|
/// Graphviz parity: cluster-local reorder apply dispatch reads input-phase
/// tuple and forwards cluster-scoped payload in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_local_rank_reorder_execution_phase_apply_phase_from_input_output(
  dispatch_context : ClusterLocalReorderApplyDispatchContext,
  input_phase_output : ClusterLocalReorderRunInputsOutput,
) -> Unit {
  let (
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    edge_order,
    cluster_sizes,
    cluster_keys,
    cluster_flat_constraints,
  ) = input_phase_output
  run_cluster_local_rank_reorder_execution_phase_apply_phase(
    dispatch_context.groups,
    dispatch_context.cluster_rank_keys,
    dispatch_context.cluster_groups,
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    cluster_keys,
    dispatch_context.cluster_meta,
    edge_order,
    dispatch_context.cluster_node_order,
    cluster_sizes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    dispatch_context.empty_cluster_skeleton,
    cluster_flat_constraints,
    dispatch_context.fixed_positions,
    dispatch_context.fixed_ranks,
    dispatch_context.cluster_node_set,
  )
}


///|
/// Graphviz parity: cluster-local reorder execution phase builds cluster-scoped
/// edge/metadata inputs before applying local mincross results back to groups.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_local_rank_reorder_execution_phase(
  groups : Map[Int, Array[String]],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
  empty_cluster_skeleton : Map[String, Bool],
  cluster_node_set : Map[String, Bool],
  cluster_nodes : Array[String],
  cluster_node_order : Map[String, Int],
  cluster_groups : Map[Int, Array[String]],
  cluster_rank_keys : Array[Int],
) -> Unit {
  let input_phase_output =
    run_cluster_local_rank_reorder_execution_phase_input_phase(
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      cluster_node_set,
      cluster_nodes,
      fixed_ranks,
      order_sizes,
      cluster_meta,
      vnode_info,
    )
  let dispatch_context : ClusterLocalReorderApplyDispatchContext = {
    groups,
    cluster_rank_keys,
    cluster_groups,
    cluster_meta,
    cluster_node_order,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    empty_cluster_skeleton,
    fixed_positions,
    fixed_ranks,
    cluster_node_set,
  }
  run_cluster_local_rank_reorder_execution_phase_apply_phase_from_input_output(
    dispatch_context,
    input_phase_output,
  )
}


///|
/// Graphviz parity: cluster-local reorder apply phase forwards cluster-scoped
/// reorder inputs into local mincross apply without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_local_rank_reorder_execution_phase_apply_phase(
  groups : Map[Int, Array[String]],
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
  cluster_edges : Array[@cgraph.Edge],
  cluster_edge_tail : Array[String],
  cluster_edge_head : Array[String],
  cluster_edge_tail_port_x : Array[Double],
  cluster_edge_head_port_x : Array[Double],
  cluster_edge_tail_port_order : Array[Double],
  cluster_edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  cluster_node_order : Map[String, Int],
  cluster_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  empty_cluster_skeleton : Map[String, Bool],
  cluster_flat_constraints : Map[String, Bool],
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
  cluster_node_set : Map[String, Bool],
) -> Unit {
  run_and_apply_cluster_local_rank_reorder(
    groups,
    cluster_rank_keys,
    cluster_groups,
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents,
    children,
    cluster_keys,
    cluster_meta,
    edge_order,
    cluster_node_order,
    cluster_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    empty_cluster_skeleton,
    cluster_flat_constraints,
    fixed_positions,
    fixed_ranks,
    cluster_node_set,
  )
}


///|
/// Graphviz parity: local cluster reorder runs mincross with cluster-restricted
/// maps and applies results only when internal constraints exist.
/// Do not change behavior without updating fixtures/tests.
fn run_and_apply_cluster_local_rank_reorder(
  groups : Map[Int, Array[String]],
  cluster_rank_keys : Array[Int],
  cluster_groups : Map[Int, Array[String]],
  cluster_edges : Array[@cgraph.Edge],
  cluster_edge_tail : Array[String],
  cluster_edge_head : Array[String],
  cluster_edge_tail_port_x : Array[Double],
  cluster_edge_head_port_x : Array[Double],
  cluster_edge_tail_port_order : Array[Double],
  cluster_edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  cluster_node_order : Map[String, Int],
  cluster_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  empty_cluster_skeleton : Map[String, Bool],
  cluster_flat_constraints : Map[String, Bool],
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
  cluster_node_set : Map[String, Bool],
) -> Unit {
  let (has_internal_constraints, ordered_cluster) =
    run_cluster_local_rank_reorder(
      cluster_rank_keys,
      cluster_groups,
      cluster_edges,
      cluster_edge_tail,
      cluster_edge_head,
      cluster_edge_tail_port_x,
      cluster_edge_head_port_x,
      cluster_edge_tail_port_order,
      cluster_edge_head_port_order,
      parents,
      children,
      cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      edge_order,
      cluster_node_order,
      cluster_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      empty_cluster_skeleton,
      cluster_flat_constraints,
      fixed_positions,
      fixed_ranks,
    )
  if !has_internal_constraints {
    return ()
  }
  apply_cluster_local_rank_order_to_groups(
    groups,
    cluster_rank_keys,
    ordered_cluster,
    cluster_node_set,
  )
}

///|
/// Graphviz parity: cluster-local reorder iterates clusters in deterministic
/// build order and applies one independent local pass per cluster.
/// Do not change behavior without updating fixtures/tests.
fn reorder_cluster_rank_groups_for_cluster_names(
  cluster_names : Array[String],
  cluster_graphs : Map[String, @cgraph.Graph],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  fixed_positions : Map[String, Double],
  fixed_ranks : Map[String, Int],
  empty_cluster_skeleton : Map[String, Bool],
  order_with_vnodes : Bool,
) -> Unit {
  for cluster in cluster_names {
    let cluster_graph = match cluster_graphs.get(cluster) {
      Some(value) => value
      None => continue
    }
    reorder_single_cluster_rank_groups(
      cluster,
      cluster_graph,
      groups,
      node_order,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      cluster_meta,
      vnode_info,
      fixed_positions,
      fixed_ranks,
      empty_cluster_skeleton,
      order_with_vnodes,
    )
  }
}


///|
/// Graphviz parity: cluster-local passes share one immutable fixed-slot snapshot
/// and an empty local skeleton map across cluster iterations.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_reorder_shared_state(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> (Map[String, Bool], Map[String, Double], Map[String, Int]) {
  let empty_cluster_skeleton : Map[String, Bool] = Map::new()
  let (fixed_positions, fixed_ranks) =
    build_cluster_local_fixed_positions_and_ranks(
      groups,
      ranks,
      vnode_ranks,
    )
  (empty_cluster_skeleton, fixed_positions, fixed_ranks)
}

///|
/// Graphviz parity: cluster-local reorder only runs when cluster build order
/// yields materialized cluster subgraphs in deterministic traversal order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_graph_order_for_build_ranks(
  graph : @cgraph.Graph,
  cluster_order : Array[String],
  cluster_parents : Map[String, String?],
) -> (Map[String, @cgraph.Graph], Array[String])? {
  if cluster_order.length() == 0 {
    return None
  }
  let (cluster_graphs, cluster_names) =
    build_cluster_graph_order_for_local_reorder(
      graph,
      cluster_order,
      cluster_parents,
    )
  if cluster_graphs.length() == 0 {
    return None
  }
  Some((cluster_graphs, cluster_names))
}

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
fn reorder_groups_by_cluster_build_ranks(
  graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  order_with_vnodes : Bool,
) -> Unit {
  let (cluster_graphs, cluster_names) =
    match build_cluster_graph_order_for_build_ranks(
      graph,
      cluster_meta.cluster_order,
      cluster_meta.cluster_parents,
    ) {
      Some(value) => value
      None => return ()
    }
  let (empty_cluster_skeleton, fixed_positions, fixed_ranks) =
    build_cluster_local_reorder_shared_state(
      groups,
      ranks,
      vnode_info.vnode_ranks,
    )
  reorder_cluster_rank_groups_for_cluster_names(
    cluster_names,
    cluster_graphs,
    groups,
    node_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    cluster_meta,
    vnode_info,
    fixed_positions,
    fixed_ranks,
    empty_cluster_skeleton,
    order_with_vnodes,
  )
}

///|
/// Graphviz parity: rank=same does not impose ordering constraints.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_same_constraints(
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  Map::new()
}

///|
/// Graphviz parity: order-edge endpoint names may map to swapped virtual
/// directions, so corresponding tail/head ports must be remapped per endpoint.
/// Do not change behavior without updating fixtures/tests.
fn resolve_order_edge_names_and_ports(
  edge : @cgraph.Edge,
  idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (String, String, @cgraph.Port?, @cgraph.Port?) {
  let tail_name =
    if idx < edge_tail.length() { edge_tail[idx] } else { edge.tail().name() }
  let head_name =
    if idx < edge_head.length() { edge_head[idx] } else { edge.head().name() }
  let orig_tail = edge.tail().name()
  let orig_head = edge.head().name()
  let tail_port =
    if tail_name == orig_tail {
      edge.tail_port()
    } else if tail_name == orig_head {
      edge.head_port()
    } else {
      edge.tail_port()
    }
  let head_port =
    if head_name == orig_head {
      edge.head_port()
    } else if head_name == orig_tail {
      edge.tail_port()
    } else {
      edge.head_port()
    }
  (tail_name, head_name, tail_port, head_port)
}

///|
/// Graphviz parity: order-edge endpoint remap is computed once per edge index
/// and reused by both port-offset and port-order passes.
/// Do not change behavior without updating fixtures/tests.
fn collect_order_edge_endpoint_ports(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Array[String], Array[String], Array[@cgraph.Port?], Array[@cgraph.Port?]) {
  let tail_names : Array[String] = []
  let head_names : Array[String] = []
  let tail_ports : Array[@cgraph.Port?] = []
  let head_ports : Array[@cgraph.Port?] = []
  let mut idx = 0
  while idx < edges.length() {
    let edge = edges[idx]
    let (tail_name, head_name, tail_port, head_port) =
      resolve_order_edge_names_and_ports(
        edge,
        idx,
        edge_tail,
        edge_head,
      )
    tail_names.push(tail_name)
    head_names.push(head_name)
    tail_ports.push(tail_port)
    head_ports.push(head_port)
    idx = idx + 1
  }
  (tail_names, head_names, tail_ports, head_ports)
}

///|
/// Graphviz parity: per-edge tail/head x-offset samples are emitted in edge
/// sequence order after endpoint-name/port remap.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_port_offsets_from_endpoint_ports(
  edges : Array[@cgraph.Edge],
  tail_names : Array[String],
  head_names : Array[String],
  tail_ports : Array[@cgraph.Port?],
  head_ports : Array[@cgraph.Port?],
  port_offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  let tail_offsets : Array[Double] = []
  let head_offsets : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    let tail_x =
      edge_port_offset(
        tail_names[idx],
        tail_ports[idx],
        port_offsets,
        sizes,
      )
    let head_x =
      edge_port_offset(
        head_names[idx],
        head_ports[idx],
        port_offsets,
        sizes,
      )
    tail_offsets.push(tail_x)
    head_offsets.push(head_x)
    idx = idx + 1
  }
  (tail_offsets, head_offsets)
}

///|
/// Graphviz parity: port-sampling inputs reuse one endpoint remap + per-node
/// port offset table so x-offset and order passes share identical edge context.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_port_sampling_inputs(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (
  Map[String, Map[String, RecordPort]],
  Array[String],
  Array[String],
  Array[@cgraph.Port?],
  Array[@cgraph.Port?],
) {
  let port_offsets = port_offsets_for_nodes(nodes, sizes)
  let (tail_names, head_names, tail_ports, head_ports) =
    collect_order_edge_endpoint_ports(
      edges,
      edge_tail,
      edge_head,
    )
  (port_offsets, tail_names, head_names, tail_ports, head_ports)
}

///|
/// Graphviz parity: port x offsets for mincross tie-breaks (mincross.c).
/// Do not change behavior without updating fixtures/tests.
fn compute_edge_port_positions(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  if edges.length() == 0 {
    return ([], [])
  }
  let (port_offsets, tail_names, head_names, tail_ports, head_ports) =
    build_edge_port_sampling_inputs(
      nodes,
      edges,
      edge_tail,
      edge_head,
      sizes,
    )
  build_edge_port_offsets_from_endpoint_ports(
    edges,
    tail_names,
    head_names,
    tail_ports,
    head_ports,
    port_offsets,
    sizes,
  )
}

///|
/// Graphviz parity: per-edge tail/head port-order samples are emitted in edge
/// sequence order using the same endpoint remap as tie-break x-offsets.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_port_orders_from_endpoint_ports(
  edges : Array[@cgraph.Edge],
  tail_names : Array[String],
  head_names : Array[String],
  tail_ports : Array[@cgraph.Port?],
  head_ports : Array[@cgraph.Port?],
  port_offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> (Array[Double], Array[Double]) {
  let tail_orders : Array[Double] = []
  let head_orders : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    let tail_order =
      edge_port_order(
        tail_names[idx],
        tail_ports[idx],
        port_offsets,
        sizes,
        rankdir,
      )
    let head_order =
      edge_port_order(
        head_names[idx],
        head_ports[idx],
        port_offsets,
        sizes,
        rankdir,
      )
    tail_orders.push(tail_order)
    head_orders.push(head_order)
    idx = idx + 1
  }
  (tail_orders, head_orders)
}

///|
/// Graphviz parity: port order fractions for mincross medians
/// (shapes.c compassPort + mincross.c VAL/MC_SCALE).
/// Do not change behavior without updating fixtures/tests.
fn compute_edge_port_orders(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double]) {
  if edges.length() == 0 {
    return ([], [])
  }
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let (port_offsets, tail_names, head_names, tail_ports, head_ports) =
    build_edge_port_sampling_inputs(
      nodes,
      edges,
      edge_tail,
      edge_head,
      sizes,
    )
  build_edge_port_orders_from_endpoint_ports(
    edges,
    tail_names,
    head_names,
    tail_ports,
    head_ports,
    port_offsets,
    sizes,
    rankdir,
  )
}

///|
/// Graphviz parity: ND_in order follows edge sequence (AGSEQ) within each
/// fixed head, preserving edge creation insertion order.
/// Do not change behavior without updating fixtures/tests.
fn build_graphviz_in_entries_from_edge_sequence(
  edge_creation_order : Array[(String, String)],
) -> Map[String, Array[String]] {
  let in_entries : Map[String, Array[String]] = Map::new()
  for edge in edge_creation_order {
    let (tail, head) = edge
    match in_entries.get(head) {
      Some(list) => list.push(tail)
      None => in_entries[head] = [tail]
    }
  }
  in_entries
}

///|
/// Graphviz parity: ND_out keeps tail-local edge insertion order for heads,
/// mirroring Graphviz AGSEQ traversal on each tail adjacency list.
/// Do not change behavior without updating fixtures/tests.
fn collect_graphviz_out_heads(
  entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)],
) -> Array[String] {
  let heads : Array[String] = []
  for entry in entries {
    let (_t, h, _pen, _constraint, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) =
      entry
    heads.push(h)
  }
  heads
}

///|
/// Graphviz parity: ND_out/ND_in neighbor maps are pre-seeded for every order
/// node before edge insertion replay to match Graphviz empty-adjacency behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_empty_graphviz_neighbor_maps(
  order_nodes : Array[String],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

///|
/// Graphviz parity: ND_in map assignment replays AGSEQ-derived head buckets
/// directly onto pre-seeded neighbor maps.
/// Do not change behavior without updating fixtures/tests.
fn assign_graphviz_in_neighbors_from_edge_sequence(
  graphviz_in_neighbors : Map[String, Array[String]],
  edge_creation_order : Array[(String, String)],
) -> Unit {
  let in_entries = build_graphviz_in_entries_from_edge_sequence(
    edge_creation_order,
  )
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
}

///|
/// Graphviz parity: ND_out assignment replays AGSEQ-ordered tail adjacency
/// lists directly onto pre-seeded neighbor maps.
/// Do not change behavior without updating fixtures/tests.
fn assign_graphviz_out_neighbors_from_tail_entries(
  graphviz_out_neighbors : Map[String, Array[String]],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Unit {
  for tail, entries in order_edges_by_tail {
    graphviz_out_neighbors[tail] = collect_graphviz_out_heads(entries)
  }
}

///|
/// Graphviz parity: ND_out/ND_in neighbor order follows edge insertion (AGSEQ).
/// Do not change behavior without updating fixtures/tests.
fn build_graphviz_neighbor_maps(
  order_nodes : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let (graphviz_out_neighbors, graphviz_in_neighbors) =
    build_empty_graphviz_neighbor_maps(order_nodes)
  assign_graphviz_out_neighbors_from_tail_entries(
    graphviz_out_neighbors,
    order_edges_by_tail,
  )
  assign_graphviz_in_neighbors_from_edge_sequence(
    graphviz_in_neighbors,
    edge_creation_order,
  )
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

///|
/// Graphviz parity: flat constraints are copied before local augmentation.
/// Do not change behavior without updating fixtures/tests.
fn clone_flat_constraints(
  flat_constraints : Map[String, Bool],
) -> Map[String, Bool] {
  let cloned : Map[String, Bool] = Map::new()
  for key, value in flat_constraints {
    cloned[key] = value
  }
  cloned
}

///|
/// Graphviz parity: prepended cluster skeleton edges must stay ahead of
/// previously collected tail edges during class2 ordering.
/// Do not change behavior without updating fixtures/tests.
fn prepend_order_edge_entry(
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  tail_name : String,
  entry : (String, String, Int, Bool, Double, Double, Double, Double),
) -> Unit {
  match order_edges_by_tail.get(tail_name) {
    Some(list) => {
      let updated : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = [entry]
      for item in list {
        updated.push(item)
      }
      order_edges_by_tail[tail_name] = updated
    }
    None => order_edges_by_tail[tail_name] = [entry]
  }
}

///|
/// Graphviz parity: cluster skeleton node naming uses
/// CLUSTER_SKELETON_PREFIX + cluster + @rank across all class2 passes.
/// Do not change behavior without updating fixtures/tests.
fn cluster_skeleton_name_for_rank(cluster : String, rank : Int) -> String {
  "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
}

///|
/// Graphviz parity: cluster skeleton names expand to one deterministic token
/// per rank between min/max bounds using CLUSTER_SKELETON_PREFIX naming.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_rank_span(
  cluster_skeleton_creation : Array[String],
  cluster : String,
  min_rank : Int,
  max_rank : Int,
) -> Unit {
  for rank in min_rank..=max_rank {
    cluster_skeleton_creation.push(
      cluster_skeleton_name_for_rank(cluster, rank),
    )
  }
}

///|
/// Graphviz parity: cluster skeleton max rank falls back to min rank when
/// cluster_max_rank has no entry for the cluster.
/// Do not change behavior without updating fixtures/tests.
fn cluster_skeleton_max_rank_or_min(
  cluster_max_rank : Map[String, Int],
  cluster : String,
  min_rank : Int,
) -> Int {
  match cluster_max_rank.get(cluster) {
    Some(value) => value
    None => min_rank
  }
}

///|
/// Graphviz parity: cluster skeleton creation follows cluster_order first,
/// then remaining cluster_min_rank iteration order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_skeleton_creation(
  order_with_clusters : Bool,
  cluster_order : Array[String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Array[String] {
  let cluster_skeleton_creation : Array[String] = []
  if !order_with_clusters {
    return cluster_skeleton_creation
  }
  let cluster_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_order {
    match cluster_min_rank.get(cluster) {
      Some(min_rank) => {
        let max_rank =
          cluster_skeleton_max_rank_or_min(cluster_max_rank, cluster, min_rank)
        append_cluster_skeleton_rank_span(
          cluster_skeleton_creation,
          cluster,
          min_rank,
          max_rank,
        )
        cluster_seen[cluster] = true
      }
      None => ()
    }
  }
  for cluster, min_rank in cluster_min_rank {
    if cluster_seen.get(cluster) is Some(_) {
      continue
    }
    let max_rank =
      cluster_skeleton_max_rank_or_min(cluster_max_rank, cluster, min_rank)
    append_cluster_skeleton_rank_span(
      cluster_skeleton_creation,
      cluster,
      min_rank,
      max_rank,
    )
  }
  cluster_skeleton_creation
}

///|
/// Graphviz parity: cluster skeleton CL_CROSS edges are inserted at the front
/// of both local and root tail maps to preserve class2 traversal priority.
/// Do not change behavior without updating fixtures/tests.
fn prepend_cluster_skeleton_edge_to_local_and_root(
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  tail_name : String,
  entry : (String, String, Int, Bool, Double, Double, Double, Double),
) -> Unit {
  prepend_order_edge_entry(
    order_edges_by_tail,
    tail_name,
    entry,
  )
  prepend_order_edge_entry(
    order_edges_by_tail_root,
    tail_name,
    entry,
  )
}

///|
/// Graphviz parity: cluster skeleton edges form a rank-by-rank CL_CROSS chain
/// and must be prepended to both local and root order-edge maps.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_edges(
  cluster : String,
  min_rank : Int,
  max_rank : Int,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
) -> Unit {
  let mut rank = min_rank
  while rank < max_rank {
    let tail_name = cluster_skeleton_name_for_rank(cluster, rank)
    let head_name = cluster_skeleton_name_for_rank(cluster, rank + 1)
    let entry = (tail_name, head_name, CL_CROSS, true, 0.0, 0.0, 0.5, 0.5)
    skeleton_edge_creation.push((tail_name, head_name))
    prepend_cluster_skeleton_edge_to_local_and_root(
      order_edges_by_tail,
      order_edges_by_tail_root,
      tail_name,
      entry,
    )
    rank = rank + 1
  }
}

///|
/// Graphviz parity: class2 order_creation keeps first-seen insertion order,
/// suppressing duplicates across skeleton, real-node, and vnode phases.
/// Do not change behavior without updating fixtures/tests.
fn append_order_creation_name_if_absent(
  order_creation : Array[String],
  order_seen : Map[String, Bool],
  name : String,
) -> Unit {
  if order_seen.get(name) is None {
    order_seen[name] = true
    order_creation.push(name)
  }
}

///|
/// Graphviz parity: vnode creation order is the stable subsequence of
/// order_creation names prefixed with EDGE_VNODE_PREFIX.
/// Do not change behavior without updating fixtures/tests.
fn collect_vnode_creation_order_from_order_creation(
  order_creation : Array[String],
) -> Array[String] {
  let vnode_creation_order : Array[String] = []
  for name in order_creation {
    if name.has_prefix(EDGE_VNODE_PREFIX) {
      vnode_creation_order.push(name)
    }
  }
  vnode_creation_order
}

///|
/// Graphviz parity: each real-node tail emits itself first, followed by its
/// per-tail vnode sequence, while preserving first-seen dedup semantics.
/// Do not change behavior without updating fixtures/tests.
fn append_order_creation_tail_and_vnodes(
  order_creation : Array[String],
  order_seen : Map[String, Bool],
  tail_name : String,
  vnode_creation_by_tail : Map[String, Array[String]],
) -> Unit {
  append_order_creation_name_if_absent(
    order_creation,
    order_seen,
    tail_name,
  )
  let vnodes = match vnode_creation_by_tail.get(tail_name) {
    Some(list) => list
    None => []
  }
  for vnode in vnodes {
    append_order_creation_name_if_absent(
      order_creation,
      order_seen,
      vnode,
    )
  }
}

///|
/// Graphviz parity: class2 order_creation starts with cluster skeletons, then
/// agfstnode real nodes interleaved with edge-vnodes per tail.
/// Do not change behavior without updating fixtures/tests.
fn build_order_creation_with_vnodes(
  cluster_skeleton_creation : Array[String],
  creation_order : Array[String],
  vnode_creation_by_tail : Map[String, Array[String]],
) -> (Array[String], Array[String]) {
  let order_creation : Array[String] = []
  let order_seen : Map[String, Bool] = Map::new()
  for name in cluster_skeleton_creation {
    append_order_creation_name_if_absent(
      order_creation,
      order_seen,
      name,
    )
  }
  for tail_name in creation_order {
    append_order_creation_tail_and_vnodes(
      order_creation,
      order_seen,
      tail_name,
      vnode_creation_by_tail,
    )
  }
  let vnode_creation_order =
    collect_vnode_creation_order_from_order_creation(order_creation)
  (order_creation, vnode_creation_order)
}

///|
/// Graphviz parity: cluster membership lookup treats missing keys as
/// non-cluster entries across class2 preprocessing passes.
/// Do not change behavior without updating fixtures/tests.
fn cluster_key_or_empty(
  cluster_keys : Map[String, String],
  name : String,
) -> String {
  match cluster_keys.get(name) {
    Some(value) => value
    None => ""
  }
}

///|
/// Graphviz parity: cluster flip preprocessing first buckets nlist nodes by
/// cluster key while skipping non-cluster entries.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_nodes_for_flip(
  nlist_order_raw : Array[String],
  cluster_keys : Map[String, String],
) -> Map[String, Array[String]] {
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  for name in nlist_order_raw {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    match cluster_nodes.get(cluster) {
      Some(list) => list.push(name)
      None => cluster_nodes[cluster] = [name]
    }
  }
  cluster_nodes
}


///|
/// Graphviz parity: cluster flip uses explicit reverse traversal to construct
/// per-cluster replacement lists in reverse local order.
/// Do not change behavior without updating fixtures/tests.
fn reverse_cluster_nodes_for_flip(list : Array[String]) -> Array[String] {
  let reversed : Array[String] = []
  let mut idx = list.length()
  while idx > 0 {
    idx = idx - 1
    reversed.push(list[idx])
  }
  reversed
}

///|
/// Graphviz parity: cluster flip precomputes reversed per-cluster node lists
/// and zeroed consumption indices before reconstructing adjusted nlist order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_reversed_nodes_and_index_for_flip(
  cluster_nodes : Map[String, Array[String]],
) -> (Map[String, Array[String]], Map[String, Int]) {
  let cluster_reversed : Map[String, Array[String]] = Map::new()
  let cluster_index : Map[String, Int] = Map::new()
  for cluster, list in cluster_nodes {
    cluster_reversed[cluster] = reverse_cluster_nodes_for_flip(list)
    cluster_index[cluster] = 0
  }
  (cluster_reversed, cluster_index)
}


///|
/// Graphviz parity: flipped nlist reconstruction consumes one reversed member
/// per cluster occurrence, falling back to original name on index overflow.
/// Do not change behavior without updating fixtures/tests.
fn consume_cluster_flip_name(
  cluster : String,
  name : String,
  cluster_reversed : Map[String, Array[String]],
  cluster_index : Map[String, Int],
) -> String {
  let idx = match cluster_index.get(cluster) {
    Some(value) => value
    None => 0
  }
  let list = match cluster_reversed.get(cluster) {
    Some(value) => value
    None => []
  }
  let resolved = if idx < list.length() { list[idx] } else { name }
  cluster_index[cluster] = idx + 1
  resolved
}

///|
/// Graphviz parity: flipped nlist reconstruction preserves non-cluster names
/// and replaces cluster names by sequential consumption from reversed buckets.
/// Do not change behavior without updating fixtures/tests.
fn build_adjusted_nlist_order_for_cluster_flip(
  nlist_order_raw : Array[String],
  cluster_keys : Map[String, String],
  cluster_reversed : Map[String, Array[String]],
  cluster_index : Map[String, Int],
) -> Array[String] {
  let adjusted : Array[String] = []
  for name in nlist_order_raw {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      adjusted.push(name)
    } else {
      adjusted.push(
        consume_cluster_flip_name(
          cluster,
          name,
          cluster_reversed,
          cluster_index,
        ),
      )
    }
  }
  adjusted
}

///|
/// Graphviz parity: when GD_flip is true, decompose nlist reverses node order
/// inside each cluster while preserving cluster membership positions.
/// Do not change behavior without updating fixtures/tests.
fn adjust_nlist_order_for_cluster_flip(
  nlist_order_raw : Array[String],
  graphviz_flip : Bool,
  has_clusters : Bool,
  cluster_keys : Map[String, String],
) -> Array[String] {
  if !(graphviz_flip && has_clusters) {
    return nlist_order_raw
  }
  let cluster_nodes = collect_cluster_nodes_for_flip(
    nlist_order_raw,
    cluster_keys,
  )
  let (cluster_reversed, cluster_index) =
    build_cluster_reversed_nodes_and_index_for_flip(cluster_nodes)
  build_adjusted_nlist_order_for_cluster_flip(
    nlist_order_raw,
    cluster_keys,
    cluster_reversed,
    cluster_index,
  )
}

///|
/// Graphviz parity: edge creation sequence concatenates skeleton links before
/// regular order-edge links to preserve AGSEQ head-neighbor replay.
/// Do not change behavior without updating fixtures/tests.
fn merge_edge_creation_sequences(
  leading : Array[(String, String)],
  trailing : Array[(String, String)],
) -> Array[(String, String)] {
  let merged : Array[(String, String)] = []
  for edge in leading {
    merged.push(edge)
  }
  for edge in trailing {
    merged.push(edge)
  }
  merged
}

///|
/// Graphviz parity: edge creation order feeds ND_in AGSEQ capture with cluster
/// skeleton links preceding regular order_edge_creation links.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_creation_order(
  skeleton_edge_creation : Array[(String, String)],
  order_edge_creation : Array[(String, String)],
) -> Array[(String, String)] {
  merge_edge_creation_sequences(
    skeleton_edge_creation,
    order_edge_creation,
  )
}

///|
/// Graphviz parity: class2 flat-rank preprocessing treats unknown node ranks
/// as 0 when evaluating same-rank non-self edge constraints.
/// Do not change behavior without updating fixtures/tests.
fn rank_or_zero_for_flat_constraints(
  ranks : Map[String, Int],
  name : String,
) -> Int {
  match ranks.get(name) {
    Some(value) => value
    None => 0
  }
}

///|
/// Graphviz parity: flat-constraint insertion only records non-self edges whose
/// endpoints resolve to the same rank under missing-rank fallback.
/// Do not change behavior without updating fixtures/tests.
fn append_flat_rank_constraint_if_same_rank(
  flat_rank_constraints : Map[String, Bool],
  tail : String,
  head : String,
  ranks : Map[String, Int],
) -> Unit {
  if tail == head {
    return
  }
  let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
  let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
  if tail_rank == head_rank {
    flat_rank_constraints["\{tail}|\{head}"] = true
  }
}

///|
/// Graphviz parity: flat edge constraints include same-rank non-self edges
/// and use missing-rank fallback 0 exactly as class2 input pre-pass.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_rank_constraints(
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let flat_rank_constraints : Map[String, Bool] = Map::new()
  let mut flat_idx = 0
  while flat_idx < edge_tail.length() {
    let tail = edge_tail[flat_idx]
    let head = edge_head[flat_idx]
    append_flat_rank_constraint_if_same_rank(
      flat_rank_constraints,
      tail,
      head,
      ranks,
    )
    flat_idx = flat_idx + 1
  }
  flat_rank_constraints
}

///|
/// Graphviz parity: class2 traverses agfstnode creation order.
/// Do not change behavior without updating fixtures/tests.
fn collect_creation_order(
  nodes : Array[@cgraph.Node],
) -> Array[String] {
  let creation_order : Array[String] = []
  for node in nodes {
    creation_order.push(node.name())
  }
  creation_order
}

///|
/// Graphviz parity: order-graph tail buckets copy ND_out edge insertion order
/// for each agfstnode name, with empty lists for nodes without out edges.
/// Do not change behavior without updating fixtures/tests.
fn build_edges_by_tail_from_out_order(
  nodes : Array[@cgraph.Node],
  edge_out_order : Map[String, Array[Int]],
) -> Map[String, Array[Int]] {
  let edges_by_tail : Map[String, Array[Int]] = Map::new()
  for node in nodes {
    let name = node.name()
    match edge_out_order.get(name) {
      Some(list) => edges_by_tail[name] = list.copy()
      None => edges_by_tail[name] = []
    }
  }
  edges_by_tail
}

///|
fn order_edge_merge_key(
  tail : String,
  head : String,
  constraint : Bool,
  tail_port_order : Double,
  head_port_order : Double,
) -> String {
  "\{tail}|\{head}|\{constraint}|\{tail_port_order.to_string()}|\{head_port_order.to_string()}"
}

///|
/// Graphviz parity: class2 merges adjacent mergeable chain segments by adding
/// xpenalty into the first representative segment and suppressing duplicates.
/// Do not change behavior without updating fixtures/tests.
fn coalesce_order_edges_for_tail(
  entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)],
) -> Array[(String, String, Int, Bool, Double, Double, Double, Double)] {
  let coalesced : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = []
  let mut prev_key = ""
  let mut prev_index = -1
  for entry in entries {
    let (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
      entry
    let key =
      order_edge_merge_key(
        tail,
        head,
        constraint,
        tail_port_order,
        head_port_order,
      )
    if penalty > 0 && prev_index >= 0 && key == prev_key {
      let (rep_tail, rep_head, rep_penalty, rep_constraint, rep_tail_port_x, rep_head_port_x, rep_tail_port_order, rep_head_port_order) =
        coalesced[prev_index]
      coalesced[prev_index] = (
        rep_tail,
        rep_head,
        rep_penalty + penalty,
        rep_constraint,
        rep_tail_port_x,
        rep_head_port_x,
        rep_tail_port_order,
        rep_head_port_order,
      )
      continue
    }
    coalesced.push(
      (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order),
    )
    prev_key = key
    prev_index = coalesced.length() - 1
  }
  coalesced
}

///|
/// Graphviz parity: class2 merge_chain compacts adjacent mergeable ND_out
/// segments per tail after chain materialization.
/// Do not change behavior without updating fixtures/tests.
fn coalesce_order_edges_by_tail(
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  let coalesced : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  for tail_name, entries in order_edges_by_tail {
    coalesced[tail_name] = coalesce_order_edges_for_tail(entries)
  }
  coalesced
}

///|
/// Graphviz parity: nested class2 passes on intercluster multi-edges preserve
/// extra xpenalty on vnode-tail segments in clustered ReMincross rematerialize.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_vnode_tail_bonus(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_keys : Map[String, String],
) -> Map[String, Int] {
  let count_by_key : Map[String, Int] = Map::new()
  for tail_name in creation_order {
    let indices = match edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for idx in indices {
      let edge = edges[idx]
      let tail =
        if idx < edge_tail.length() { edge_tail[idx] } else { edge.tail().name() }
      let head =
        if idx < edge_head.length() { edge_head[idx] } else { edge.head().name() }
      let tail_rank = match ranks.get(tail) {
        Some(value) => value
        None => 0
      }
      let head_rank = match ranks.get(head) {
        Some(value) => value
        None => 0
      }
      if tail_rank == head_rank {
        continue
      }
      let tail_cluster =
        if order_with_clusters {
          cluster_key_or_empty(cluster_keys, tail)
        } else {
          ""
        }
      let head_cluster =
        if order_with_clusters {
          cluster_key_or_empty(cluster_keys, head)
        } else {
          ""
        }
      let intercluster =
        order_with_clusters && tail_cluster != head_cluster &&
        (tail_cluster != "" || head_cluster != "")
      if !intercluster || !edge_is_constraint(edge) || edge_xpenalty(edge) <= 0 {
        continue
      }
      let tail_port_order =
        if idx < edge_tail_port_order.length() { edge_tail_port_order[idx] } else {
          0.5
        }
      let head_port_order =
        if idx < edge_head_port_order.length() { edge_head_port_order[idx] } else {
          0.5
        }
      let vnodes =
        if order_with_vnodes {
          match edge_vnodes.get(edge_vnode_key(edge)) {
            Some(list) => list
            None => []
          }
        } else {
          []
        }
      let chain : Array[String] = []
      let (chain_tail, chain_head) =
        if tail_rank <= head_rank { (tail, head) } else { (head, tail) }
      chain.push(chain_tail)
      if order_with_vnodes && vnodes.length() > 0 {
        for vnode in vnodes {
          chain.push(vnode)
        }
      }
      chain.push(chain_head)
      let mut i = 0
      while i + 1 < chain.length() {
        let t = chain[i]
        let h = chain[i + 1]
        if t != h && t.has_prefix(EDGE_VNODE_PREFIX) {
          let seg_tail_order =
            if t == tail && chain_tail == tail {
              tail_port_order
            } else if t == head && chain_head == head {
              head_port_order
            } else {
              0.0
            }
          let seg_head_order =
            if h == head && chain_head == head {
              head_port_order
            } else if h == tail && chain_tail == tail {
              tail_port_order
            } else {
              0.0
            }
          let key =
            order_edge_merge_key(
              t,
              h,
              true,
              seg_tail_order,
              seg_head_order,
            )
          let prev = match count_by_key.get(key) {
            Some(value) => value
            None => 0
          }
          count_by_key[key] = prev + 1
        }
        i = i + 1
      }
    }
  }
  let bonus_by_key : Map[String, Int] = Map::new()
  for key, count in count_by_key {
    if count > 1 {
      bonus_by_key[key] = count - 1
    }
  }
  bonus_by_key
}

///|
/// Graphviz parity: apply nested intercluster merge-chain bonus to the first
/// representative vnode-tail segment for each merge key.
/// Do not change behavior without updating fixtures/tests.
fn apply_intercluster_vnode_tail_bonus(
  order_edges_by_tail_coalesced : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  bonus_by_key : Map[String, Int],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  if bonus_by_key.length() == 0 {
    return order_edges_by_tail_coalesced
  }
  let remaining_bonus : Map[String, Int] = Map::new()
  for key, value in bonus_by_key {
    remaining_bonus[key] = value
  }
  let adjusted : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  for tail_name, entries in order_edges_by_tail_coalesced {
    let adjusted_entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = []
    for entry in entries {
      let (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        entry
      let key =
        order_edge_merge_key(
          tail,
          head,
          constraint,
          tail_port_order,
          head_port_order,
        )
      let mut adjusted_penalty = penalty
      match remaining_bonus.get(key) {
        Some(extra) =>
          if extra > 0 {
            adjusted_penalty = adjusted_penalty + extra
            remaining_bonus[key] = 0
          }
        None => ()
      }
      adjusted_entries.push(
        (tail, head, adjusted_penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order),
      )
    }
    adjusted[tail_name] = adjusted_entries
  }
  adjusted
}

///|
/// Graphviz parity: edge creation replay follows per-tail ND_out order after
/// class2 merge-chain coalescing in rematerialized clustered passes.
/// Do not change behavior without updating fixtures/tests.
fn rebuild_edge_creation_from_tail_order(
  tail_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Array[(String, String)] {
  let edge_creation : Array[(String, String)] = []
  for tail_name in tail_order {
    let entries = match order_edges_by_tail.get(tail_name) {
      Some(list) => list
      None => []
    }
    for entry in entries {
      let (tail, head, _, _, _, _, _, _) = entry
      edge_creation.push((tail, head))
    }
  }
  edge_creation
}

///|
/// Graphviz parity: cluster-local build_ranks consumes edge chains before
/// root/cluster remapping, so unmapped tails/heads must remain available.
/// Do not change behavior without updating fixtures/tests.
fn build_unmapped_order_edges_by_tail(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  edges_by_tail : Map[String, Array[Int]],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  if order_with_clusters {
    let (unmapped_edges_by_tail, _unmapped_vnode_creation, _unmapped_edge_creation) =
      build_order_edges_by_tail_graphviz(
        creation_order,
        edges,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_tail_port_order,
        edge_head_port_order,
        ranks,
        edge_vnodes,
        order_with_vnodes,
        cluster_keys,
        order_with_clusters,
        false,
        false,
        edges_by_tail,
      )
    unmapped_edges_by_tail
  } else {
    order_edges_by_tail
  }
}

///|
/// Graphviz parity: root order-edge chains use remapped cluster endpoints,
/// while non-cluster graphs reuse the base order_edges_by_tail mapping.
/// Do not change behavior without updating fixtures/tests.
fn build_root_order_edges_by_tail(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  edges_by_tail : Map[String, Array[Int]],
) -> (Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]], Array[(String, String)]) {
  if order_with_clusters {
    let (root_edges_by_tail, _root_vnode_creation_by_tail, root_edge_creation) =
      build_order_edges_by_tail_graphviz(
        creation_order,
        edges,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_tail_port_order,
        edge_head_port_order,
        ranks,
        edge_vnodes,
        order_with_vnodes,
        cluster_keys,
        order_with_clusters,
        true,
        true,
        edges_by_tail,
      )
    (root_edges_by_tail, root_edge_creation)
  } else {
    (order_edges_by_tail, order_edge_creation)
  }
}

///|
/// Graphviz parity: nlist index map follows current GD_nlist/decompose order
/// for vnode key fallback and class2 ordering ties.
/// Do not change behavior without updating fixtures/tests.
fn build_nlist_order_index(
  nlist_order : Array[String],
) -> Map[String, Int] {
  let nlist_order_index : Map[String, Int] = Map::new()
  let mut nlist_idx = 0
  for name in nlist_order {
    nlist_order_index[name] = nlist_idx
    nlist_idx = nlist_idx + 1
  }
  nlist_order_index
}

///|
/// Graphviz parity: order graph starts from measured node sizes and augments
/// with vnode virtual sizes when vnode ordering is enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_order_sizes_for_order_graph(
  order_sizes : Map[String, NodeSize],
  order_with_vnodes : Bool,
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  let order_sizes_out : Map[String, NodeSize] = Map::new()
  for name, size in order_sizes {
    order_sizes_out[name] = size
  }
  if order_with_vnodes {
    for name, size in vnode_sizes {
      order_sizes_out[name] = size
    }
  }
  order_sizes_out
}

///|
/// Graphviz parity: class2 build_ranks reverses current nlist when creating
/// node visit seed order for edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_reverse_creation_order_from_nlist(
  nlist_order : Array[String],
) -> Array[String] {
  let creation_order : Array[String] = []
  let mut creation_idx = nlist_order.length()
  while creation_idx > 0 {
    creation_idx = creation_idx - 1
    creation_order.push(nlist_order[creation_idx])
  }
  creation_order
}

///|
/// Graphviz parity: order graph cluster-key map starts from real-node keys and
/// appends vnode cluster keys only when vnode ordering is enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_order_cluster_keys_for_order_graph(
  cluster_keys : Map[String, String],
  order_with_vnodes : Bool,
  vnode_clusters : Map[String, String],
) -> Map[String, String] {
  let order_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_keys {
    order_cluster_keys[name] = key
  }
  if order_with_vnodes {
    for name, key in vnode_clusters {
      order_cluster_keys[name] = key
    }
  }
  order_cluster_keys
}

///|
/// Graphviz parity: class2 cluster skeleton nodes use virtual_node() defaults
/// and are appended into every covered rank in cluster order.
/// Do not change behavior without updating fixtures/tests.
fn append_order_cluster_skeleton_range(
  cluster : String,
  min_rank : Int,
  max_rank : Int,
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  order_groups : Map[Int, Array[String]],
  skeleton_size : NodeSize,
) -> Unit {
  for rank in min_rank..=max_rank {
    let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
    order_cluster_keys[name] = cluster
    order_cluster_skeleton[name] = true
    order_sizes_out[name] = skeleton_size
    match order_groups.get(rank) {
      Some(list) => list.push(name)
      None => order_groups[rank] = [name]
    }
  }
}

///|
/// Graphviz parity: order-graph node creation follows collected rank key order
/// and per-rank node sequence (including appended virtual skeleton/vnodes).
/// Do not change behavior without updating fixtures/tests.
fn build_order_nodes_from_groups(
  order_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
) -> Array[String] {
  let order_nodes : Array[String] = []
  for rank in order_rank_keys {
    let names = match order_groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      order_nodes.push(name)
    }
  }
  order_nodes
}

///|
/// Graphviz parity: order graph node table is built by creating each name in
/// order_nodes sequence, matching agnode creation iteration order.
/// Do not change behavior without updating fixtures/tests.
fn build_order_graph_and_nodes(
  graph_name : String,
  order_nodes : Array[String],
) -> (@cgraph.Graph, Map[String, @cgraph.Node]) {
  let order_graph =
    @cgraph.Graph::new(
      @cgraph.GraphKind::Directed,
      name=graph_name,
      strict=false,
    )
  let order_node_map : Map[String, @cgraph.Node] = Map::new()
  for name in order_nodes {
    order_node_map[name] = order_graph.node(name)
  }
  (order_graph, order_node_map)
}

///|
/// Graphviz parity: order edges are materialized in nlist tail iteration order
/// with per-tail edge lists consumed exactly in stored sequence.
/// Do not change behavior without updating fixtures/tests.
fn append_order_edges_for_tail_sequence(
  tail_sequence : Array[String],
  edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> Unit {
  for tail_name in tail_sequence {
    let list = match edges_by_tail.get(tail_name) {
      Some(value) => value
      None => []
    }
    for entry in list {
      let (edge_tail_name, edge_head_name, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        entry
      add_order_edge(
        order_graph,
        order_node_map,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_edge_tail_port_x,
        order_edge_head_port_x,
        order_edge_tail_port_order,
        order_edge_head_port_order,
        edge_tail_name,
        edge_head_name,
        penalty,
        constraint,
        tail_port_x,
        head_port_x,
        tail_port_order,
        head_port_order,
      )
    }
  }
}

///|
/// Graphviz parity: edge arrays are materialized from per-tail lists in exact
/// nlist tail iteration order (shared root/remincross order-graph builder).
/// Do not change behavior without updating fixtures/tests.
fn collect_order_edges_for_tail_sequence(
  tail_sequence : Array[String],
  edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  append_order_edges_for_tail_sequence(
    tail_sequence,
    edges_by_tail,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
  (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}

///|
/// Graphviz parity: parent/child adjacency maps and edge-order indices are
/// derived from the exact materialized edge arrays in current order graph.
/// Do not change behavior without updating fixtures/tests.
fn build_order_edge_indices_and_order(
  order_nodes : Array[String],
  edge_tail_out : Array[String],
  edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  edges_out : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  let (parents, children) =
    build_edge_index_for_order_names(
      order_nodes,
      edge_tail_out,
      edge_head_out,
      order_ranks,
    )
  let edge_order = collect_edge_order(edges_out)
  (parents, children, edge_order)
}

///|
/// Graphviz parity: build_ranks node-order seed prioritizes GD_nlist then
/// fills with nlist/order_groups/base order while applying rank=same overrides.
/// Do not change behavior without updating fixtures/tests.
fn build_order_node_order_for_build_ranks(
  gdnlist_order : Array[String],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  order_groups : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let order_node_order : Map[String, Int] = Map::new()
  let mut order_idx = 0
  for name in gdnlist_order {
    order_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  for name in nlist_order {
    if order_node_order.get(name) is None {
      order_node_order[name] = order_idx
      order_idx = order_idx + 1
    }
  }
  // Graphviz parity: fall back to GD_nlist order for real nodes missing from nlist.
  for name, idx in node_order {
    if real_nodes.get(name) is Some(_) && order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_index = build_order_index(order_groups)
  for name, idx in order_index {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: seed missing real-node order from initial rank order;
  // GD_nlist order remains the primary source.
  for name, idx in base_order_index {
    if real_nodes.get(name) is Some(_) && order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  apply_rank_same_order_to_node_order(
    order_node_order,
    rank_same_groups,
    rank_same_order,
    port_edge_nodes,
  )
  order_node_order
}

///|
/// Graphviz parity: unconstrained-node seeding uses GD_nlist indices for real
/// nodes only, matching class2 fallback behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_gdnlist_order_index_for_real_nodes(
  gdnlist_order : Array[String],
  real_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let gdnlist_order_index : Map[String, Int] = Map::new()
  let mut gdnlist_idx = 0
  for name in gdnlist_order {
    if real_nodes.get(name) is Some(_) {
      gdnlist_order_index[name] = gdnlist_idx
      gdnlist_idx = gdnlist_idx + 1
    }
  }
  gdnlist_order_index
}

///|
/// Graphviz parity: unconstrained nodes are exactly nodes with zero ND_out and
/// zero ND_in neighbors in the order graph.
/// Do not change behavior without updating fixtures/tests.
fn collect_unconstrained_order_nodes(
  order_nodes : Array[String],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
) -> Map[String, Bool] {
  let unconstrained_nodes : Map[String, Bool] = Map::new()
  for name in order_nodes {
    let out = match graphviz_out_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let inn = match graphviz_in_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    if out.length() == 0 && inn.length() == 0 {
      unconstrained_nodes[name] = true
    }
  }
  unconstrained_nodes
}

///|
/// Graphviz parity: incoming-only unconstrained handling uses non-self edges
/// to mark ND_out/ND_in presence, matching class2 neighbor detection.
/// Do not change behavior without updating fixtures/tests.
fn build_node_in_out_presence_maps(
  edge_tail : Array[String],
  edge_head : Array[String],
) -> (Map[String, Bool], Map[String, Bool]) {
  let node_has_out : Map[String, Bool] = Map::new()
  let node_has_in : Map[String, Bool] = Map::new()
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      node_has_out[tail] = true
      node_has_in[head] = true
    }
    edge_idx = edge_idx + 1
  }
  (node_has_out, node_has_in)
}

///|
/// Graphviz parity: local cluster node creation order follows node scan order
/// per intercluster key, matching class2 fast-node insertion inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_local_cluster_creation_order(
  nodes : Array[@cgraph.Node],
  intercluster_keys : Map[String, String],
) -> Map[String, Array[String]] {
  let local_creation : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let local_cluster = match intercluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    if local_cluster == "" {
      continue
    }
    match local_creation.get(local_cluster) {
      Some(list) => list.push(name)
      None => local_creation[local_cluster] = [name]
    }
  }
  local_creation
}

///|
/// Graphviz parity: incoming-only unconstrained local nodes are reassigned in
/// reverse creation order while preserving their sorted order slots.
/// Do not change behavior without updating fixtures/tests.
fn reorder_incoming_only_unconstrained_local_nodes(
  local_creation : Map[String, Array[String]],
  unconstrained_nodes : Map[String, Bool],
  rank_same_groups : Map[String, Int],
  node_has_out : Map[String, Bool],
  node_has_in : Map[String, Bool],
  order_node_order : Map[String, Int],
) -> Unit {
  for _cluster, names in local_creation {
    let unconstrained_local : Array[String] = []
    for name in names {
      if unconstrained_nodes.get(name) is Some(_) &&
        rank_same_groups.get(name) is None &&
        node_has_out.get(name) is None &&
        node_has_in.get(name) is Some(_) {
        unconstrained_local.push(name)
      }
    }
    if unconstrained_local.length() <= 1 {
      continue
    }
    let desired : Array[String] = []
    let mut rev_idx = unconstrained_local.length()
    while rev_idx > 0 {
      rev_idx = rev_idx - 1
      desired.push(unconstrained_local[rev_idx])
    }
    let orders : Array[Int] = []
    let mut all_present = true
    for name in unconstrained_local {
      match order_node_order.get(name) {
        Some(value) => orders.push(value)
        None => {
          all_present = false
          break
        }
      }
    }
    if !all_present || orders.length() != desired.length() {
      continue
    }
    orders.sort()
    let mut idx = 0
    while idx < desired.length() && idx < orders.length() {
      order_node_order[desired[idx]] = orders[idx]
      idx = idx + 1
    }
  }
}

///|
/// Graphviz parity: transpose seed maps include all seeded nodes and only
/// positive-penalty constrained edges that cross ranks.
/// Do not change behavior without updating fixtures/tests.
fn build_transpose_seed_edge_maps(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
) -> (Array[Int], Map[String, Array[Int]], Map[String, Array[Int]]) {
  let edge_penalty : Array[Int] = []
  let edge_in : Map[String, Array[Int]] = Map::new()
  let edge_out : Map[String, Array[Int]] = Map::new()
  for rank in order_rank_keys {
    let names = match seeded_groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      edge_in[name] = []
      edge_out[name] = []
    }
  }
  for edge_idx in 0..<order_edges_out.length() {
    let edge = order_edges_out[edge_idx]
    let penalty = edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !edge_is_constraint(edge) {
      continue
    }
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    let tail_rank = match order_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match order_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
    match edge_in.get(head) {
      Some(list) => list.push(edge_idx)
      None => edge_in[head] = [edge_idx]
    }
  }
  (edge_penalty, edge_in, edge_out)
}

///|
/// Graphviz parity: root ReMincross keeps only root and cluster-skeleton nodes;
/// cluster-internal ordering stays in cluster-local build_ranks passes.
/// Do not change behavior without updating fixtures/tests.
fn build_order_groups_for_root_mincross(
  order_with_clusters : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  if !order_with_clusters {
    return seeded_groups
  }
  let filtered : Map[Int, Array[String]] = Map::new()
  for rank, names in seeded_groups {
    let list : Array[String] = []
    for name in names {
      let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
      let cluster = match order_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if is_skeleton || cluster == "" {
        list.push(name)
      }
    }
    if list.length() > 0 {
      filtered[rank] = list
    }
  }
  filtered
}

///|
/// Graphviz parity: membership checks for mincross subgraph are exact-name set
/// lookups over the filtered node list.
/// Do not change behavior without updating fixtures/tests.
fn build_node_membership_set(names : Array[String]) -> Map[String, Bool] {
  let membership : Map[String, Bool] = Map::new()
  for name in names {
    membership[name] = true
  }
  membership
}

///|
/// Graphviz parity: mincross port metadata on synthetic ordering nodes uses
/// default zero offsets/order unless an explicit non-default port survives
/// into the materialized order edge.
/// Do not change behavior without updating fixtures/tests.
fn should_zero_synthetic_mincross_ports(
  tail : String,
  head : String,
  tail_port_x : Double,
  head_port_x : Double,
  tail_port_order : Double,
  head_port_order : Double,
) -> Bool {
  let tail_is_skeleton = tail.has_prefix(CLUSTER_SKELETON_PREFIX)
  let head_is_skeleton = head.has_prefix(CLUSTER_SKELETON_PREFIX)
  let synthetic_endpoint =
    is_edge_vnode_name(tail) || is_edge_vnode_name(head) ||
    tail_is_skeleton || head_is_skeleton
  if !synthetic_endpoint {
    return false
  }
  let defaultish_x =
    (tail_port_x == 0.0 || tail_port_x == 0.5) &&
    (head_port_x == 0.0 || head_port_x == 0.5)
  if tail_is_skeleton && head_is_skeleton {
    return true
  }
  defaultish_x && tail_port_order == 0.0 && head_port_order == 0.0
}

///|
/// Graphviz parity: root mincross edge set keeps only edges whose endpoints are
/// both in the filtered node set, preserving edge and port-order sequence.
/// Do not change behavior without updating fixtures/tests.
fn collect_mincross_order_edges(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let order_edges_out_mincross : Array[@cgraph.Edge] = []
  let order_edge_tail_out_mincross : Array[String] = []
  let order_edge_head_out_mincross : Array[String] = []
  let order_edge_tail_port_x_mincross : Array[Double] = []
  let order_edge_head_port_x_mincross : Array[Double] = []
  let order_edge_tail_port_order_mincross : Array[Double] = []
  let order_edge_head_port_order_mincross : Array[Double] = []
  let mut edge_idx = 0
  while edge_idx < order_edges_out.length() {
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    if mincross_nodes.get(tail) is Some(_) && mincross_nodes.get(head) is Some(_) {
      let tail_port_x_raw = order_edge_tail_port_x[edge_idx]
      let head_port_x_raw = order_edge_head_port_x[edge_idx]
      let tail_port_order_raw = order_edge_tail_port_order[edge_idx]
      let head_port_order_raw = order_edge_head_port_order[edge_idx]
      let zero_synthetic_defaults =
        should_zero_synthetic_mincross_ports(
          tail,
          head,
          tail_port_x_raw,
          head_port_x_raw,
          tail_port_order_raw,
          head_port_order_raw,
        )
      let tail_port_x =
        if zero_synthetic_defaults { 0.0 } else { tail_port_x_raw }
      let head_port_x =
        if zero_synthetic_defaults { 0.0 } else { head_port_x_raw }
      let tail_port_order =
        if zero_synthetic_defaults {
          0.0
        } else {
          tail_port_order_raw
        }
      let head_port_order =
        if zero_synthetic_defaults {
          0.0
        } else {
          head_port_order_raw
        }
      order_edges_out_mincross.push(order_edges_out[edge_idx])
      order_edge_tail_out_mincross.push(tail)
      order_edge_head_out_mincross.push(head)
      order_edge_tail_port_x_mincross.push(tail_port_x)
      order_edge_head_port_x_mincross.push(head_port_x)
      order_edge_tail_port_order_mincross.push(tail_port_order)
      order_edge_head_port_order_mincross.push(head_port_order)
    }
    edge_idx = edge_idx + 1
  }
  (
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
  )
}

///|
/// Graphviz parity: after root-only mincross, reordered root/skeleton nodes are
/// merged back into seeded rank lists by replacing only filtered positions.
/// Do not change behavior without updating fixtures/tests.
fn merge_root_mincross_order_into_seeded_groups(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
  _order_cluster_keys : Map[String, String],
  _order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = match seeded_groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    let replacements = match ordered_mincross.get(rank) {
      Some(list) => list
      None => []
    }
    if replacements.length() == 0 {
      merged[rank] = names
      continue
    }
    // Graphviz parity: keep cluster-internal nodes attached to the rankleader
    // skeleton position when root mincross reorders cluster skeleton chains.
    let skeleton_for_cluster : Map[String, String] = Map::new()
    for name in names {
      if _order_cluster_skeleton.get(name) == Some(true) {
        let cluster = match _order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster != "" {
          skeleton_for_cluster[cluster] = name
        }
      }
    }
    let attached_by_skeleton : Map[String, Array[String]] = Map::new()
    for name in names {
      if mincross_nodes.get(name) is Some(_) {
        continue
      }
      let cluster = match _order_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      match skeleton_for_cluster.get(cluster) {
        Some(skeleton_name) =>
          match attached_by_skeleton.get(skeleton_name) {
            Some(list) => list.push(name)
            None => attached_by_skeleton[skeleton_name] = [name]
          }
        None => ()
      }
    }
    let next_names : Array[String] = []
    let seen : Map[String, Bool] = Map::new()
    for replacement in replacements {
      next_names.push(replacement)
      seen[replacement] = true
      if _order_cluster_skeleton.get(replacement) == Some(true) {
        let attached = match attached_by_skeleton.get(replacement) {
          Some(list) => list
          None => []
        }
        for attached_name in attached {
          if seen.get(attached_name) is None {
            next_names.push(attached_name)
            seen[attached_name] = true
          }
        }
      }
    }
    for name in names {
      if seen.get(name) is None {
        next_names.push(name)
        seen[name] = true
      }
    }
    merged[rank] = next_names
  }
  merged
}

///|
/// Graphviz parity: root-vnode set for cluster root reorder includes vnodes on
/// edges crossing cluster boundaries (same edge_vnode_key mapping as routing).
/// Do not change behavior without updating fixtures/tests.
fn collect_root_vnodes_for_cluster_reorder(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Bool] {
  let root_vnodes : Map[String, Bool] = Map::new()
  if !order_with_vnodes {
    return root_vnodes
  }
  let mut edge_idx = 0
  for edge in edges {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if tail_cluster != head_cluster {
      let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      for vnode in vnodes {
        root_vnodes[vnode] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  root_vnodes
}

///|
/// Graphviz parity: root cluster reorder base groups keep only root/skeleton
/// nodes, and include edge-vnodes only when flagged as root-vnodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_groups_base_for_cluster_reorder(
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  root_vnodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let root_groups_base : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys {
    let names = match order_groups_for_mincross.get(rank) {
      Some(list) => list
      None => []
    }
    let root_names : Array[String] = []
    for name in names {
      let cluster = match order_cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      let is_skeleton = order_cluster_skeleton.get(name) == Some(true)
      if is_skeleton || cluster == "" {
        if !name.has_prefix(EDGE_VNODE_PREFIX) || root_vnodes.get(name) == Some(true) {
          root_names.push(name)
        }
      }
    }
    if root_names.length() > 0 {
      root_groups_base[rank] = root_names
    }
  }
  root_groups_base
}

///|
/// Graphviz parity: root cluster reorder seeds tail order from current nlist,
/// replacing cluster members with rank-qualified skeleton names and deduping.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_seed_order_for_cluster_reorder(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Array[String] {
  let tail_order_root : Array[String] = []
  let tail_root_seen : Map[String, Bool] = Map::new()
  for name in nlist_order {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster != "" {
      let rank = rank_or_zero_for_flat_constraints(ranks, name)
      let skel = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      append_order_creation_name_if_absent(
        tail_order_root,
        tail_root_seen,
        skel,
      )
    } else {
      append_order_creation_name_if_absent(
        tail_order_root,
        tail_root_seen,
        name,
      )
    }
  }
  tail_order_root
}

///|
/// Graphviz parity: root tail visit order places source tails (no incoming
/// edges) first while preserving original deduped tail sequence order.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_order_sources_first(
  tail_order_root : Array[String],
  root_has_in : Map[String, Bool],
) -> Array[String] {
  let root_tail_order : Array[String] = []
  let root_tail_seen : Map[String, Bool] = Map::new()
  for name in tail_order_root {
    if root_has_in.get(name) == Some(false) {
      append_order_creation_name_if_absent(
        root_tail_order,
        root_tail_seen,
        name,
      )
    }
  }
  for name in tail_order_root {
    append_order_creation_name_if_absent(
      root_tail_order,
      root_tail_seen,
      name,
    )
  }
  root_tail_order
}

///|
/// Graphviz parity: root source-first ordering marks incoming heads among
/// root nodes from merged edge-creation order before tail-order filtering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_has_in_map_for_cluster_reorder(
  root_nodes : Array[String],
  root_edge_creation_order : Array[(String, String)],
) -> Map[String, Bool] {
  let root_has_in : Map[String, Bool] = Map::new()
  for name in root_nodes {
    root_has_in[name] = false
  }
  for edge in root_edge_creation_order {
    let (_tail, head) = edge
    if root_has_in.get(head) is Some(_) {
      root_has_in[head] = true
    }
  }
  root_has_in
}

///|
/// Graphviz parity: root GD_nlist output keeps only materialized root nodes,
/// then appends any missing root names in root_nodes order.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_nlist_order_for_cluster_reorder(
  root_nlist_full : Array[String],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
) -> Array[String] {
  let root_nlist_order : Array[String] = []
  let root_seen : Map[String, Bool] = Map::new()
  for name in root_nlist_full {
    if root_node_map.get(name) is Some(_) {
      root_seen[name] = true
      root_nlist_order.push(name)
    }
  }
  if root_nlist_order.length() < root_nodes.length() {
    for name in root_nodes {
      if root_seen.get(name) is None {
        root_nlist_order.push(name)
      }
    }
  }
  root_nlist_order
}


///|
/// Graphviz parity: root cluster reorder GD_nlist keeps skeleton/root tail
/// sequence from input order, prioritizes source tails, then rebuilds nlist via
/// edge creation order while appending any missing root nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_root_nlist_order_for_cluster_reorder(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
) -> Array[String] {
  let tail_order_root =
    build_root_tail_seed_order_for_cluster_reorder(
      nlist_order,
      cluster_keys,
      ranks,
    )
  let root_edge_creation_order =
    merge_edge_creation_sequences(
      skeleton_edge_creation,
      root_edge_creation,
    )
  let root_has_in =
    build_root_has_in_map_for_cluster_reorder(
      root_nodes,
      root_edge_creation_order,
    )
  let root_tail_order =
    build_root_tail_order_sources_first(tail_order_root, root_has_in)
  let root_nlist_full =
    build_graphviz_nlist_order_from_edges(
      root_tail_order,
      root_nodes,
      root_edge_creation_order,
      flat_rank_constraints,
    )
  finalize_root_nlist_order_for_cluster_reorder(
    root_nlist_full,
    root_nodes,
    root_node_map,
  )
}

///|
/// Graphviz parity: root mincross vnode inputs keep only root-vnodes from
/// vnode rank buckets and vnode order keys.
/// Do not change behavior without updating fixtures/tests.
fn collect_root_vnode_rank_groups_and_order_keys(
  order_with_vnodes : Bool,
  root_vnodes : Map[String, Bool],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (Map[Int, Array[String]], Map[String, Double]) {
  let root_vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  let root_vnode_order_keys : Map[String, Double] = Map::new()
  if order_with_vnodes {
    for rank, names in vnodes_by_rank {
      let filtered : Array[String] = []
      for name in names {
        if root_vnodes.get(name) == Some(true) {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        root_vnodes_by_rank[rank] = filtered
      }
    }
    for name, key in vnode_order_keys_for_ordering {
      if root_vnodes.get(name) == Some(true) {
        root_vnode_order_keys[name] = key
      }
    }
  }
  (root_vnodes_by_rank, root_vnode_order_keys)
}

///|
/// Graphviz parity: root cluster reorder groups keep root/skeleton base order
/// and optionally merge only root-vnodes into rank groups using filtered vnode
/// keys/rank buckets from root-mincross inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_groups_for_cluster_reorder(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> Map[Int, Array[String]] {
  let root_vnodes =
    collect_root_vnodes_for_cluster_reorder(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
    )
  let root_groups_base =
    build_root_groups_base_for_cluster_reorder(
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      root_vnodes,
    )
  let root_order_index = build_order_index(root_groups_base)
  let (root_vnodes_by_rank, root_vnode_order_keys) =
    collect_root_vnode_rank_groups_and_order_keys(
      order_with_vnodes,
      root_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      root_groups_base,
      root_order_index,
      root_vnodes_by_rank,
      root_vnode_order_keys,
    )
  } else {
    root_groups_base
  }
}

///|
/// Graphviz parity: cluster-rank sort keys are normalized into deterministic
/// order for root-bucket anchor transfer across adjacent ranks.
/// Do not change behavior without updating fixtures/tests.
fn collect_sorted_cluster_keys_for_cluster_rank_order(
  order_map : Map[String, Int],
) -> Array[String] {
  let entries : Array[(Int, String)] = []
  for cluster, order in order_map {
    if cluster == "" {
      continue
    }
    entries.push((order, cluster))
  }
  if entries.length() > 1 {
    entries.sort_by((a, b) => {
      let (a_order, a_cluster) = a
      let (b_order, b_cluster) = b
      if a_order < b_order {
        -1
      } else if a_order > b_order {
        1
      } else if a_cluster < b_cluster {
        -1
      } else if a_cluster > b_cluster {
        1
      } else {
        0
      }
    })
  }
  let sorted : Array[String] = []
  for entry in entries {
    let (_order, cluster) = entry
    sorted.push(cluster)
  }
  sorted
}

///|
/// Graphviz parity: root real-node bucket keeps relative left/right anchor
/// continuity across adjacent ranks when both ranks expose root buckets.
/// Do not change behavior without updating fixtures/tests.
fn anchor_root_bucket_from_previous_cluster_rank_order(
  order_map : Map[String, Int],
  previous_order_map : Map[String, Int]?,
) -> Unit {
  if order_map.get("") is None {
    return ()
  }
  let prev_map = match previous_order_map {
    Some(value) => value
    None => return ()
  }
  let prev_root = match prev_map.get("") {
    Some(value) => value
    None => return ()
  }
  let mut prev_cluster_count = 0
  let mut left_anchor : String? = None
  let mut left_order = 0
  let mut has_left = false
  let mut has_right = false
  for cluster, order in prev_map {
    if cluster == "" {
      continue
    }
    prev_cluster_count = prev_cluster_count + 1
    if order_map.get(cluster) is None {
      continue
    }
    if order < prev_root {
      if !has_left || order > left_order {
        left_anchor = Some(cluster)
        left_order = order
        has_left = true
      }
    } else if order > prev_root {
      has_right = true
    }
  }
  // Guardrail: only apply this on the simple single-left-anchor shape
  // seen in cluster hand-off ranks (e.g. clust5 rank transition).
  if prev_cluster_count != 1 || !has_left || has_right {
    return ()
  }
  let sorted_clusters = collect_sorted_cluster_keys_for_cluster_rank_order(order_map)
  if sorted_clusters.length() == 0 {
    return ()
  }
  let left = match left_anchor {
    Some(value) => value
    None => return ()
  }
  let mut insert_idx = sorted_clusters.length()
  for i in 0..<sorted_clusters.length() {
    if sorted_clusters[i] == left {
      insert_idx = i + 1
      break
    }
  }
  if insert_idx > sorted_clusters.length() {
    return ()
  }
  let reordered : Array[String] = []
  for i in 0..<sorted_clusters.length() {
    if i == insert_idx {
      reordered.push("")
    }
    reordered.push(sorted_clusters[i])
  }
  if insert_idx >= sorted_clusters.length() {
    reordered.push("")
  }
  let mut idx = 0
  for cluster in reordered {
    order_map[cluster] = idx
    idx = idx + 1
  }
}

///|
/// Graphviz parity: root mincross rank map records first-seen cluster skeleton
/// (or root real-node bucket) order per rank for cluster-phase reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_from_root_ordered(
  root_rank_keys : Array[Int],
  ordered_root : Map[Int, Array[String]],
  order_cluster_skeleton : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let mut previous_order_map : Map[String, Int]? = None
  for rank in root_rank_keys {
    let names = match ordered_root.get(rank) {
      Some(list) => list
      None => []
    }
    let order_map : Map[String, Int] = Map::new()
    let mut idx = 0
    for name in names {
      if order_cluster_skeleton.get(name) == Some(true) {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster != "" && order_map.get(cluster) is None {
          order_map[cluster] = idx
          idx = idx + 1
        }
      } else if real_nodes.get(name) is Some(_) {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        if cluster == "" && order_map.get("") is None {
          order_map[""] = idx
          idx = idx + 1
        }
      }
    }
    anchor_root_bucket_from_previous_cluster_rank_order(
      order_map,
      previous_order_map,
    )
    if order_map.length() > 0 {
      cluster_rank_order[rank] = order_map
      previous_order_map = Some(order_map)
    }
  }
  cluster_rank_order
}

///|
/// Graphviz parity: debug root-edge trace for cluster reorder mirrors the
/// root mincross materialization sequence and penalties.
/// Do not change behavior without updating fixtures/tests.
fn trace_root_edges_for_cluster_reorder(
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let mut edge_idx = 0
    while edge_idx < root_edges_out.length() {
      let tail = root_edge_tail_out[edge_idx]
      let head = root_edge_head_out[edge_idx]
      let pen = edge_xpenalty(root_edges_out[edge_idx])
      println("root_edge \{edge_idx}: \{tail} -> \{head} pen=\{pen}")
      edge_idx = edge_idx + 1
    }
  }
}

///|
/// Graphviz parity: root reorder edge bundle keeps tail-sequence edge
/// materialization, optional trace output, and index maps in one stage.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_edge_bundle(
  root_nlist_order : Array[String],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_graph : @cgraph.Graph,
  root_node_map : Map[String, @cgraph.Node],
  root_nodes : Array[String],
  root_ranks : Map[String, Int],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
) {
  let (
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
  ) =
    collect_order_edges_for_tail_sequence(
      root_nlist_order,
      order_edges_by_tail_root,
      root_graph,
      root_node_map,
    )
  let root_edge_tail_port_x_norm : Array[Double] = []
  let root_edge_head_port_x_norm : Array[Double] = []
  let root_edge_tail_port_order_norm : Array[Double] = []
  let root_edge_head_port_order_norm : Array[Double] = []
  let mut root_port_idx = 0
  while root_port_idx < root_edges_out.length() {
    let tail = root_edge_tail_out[root_port_idx]
    let head = root_edge_head_out[root_port_idx]
    let tail_port_x_raw = root_edge_tail_port_x[root_port_idx]
    let head_port_x_raw = root_edge_head_port_x[root_port_idx]
    let tail_port_order_raw = root_edge_tail_port_order[root_port_idx]
    let head_port_order_raw = root_edge_head_port_order[root_port_idx]
    let zero_ports =
      should_zero_synthetic_mincross_ports(
        tail,
        head,
        tail_port_x_raw,
        head_port_x_raw,
        tail_port_order_raw,
        head_port_order_raw,
      )
    root_edge_tail_port_x_norm.push(
      if zero_ports { 0.0 } else { tail_port_x_raw },
    )
    root_edge_head_port_x_norm.push(
      if zero_ports { 0.0 } else { head_port_x_raw },
    )
    root_edge_tail_port_order_norm.push(
      if zero_ports { 0.0 } else { tail_port_order_raw },
    )
    root_edge_head_port_order_norm.push(
      if zero_ports { 0.0 } else { head_port_order_raw },
    )
    root_port_idx = root_port_idx + 1
  }
  trace_root_edges_for_cluster_reorder(
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
  )
  let (root_parents, root_children, root_edge_order) =
    build_order_edge_indices_and_order(
      root_nodes,
      root_edge_tail_out,
      root_edge_head_out,
      root_ranks,
      root_edges_out,
    )
  (
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x_norm,
    root_edge_head_port_x_norm,
    root_edge_tail_port_order_norm,
    root_edge_head_port_order_norm,
    root_parents,
    root_children,
    root_edge_order,
  )
}

///|
/// Graphviz parity: root-only reorder pass uses the same reorder_rank_groups
/// path and tracing as cluster-phase root bucket ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_cluster_reorder_for_cluster_rank_order(
  root_rank_keys : Array[Int],
  root_groups : Map[Int, Array[String]],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let ordered_root = reorder_rank_groups(
    root_rank_keys,
    root_groups,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    root_edge_order,
    root_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    order_cluster_skeleton,
    flat_constraints,
    graphviz_flip=graphviz_flip,
  )
  dot_trace_groups("order_root", ordered_root)
  ordered_root
}

///|
/// Graphviz parity: root cluster-reorder derives rank keys/ranks, ordered
/// root nodes, and order_root graph directly from root-group membership.
/// Do not change behavior without updating fixtures/tests.
fn build_root_rank_graph_bundle_for_cluster_reorder(
  root_groups : Map[Int, Array[String]],
) -> (
  Array[Int],
  Map[String, Int],
  Array[String],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
) {
  let root_rank_keys = collect_rank_keys(root_groups)
  let root_ranks = build_node_ranks(root_groups)
  let root_nodes = build_order_nodes_from_groups(root_groups, root_rank_keys)
  let (root_graph, root_node_map) =
    build_order_graph_and_nodes("order_root", root_nodes)
  (root_rank_keys, root_ranks, root_nodes, root_graph, root_node_map)
}

///|
/// Graphviz parity: root cluster-reorder derives root GD_nlist walk order and
/// root-node order map from the same root graph/group membership snapshot.
/// Do not change behavior without updating fixtures/tests.
fn build_root_nlist_and_node_order_for_cluster_reorder(
  nlist_order : Array[String],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  root_nodes : Array[String],
  root_node_map : Map[String, @cgraph.Node],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  root_groups : Map[Int, Array[String]],
) -> (Array[String], Map[String, Int]) {
  let root_nlist_order =
    build_root_nlist_order_for_cluster_reorder(
      nlist_order,
      cluster_keys,
      ranks,
      root_nodes,
      root_node_map,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
    )
  let root_node_order =
    build_order_node_order_from_nlist_and_groups(
      root_nlist_order,
      root_node_map,
      root_groups,
    )
  (root_nlist_order, root_node_order)
}

///|
/// Graphviz parity: root cluster-reorder context is assembled from root
/// groups, root graph, and root nlist ordering before edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_context(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
) -> (
  Map[Int, Array[String]],
  Array[Int],
  Map[String, Int],
  Array[String],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
  Array[String],
  Map[String, Int],
) {
  let root_groups =
    build_root_groups_for_cluster_reorder(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
    )
  let (root_rank_keys, root_ranks, root_nodes, root_graph, root_node_map) =
    build_root_rank_graph_bundle_for_cluster_reorder(root_groups)
  let (root_nlist_order, root_node_order) =
    build_root_nlist_and_node_order_for_cluster_reorder(
      nlist_order,
      cluster_keys,
      ranks,
      root_nodes,
      root_node_map,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
      root_groups,
    )
  (
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
  )
}

///|
/// Graphviz parity: root-order rank map is transferred into the cluster
/// rank-order output map before final clustered reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn append_root_cluster_rank_order_for_cluster_reorder(
  cluster_rank_order : Map[Int, Map[String, Int]],
  root_rank_keys : Array[Int],
  ordered_root : Map[Int, Array[String]],
  order_cluster_skeleton : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  real_nodes : Map[String, Bool],
) -> Unit {
  let root_cluster_rank_order =
    build_cluster_rank_order_from_root_ordered(
      root_rank_keys,
      ordered_root,
      order_cluster_skeleton,
      order_cluster_keys,
      real_nodes,
    )
  for rank, order_map in root_cluster_rank_order {
    cluster_rank_order[rank] = order_map
  }
}

///|
/// Graphviz parity: root cluster-rank-order output context keeps rank-same,
/// order-size, and cluster-filter payload ordering for root reorder dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterRankOrderFromRootReorderContext {
  order_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_cluster_skeleton : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
  real_nodes : Map[String, Bool]
}

///|
/// Graphviz parity: root cluster-rank-order phase output keeps root-rank keys
/// and ordered-root groups tuple ordering unchanged before rank transfer.
/// Do not change behavior without updating fixtures/tests.
type RootClusterRankOrderPhaseOutput = (
  Array[Int],
  Map[Int, Array[String]],
)

///|
/// Graphviz parity: root cluster-rank-order phase consumes root reorder tuple
/// and dispatch context without reordering Graphviz call arguments.
/// Do not change behavior without updating fixtures/tests.
fn run_root_cluster_rank_order_phase_from_root_reorder_output(
  dispatch_context : ClusterRankOrderFromRootReorderContext,
  root_reorder_output : RootClusterReorderInputsForRankOrderOutput,
) -> RootClusterRankOrderPhaseOutput {
  let (
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
  ) = root_reorder_output
  let ordered_root = run_root_cluster_reorder_for_cluster_rank_order(
    root_rank_keys,
    root_groups,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    dispatch_context.order_cluster_keys,
    dispatch_context.rank_same_groups,
    dispatch_context.rank_same_order,
    root_edge_order,
    root_node_order,
    dispatch_context.order_sizes_out,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    dispatch_context.order_cluster_skeleton,
    dispatch_context.flat_constraints,
    dispatch_context.graphviz_flip,
  )
  (root_rank_keys, ordered_root)
}


///|
/// Graphviz parity: root reorder output map for clustered ordering is
/// produced by root mincross reorder followed by root-rank map transfer.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_output_from_root_reorder(
  dispatch_context : ClusterRankOrderFromRootReorderContext,
  root_reorder_output : RootClusterReorderInputsForRankOrderOutput,
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let (root_rank_keys, ordered_root) =
    run_root_cluster_rank_order_phase_from_root_reorder_output(
      dispatch_context,
      root_reorder_output,
    )
  append_root_cluster_rank_order_for_cluster_reorder(
    cluster_rank_order,
    root_rank_keys,
    ordered_root,
    dispatch_context.order_cluster_skeleton,
    dispatch_context.order_cluster_keys,
    dispatch_context.real_nodes,
  )
  cluster_rank_order
}

///|
/// Graphviz parity: root cluster-rank-order prep tuple alias keeps root
/// groups/edges/node-order field ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
type RootClusterReorderInputsForRankOrderOutput = (
  Map[Int, Array[String]],
  Array[Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, Int],
)

///|
/// Graphviz parity: root cluster-rank-order prep output keeps root groups,
/// root edge materialization arrays, and root node-order map tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_output(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
) -> RootClusterReorderInputsForRankOrderOutput {
  (
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
  )
}

///|
/// Graphviz parity: root reorder edge-bundle phase consumes root context
/// graph artifacts before root-only mincross input tuple assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_edge_bundle_phase(
  root_nlist_order : Array[String],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_graph : @cgraph.Graph,
  root_node_map : Map[String, @cgraph.Node],
  root_nodes : Array[String],
  root_ranks : Map[String, Int],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
) {
  build_root_cluster_reorder_edge_bundle(
    root_nlist_order,
    order_edges_by_tail_root,
    root_graph,
    root_node_map,
    root_nodes,
    root_ranks,
  )
}


///|
/// Graphviz parity: root reorder context phase materializes root rank/group
/// graph artifacts before root-edge bundle expansion for mincross inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_context_phase(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
) -> (
  Map[Int, Array[String]],
  Array[Int],
  Map[String, Int],
  Array[String],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
  Array[String],
  Map[String, Int],
) {
  build_root_cluster_reorder_context(
    order_with_vnodes,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    edges,
    edge_tail,
    edge_head,
    cluster_keys,
    edge_vnodes,
    vnodes_by_rank,
    vnode_order_keys_for_ordering,
    nlist_order,
    ranks,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root reorder from-context phase materializes root edge
/// bundle and assembles root-only reorder input tuple without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order_from_context_phase(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_ranks : Map[String, Int],
  root_nodes : Array[String],
  root_graph : @cgraph.Graph,
  root_node_map : Map[String, @cgraph.Node],
  root_nlist_order : Array[String],
  root_node_order : Map[String, Int],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> RootClusterReorderInputsForRankOrderOutput {
  let (
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
  ) =
    build_root_cluster_reorder_inputs_for_rank_order_edge_bundle_phase(
      root_nlist_order,
      order_edges_by_tail_root,
      root_graph,
      root_node_map,
      root_nodes,
      root_ranks,
    )
  build_root_cluster_reorder_inputs_for_rank_order_output(
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
  )
}


///|
/// Graphviz parity: root reorder context + root edge bundle are materialized
/// before root-only mincross in cluster-order phase.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_rank_order(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  edge_vnodes : Map[String, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> RootClusterReorderInputsForRankOrderOutput {
  let (
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
  ) =
    build_root_cluster_reorder_inputs_for_rank_order_context_phase(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      cluster_keys,
      edge_vnodes,
      vnodes_by_rank,
      vnode_order_keys_for_ordering,
      nlist_order,
      ranks,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
    )
  build_root_cluster_reorder_inputs_for_rank_order_from_context_phase(
    root_groups,
    root_rank_keys,
    root_ranks,
    root_nodes,
    root_graph,
    root_node_map,
    root_nlist_order,
    root_node_order,
    order_edges_by_tail_root,
  )
}

///|
/// Graphviz parity: enabled-cluster rank-order assembly consumes root reorder
/// materialization and forwards fields in Graphviz root-mincross order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_from_enabled_cluster_root_inputs(
  dispatch_context : ClusterRankOrderFromRootReorderContext,
  root_reorder_output : RootClusterReorderInputsForRankOrderOutput,
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_output_from_root_reorder(
    dispatch_context,
    root_reorder_output,
  )
}

///|
/// Graphviz parity: enabled-cluster rank-order prep pulls cluster-key/vnode
/// fields from cluster metadata before root-only reorder input assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_root_cluster_reorder_inputs_for_enabled_cluster_rank_order(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (
  Map[Int, Array[String]],
  Array[Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, Int],
) {
  build_root_cluster_reorder_inputs_for_rank_order(
    order_with_vnodes,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    edges,
    edge_tail,
    edge_head,
    cluster_meta.cluster_keys,
    vnode_info.edge_vnodes,
    vnode_info.vnodes_by_rank,
    vnode_order_keys_for_ordering,
    nlist_order,
    ranks,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    order_edges_by_tail_root,
  )
}

///|
/// Graphviz parity: cluster-enabled rank-order output maps root-only reorder
/// materialization into Graphviz cluster-rank-order assembly arguments.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_from_root_reorder_inputs(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  let root_reorder_output : RootClusterReorderInputsForRankOrderOutput = (
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
  )
  let dispatch_context : ClusterRankOrderFromRootReorderContext = {
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    flat_constraints,
    graphviz_flip,
    real_nodes,
  }
  build_cluster_rank_order_from_enabled_cluster_root_inputs(
    dispatch_context,
    root_reorder_output,
  )
}

///|
/// Graphviz parity: cluster-enabled rank-order forwarding reads rank-same and
/// flat-constraint maps from cluster metadata before root-order assembly call.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_from_root_reorder_with_cluster_meta(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_when_clusters_enabled_from_root_reorder_inputs(
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
    order_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: cluster-enabled rank-order root phase builds root-only
/// reorder payload before cluster-metadata forwarding and final map assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_root_reorder_phase(
  order_with_vnodes : Bool,
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
) -> (
  Map[Int, Array[String]],
  Array[Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, Int],
) {
  build_root_cluster_reorder_inputs_for_enabled_cluster_rank_order(
    order_with_vnodes,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    order_edges_by_tail_root,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
  )
}

///|
/// Graphviz parity: cluster-enabled rank-order from-root phase forwards
/// root-only reorder payload into cluster-metadata map assembly unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_from_root_reorder_phase(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_when_clusters_enabled_from_root_reorder_with_cluster_meta(
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: cluster-enabled rank-order finalize phase forwards
/// root-only reorder payload into final cluster-rank-order map assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_finalize_phase(
  root_groups : Map[Int, Array[String]],
  root_rank_keys : Array[Int],
  root_edges_out : Array[@cgraph.Edge],
  root_edge_tail_out : Array[String],
  root_edge_head_out : Array[String],
  root_edge_tail_port_x : Array[Double],
  root_edge_head_port_x : Array[Double],
  root_edge_tail_port_order : Array[Double],
  root_edge_head_port_order : Array[Double],
  root_parents : Map[String, Array[String]],
  root_children : Map[String, Array[String]],
  root_edge_order : Map[String, Int],
  root_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_when_clusters_enabled_from_root_reorder_phase(
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: cluster-enabled rank-order finalize dispatch reads
/// root-reorder tuple and forwards values in Graphviz argument ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled_finalize_phase_from_root_reorder_output(
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
  root_reorder_output : (
    Map[Int, Array[String]],
    Array[Int],
    Array[@cgraph.Edge],
    Array[String],
    Array[String],
    Array[Double],
    Array[Double],
    Array[Double],
    Array[Double],
    Map[String, Array[String]],
    Map[String, Array[String]],
    Map[String, Int],
    Map[String, Int],
  ),
) -> Map[Int, Map[String, Int]] {
  let (
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
  ) = root_reorder_output
  build_cluster_rank_order_when_clusters_enabled_finalize_phase(
    root_groups,
    root_rank_keys,
    root_edges_out,
    root_edge_tail_out,
    root_edge_head_out,
    root_edge_tail_port_x,
    root_edge_head_port_x,
    root_edge_tail_port_order,
    root_edge_head_port_order,
    root_parents,
    root_children,
    root_edge_order,
    root_node_order,
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: when cluster ordering is enabled, cluster rank-order map
/// is built from root-only reorder inputs and root mincross output.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_when_clusters_enabled(
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  let root_reorder_output =
    build_cluster_rank_order_when_clusters_enabled_root_reorder_phase(
      order_with_vnodes,
      order_rank_keys,
      order_groups_for_mincross,
      order_cluster_keys,
      order_cluster_skeleton,
      edges,
      edge_tail,
      edge_head,
      nlist_order,
      ranks,
      skeleton_edge_creation,
      root_edge_creation,
      flat_rank_constraints,
      order_edges_by_tail_root,
      cluster_meta,
      vnode_info,
      vnode_order_keys_for_ordering,
    )
  build_cluster_rank_order_when_clusters_enabled_finalize_phase_from_root_reorder_output(
    order_cluster_keys,
    cluster_meta,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    graphviz_flip,
    real_nodes,
    root_reorder_output,
  )
}

///|
/// Graphviz parity: cluster-phase rank-order map is built from root-only
/// reorder pass (root/skeleton + root-vnodes) before local cluster bucket
/// reordering in final real-node groups.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_for_cluster_reorder(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  if !order_with_clusters {
    return Map::new()
  }
  build_cluster_rank_order_when_clusters_enabled(
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: final rank groups drop non-real nodes after root ordering,
/// preserving rank iteration order and per-rank sequence.
/// Do not change behavior without updating fixtures/tests.
fn collect_real_only_rank_groups(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let cleaned_groups : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    let cleaned : Array[String] = []
    for name in names {
      if real_nodes.get(name) is Some(_) {
        cleaned.push(name)
      }
    }
    if cleaned.length() > 0 {
      cleaned_groups[rank] = cleaned
    }
  }
  cleaned_groups
}

///|
/// Graphviz parity: cluster reorder buckets keep first-seen cluster sequence
/// and preserve per-cluster node order within each rank.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_nodes_and_sequence_for_rank_reorder(
  names : Array[String],
  cluster_keys : Map[String, String],
) -> (Map[String, Array[String]], Array[String]) {
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  let cluster_seq : Array[String] = []
  for name in names {
    let cluster = cluster_key_or_empty(cluster_keys, name)
    match cluster_nodes.get(cluster) {
      Some(list) => list.push(name)
      None => {
        cluster_nodes[cluster] = [name]
        cluster_seq.push(cluster)
      }
    }
  }
  (cluster_nodes, cluster_seq)
}

///|
/// Graphviz parity: cluster bucket sort keys use root rank-order map with
/// stable first-seen sequence fallback for clusters missing from the map.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_ordered_keys_for_rank_reorder(
  order_map : Map[String, Int],
  cluster_seq : Array[String],
) -> Array[(Int, Int, String)] {
  let cluster_ordered : Array[(Int, Int, String)] = []
  for idx, cluster in cluster_seq {
    let base =
      match order_map.get(cluster) {
        Some(value) => value
        None => order_map.length() + idx
      }
    cluster_ordered.push((base, idx, cluster))
  }
  if cluster_ordered.length() > 1 {
    cluster_ordered.sort_by((a, b) => {
      let (a_order, a_idx, _a_name) = a
      let (b_order, b_idx, _b_name) = b
      if a_order < b_order {
        -1
      } else if a_order > b_order {
        1
      } else if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  cluster_ordered
}

///|
/// Graphviz parity: cluster bucket flattening emits clusters in sorted bucket
/// order while preserving each cluster's original node sequence.
/// Do not change behavior without updating fixtures/tests.
fn flatten_cluster_ordered_names_for_rank_reorder(
  cluster_ordered : Array[(Int, Int, String)],
  cluster_nodes : Map[String, Array[String]],
) -> Array[String] {
  let ordered_names : Array[String] = []
  for entry in cluster_ordered {
    let (_order, _idx, cluster) = entry
    let nodes_in_cluster = match cluster_nodes.get(cluster) {
      Some(list) => list
      None => []
    }
    for name in nodes_in_cluster {
      ordered_names.push(name)
    }
  }
  ordered_names
}

///|
/// Graphviz parity: cluster-phase reorder keeps intra-cluster node order, then
/// reorders cluster buckets by root mincross rank map with stable tie-breaks.
/// Do not change behavior without updating fixtures/tests.
fn reorder_rank_groups_by_cluster_rank_order(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let ordered_by_cluster : Map[Int, Array[String]] = Map::new()
  for rank, names in final_groups {
    let order_map = match cluster_rank_order.get(rank) {
      Some(value) => value
      None => {
        ordered_by_cluster[rank] = names
        continue
      }
    }
    if names.length() > 2 {
      let mut first_cluster = -1
      let mut last_cluster = -1
      let mut root_before = false
      let mut root_after = false
      for i in 0..<names.length() {
        let cluster = cluster_key_or_empty(cluster_keys, names[i])
        if cluster != "" {
          if first_cluster < 0 {
            first_cluster = i
          }
          last_cluster = i
        }
      }
      if first_cluster >= 0 {
        for i in 0..<first_cluster {
          if cluster_key_or_empty(cluster_keys, names[i]) == "" {
            root_before = true
            break
          }
        }
        if last_cluster + 1 < names.length() {
          for i in (last_cluster + 1)..<names.length() {
            if cluster_key_or_empty(cluster_keys, names[i]) == "" {
              root_after = true
              break
            }
          }
        }
      }
      if root_before && root_after {
        ordered_by_cluster[rank] = names
        continue
      }
    }
    let (cluster_nodes, cluster_seq) =
      collect_cluster_nodes_and_sequence_for_rank_reorder(names, cluster_keys)
    let cluster_ordered =
      build_cluster_ordered_keys_for_rank_reorder(order_map, cluster_seq)
    let ordered_names =
      flatten_cluster_ordered_names_for_rank_reorder(
        cluster_ordered,
        cluster_nodes,
      )
    ordered_by_cluster[rank] = ordered_names
  }
  ordered_by_cluster
}

///|
/// Graphviz parity: trailing-vnode marking applies only to non-internal,
/// cross-cluster edges whose endpoint cluster rank ranges do not overlap.
/// Do not change behavior without updating fixtures/tests.
fn should_trail_intercluster_vnodes_for_edge(
  tail_cluster : String,
  head_cluster : String,
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Bool {
  let internal =
    tail_cluster != "" && head_cluster != "" &&
    edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
  if internal || tail_cluster == head_cluster {
    return false
  }
  if tail_cluster == "" || head_cluster == "" {
    return false
  }
  let tail_min = match cluster_min_rank.get(tail_cluster) {
    Some(value) => value
    None => 0
  }
  let tail_max = match cluster_max_rank.get(tail_cluster) {
    Some(value) => value
    None => tail_min
  }
  let head_min = match cluster_min_rank.get(head_cluster) {
    Some(value) => value
    None => 0
  }
  let head_max = match cluster_max_rank.get(head_cluster) {
    Some(value) => value
    None => head_min
  }
  let overlap = tail_min <= head_max && head_min <= tail_max
  !overlap
}

///|
/// Graphviz parity: ReMincross trailing vnode set marks intercluster edge
/// vnodes whose endpoint cluster rank ranges do not overlap.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_trailing_vnodes(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Bool] {
  let intercluster_vnodes : Map[String, Bool] = Map::new()
  if !order_with_vnodes {
    return intercluster_vnodes
  }
  let mut edge_idx = 0
  for edge in edges {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if should_trail_intercluster_vnodes_for_edge(
      tail_cluster,
      head_cluster,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
    ) {
      let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      for vnode in vnodes {
        intercluster_vnodes[vnode] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  intercluster_vnodes
}

///|
/// Graphviz parity: trailing-vnode floor uses the maximum real-node order seen
/// per rank from the current ReMincross base order index.
/// Do not change behavior without updating fixtures/tests.
fn collect_max_real_order_by_rank_for_intercluster_floor(
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
) -> Map[Int, Int] {
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in rem_base_order_index {
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    match max_order_by_rank.get(rank) {
      Some(current) =>
        if order > current {
          max_order_by_rank[rank] = order
        }
      None => max_order_by_rank[rank] = order
    }
  }
  max_order_by_rank
}

///|
/// Graphviz parity: trailing intercluster vnodes get a minimum order key just
/// after the max real-node order on their rank (stable tiny seq offset).
/// Do not change behavior without updating fixtures/tests.
fn apply_intercluster_vnode_order_key_floor(
  keys : Map[String, Double],
  intercluster_vnodes : Map[String, Bool],
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Unit {
  if intercluster_vnodes.length() == 0 {
    return
  }
  let max_order_by_rank =
    collect_max_real_order_by_rank_for_intercluster_floor(
      rem_base_order_index,
      ranks,
    )
  let mut seq = 0
  for vnode, _ in intercluster_vnodes {
    let rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let max_order = match max_order_by_rank.get(rank) {
      Some(value) => value
      None => -1
    }
    let base = Double::from_int(max_order + 1)
    let offset = Double::from_int(seq) * 0.000001
    let min_key = base + offset
    match keys.get(vnode) {
      Some(current) =>
        if current < min_key {
          keys[vnode] = min_key
        }
      None => keys[vnode] = min_key
    }
    seq = seq + 1
  }
}

///|
/// Graphviz parity: ReMincross local flat constraints keep only endpoints that
/// exist in the current fast graph node map.
/// Do not change behavior without updating fixtures/tests.
fn filter_flat_constraints_for_node_map(
  flat_rank_constraints : Map[String, Bool],
  node_map : Map[String, @cgraph.Node],
) -> Map[String, Bool] {
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  for key, _ in flat_rank_constraints {
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else {
          ""
        }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        if node_map.get(tail) is Some(_) && node_map.get(head) is Some(_) {
          rem_flat_constraints[key] = true
        }
      }
      None => ()
    }
  }
  rem_flat_constraints
}

///|
/// Graphviz parity: ReMincross creation order starts from tail creation order
/// then appends each tail vnode sequence once (stable dedupe).
/// Do not change behavior without updating fixtures/tests.
fn build_rem_order_creation_sequence(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
) -> Array[String] {
  let rem_order_creation : Array[String] = []
  let rem_seen : Map[String, Bool] = Map::new()
  for tail_name in creation_order {
    if rem_seen.get(tail_name) is None {
      rem_seen[tail_name] = true
      rem_order_creation.push(tail_name)
    }
    let vnodes = match rem_vnode_creation.get(tail_name) {
      Some(list) => list
      None => []
    }
    for vnode in vnodes {
      if rem_seen.get(vnode) is None {
        rem_seen[vnode] = true
        rem_order_creation.push(vnode)
      }
    }
  }
  rem_order_creation
}

///|
/// Graphviz parity: ReMincross vnode order keys follow vnodes_by_rank keys
/// with trailing intercluster vnode floor adjustment before rank merge.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_vnode_order_keys(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  rem_base_order_index : Map[String, Int],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  if !order_with_vnodes {
    return Map::new()
  }
  let remincross_cluster_keys : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    remincross_cluster_keys[name] = key
  }
  for name, _ in rem_base_order_index {
    match remincross_cluster_keys.get(name) {
      Some(value) =>
        if value == "" {
          remincross_cluster_keys[name] = "g"
        }
      None => remincross_cluster_keys[name] = "g"
    }
  }
  let intercluster_vnodes =
    collect_intercluster_trailing_vnodes(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      remincross_cluster_keys,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
      edge_vnodes,
    )
  let keys = build_vnode_order_keys(
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    rem_base_order_index,
    remincross_cluster_keys,
    cluster_parents,
    edge_vnodes,
    vnode_ranks,
  )
  apply_intercluster_vnode_order_key_floor(
    keys,
    intercluster_vnodes,
    rem_base_order_index,
    ranks,
    vnode_ranks,
  )
  keys
}

///|
/// Graphviz parity: ReMincross rank groups start from real-node groups and
/// optionally inject edge-vnodes using vnode order keys from cluster-aware
/// trailing-vnode adjustments.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_with_optional_vnodes(
  final_groups : Map[Int, Array[String]],
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let rem_base_groups = clone_rank_groups(final_groups)
  let rem_base_order_index = build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    build_remincross_vnode_order_keys(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      rem_base_order_index,
      intercluster_keys,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
      edge_vnodes,
      vnode_ranks,
    )
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
}

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_nlist_order(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_flat_constraints : Map[String, Bool],
) -> Array[String] {
  let rem_edge_creation_order : Array[(String, String)] = []
  for edge in rem_edge_creation {
    rem_edge_creation_order.push(edge)
  }
  let rem_order_creation =
    build_rem_order_creation_sequence(creation_order, rem_vnode_creation)
  // Graphviz parity: GD_nlist seeding uses agfstnode order for the
  // fast graph (reverse creation insertion).
  let rem_order_creation_rev : Array[String] = []
  let mut rem_rev_idx = rem_order_creation.length()
  while rem_rev_idx > 0 {
    rem_rev_idx = rem_rev_idx - 1
    rem_order_creation_rev.push(rem_order_creation[rem_rev_idx])
  }
  build_graphviz_nlist_order_from_edges(
    rem_order_creation_rev,
    rem_order_creation,
    rem_edge_creation_order,
    rem_flat_constraints,
  )
}

///|
/// Graphviz parity: ReMincross order-graph materialization filters local flat
/// constraints by fast-graph membership, rebuilds GD_nlist, seeds node order,
/// then materializes edge arrays in nlist tail order.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_materialized_order_graph(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let rem_flat_constraints =
    filter_flat_constraints_for_node_map(
      flat_rank_constraints,
      rem_node_map,
    )
  let rem_nlist_order =
    build_remincross_nlist_order(
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_flat_constraints,
    )
  let rem_node_order =
    build_order_node_order_from_nlist_and_groups(
      rem_nlist_order,
      rem_node_map,
      rem_groups,
    )
  let (
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    collect_order_edges_for_tail_sequence(
      rem_nlist_order,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
    )
  build_clustered_remincross_materialized_edges_output(
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: ReMincross base cluster keys copy intercluster keys and
/// map empty keys to a non-empty root ND_clust key (mark_lowclusters).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys_base(
  graph : @cgraph.Graph,
  intercluster_keys : Map[String, String],
) -> (Map[String, String], String) {
  let rem_cluster_keys : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    rem_cluster_keys[name] = key
  }
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  let root_cluster = match graph.name() {
    Some(value) => value
    None => "__root__"
  }
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = root_cluster
    }
  }
  (rem_cluster_keys, root_cluster)
}


///|
/// Graphviz parity: ReMincross virtual nodes take the LCA endpoint cluster
/// (or root fallback) from intercluster edge endpoints.
/// Do not change behavior without updating fixtures/tests.
fn assign_remincross_vnode_clusters_from_edges(
  rem_cluster_keys : Map[String, String],
  root_cluster : String,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Unit {
  let mut edge_idx = 0
  for edge in edges {
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      edge_idx = edge_idx + 1
      continue
    }
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
    let head_cluster = cluster_key_or_empty(intercluster_keys, head)
    // Graphviz parity: mark_lowclusters assigns virtual nodes to the
    // lowest common ancestor cluster for intercluster edges.
    let vnode_cluster =
      cluster_lowest_common_ancestor(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: ReMincross cluster keys start from intercluster keys,
/// map empty keys to the root graph key, and assign edge vnodes to the LCA
/// cluster (mark_lowclusters) for cluster-boundary swap guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, String] {
  let (rem_cluster_keys, root_cluster) =
    build_remincross_cluster_keys_base(graph, intercluster_keys)
  if !order_with_vnodes {
    return rem_cluster_keys
  }
  assign_remincross_vnode_clusters_from_edges(
    rem_cluster_keys,
    root_cluster,
    edges,
    edge_tail,
    edge_head,
    intercluster_keys,
    cluster_parents,
    edge_vnodes,
  )
  rem_cluster_keys
}

///|
/// Graphviz parity: intercluster short-span guard selects only edges crossing
/// cluster keys with absolute rank difference <= 1.
/// Do not change behavior without updating fixtures/tests.
fn edge_has_intercluster_short_span(
  tail : String,
  head : String,
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Bool {
  let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
  let head_cluster = cluster_key_or_empty(intercluster_keys, head)
  if tail_cluster == head_cluster {
    return false
  }
  let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
  let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
  let span = if tail_rank <= head_rank {
    head_rank - tail_rank
  } else {
    tail_rank - head_rank
  }
  span <= 1
}

///|
/// Graphviz parity: intercluster node guard marks real endpoints of
/// intercluster edges with rank span <= 1 for local-order relaxation.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_nodes_with_short_span(
  order_with_clusters : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_nodes : Map[String, Bool] = Map::new()
  if !order_with_clusters {
    return intercluster_nodes
  }
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if edge_has_intercluster_short_span(
      tail,
      head,
      intercluster_keys,
      ranks,
    ) {
      intercluster_nodes[tail] = true
      intercluster_nodes[head] = true
    }
    edge_idx = edge_idx + 1
  }
  intercluster_nodes
}

///|
/// Graphviz parity: root/ReMincross node-order seeding follows GD_nlist order
/// and fills missing nodes from current rank-group index.
/// Do not change behavior without updating fixtures/tests.
fn build_order_node_order_from_nlist_and_groups(
  nlist_order : Array[String],
  node_map : Map[String, @cgraph.Node],
  groups : Map[Int, Array[String]],
) -> Map[String, Int] {
  let node_order_out : Map[String, Int] = Map::new()
  let mut node_idx = 0
  for name in nlist_order {
    if node_map.get(name) is Some(_) {
      node_order_out[name] = node_idx
      node_idx = node_idx + 1
    }
  }
  let order_index = build_order_index(groups)
  for name, idx in order_index {
    if node_order_out.get(name) is None {
      node_order_out[name] = idx
    }
  }
  node_order_out
}

///|
/// Graphviz parity: ReMincross cluster-local flat locks keep adjacent real
/// nodes in the same non-empty cluster when both are non-intercluster nodes.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_local_flat_constraints_for_remincross_rank(
  rem_flat_constraints : Map[String, Bool],
  names : Array[String],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> Unit {
  let mut prev_real : String? = None
  let mut prev_cluster = ""
  let mut prev_inter = false
  for name in names {
    if real_nodes.get(name) is None {
      continue
    }
    let cluster = cluster_key_or_empty(rem_cluster_keys, name)
    let inter = intercluster_nodes.get(name) is Some(_)
    match prev_real {
      Some(prev) =>
        if cluster != "" && cluster == prev_cluster && !prev_inter && !inter {
          rem_flat_constraints["\{prev}|\{name}"] = true
        }
      None => ()
    }
    prev_real = Some(name)
    prev_cluster = cluster
    prev_inter = inter
  }
}

///|
/// Graphviz parity: ReMincross flat constraints combine existing same-rank
/// constraints with local intra-cluster adjacency locks for non-intercluster
/// real-node pairs (flat.c cluster-local reorder guard).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_flat_constraints(
  flat_constraints : Map[String, Bool],
  rank_same_constraints : Map[String, Bool],
  order_with_clusters : Bool,
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> Map[String, Bool] {
  let rem_flat_constraints = clone_flat_constraints(flat_constraints)
  for key, _ in rank_same_constraints {
    rem_flat_constraints[key] = true
  }
  if !order_with_clusters {
    return rem_flat_constraints
  }
  // Graphviz parity: keep relative order of real nodes that are
  // internal to a cluster; allow nodes with intercluster edges to reorder.
  for _rank, names in rem_groups {
    apply_cluster_local_flat_constraints_for_remincross_rank(
      rem_flat_constraints,
      names,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  }
  rem_flat_constraints
}

///|
/// Graphviz parity: ReMincross clustered reorder executes mincross with
/// startpass=2 on rematerialized fast-graph edges and local flat constraints.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_rank_reorder_startpass2(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    for rank in rem_rank_keys {
      let names = match rem_groups.get(rank) {
        Some(list) => list
        None => []
      }
      let rank_joined = names.join(" ")
      println("remincross_input_rank \{rank}: \{rank_joined}")
    }
    let mut idx = 0
    while idx < rem_edges_out.length() {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      let pen = edge_xpenalty(rem_edges_out[idx])
      println("remincross_input_edge \{idx}: \{tail} -> \{head} pen=\{pen}")
      idx = idx + 1
    }
  }
  reorder_rank_groups(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    rank_same_groups,
    rank_same_order,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    Map::new(),
    rem_flat_constraints,
    graphviz_flip=graphviz_flip,
    // Graphviz parity: ReMincross counts parallel chain segments once
    // with summed xpenalty before startpass=2 transposition.
    coalesce_parallel_edges=true,
    startpass=2,
    remincross_mode=true,
  )
}

///|
/// Graphviz parity: ReMincross final reorder runs with startpass=2 using
/// materialized fast-graph edges, then drops non-real nodes for final groups
/// while preserving rank iteration and per-rank order.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_reorder_and_collect_real_groups(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_ordered =
    run_remincross_rank_reorder_startpass2(
      rem_rank_keys,
      rem_groups,
      rem_edges_out,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_edge_tail_port_x,
      rem_edge_head_port_x,
      rem_edge_tail_port_order,
      rem_edge_head_port_order,
      rem_parents,
      rem_children,
      rem_cluster_keys,
      rank_same_groups,
      rank_same_order,
      rem_edge_order,
      rem_node_order,
      rem_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      rem_flat_constraints,
      graphviz_flip,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    dot_trace_groups("remincross_ordered", rem_ordered)
  }
  let rem_cleaned =
    collect_real_only_rank_groups(rem_rank_keys, rem_ordered, real_nodes)
  (rem_ordered, rem_cleaned)
}

///|
/// Graphviz parity: ReMincross reorder cluster inputs derive cluster keys
/// (including vnode LCA assignments) and intercluster short-span node guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_inputs_for_reorder(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> (Map[String, String], Map[String, Bool]) {
  let rem_cluster_keys =
    build_remincross_cluster_keys(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      vnode_info.edge_vnodes,
    )
  let intercluster_nodes =
    collect_intercluster_nodes_with_short_span(
      order_with_clusters,
      edge_tail,
      edge_head,
      cluster_meta.intercluster_keys,
      ranks,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_vnodes : Array[String] = [
      "_mbt_edge_vn_0_3",
      "_mbt_edge_vn_1_3",
    ]
    for name in debug_vnodes {
      let cluster = cluster_key_or_empty(rem_cluster_keys, name)
      println("remincross vnode \{name} cluster=\{cluster}")
    }
  }
  (rem_cluster_keys, intercluster_nodes)
}

///|
/// Graphviz parity: ReMincross reorder size/constraint inputs extend sizes with
/// vnode dimensions and augment flat constraints with same-rank + cluster-local
/// guards before final reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_sizes_and_flat_constraints(
  order_sizes : Map[String, NodeSize],
  order_with_vnodes : Bool,
  vnode_sizes : Map[String, NodeSize],
  flat_constraints : Map[String, Bool],
  rank_same_constraints : Map[String, Bool],
  order_with_clusters : Bool,
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> (Map[String, NodeSize], Map[String, Bool]) {
  let rem_sizes =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_sizes,
    )
  let rem_flat_constraints =
    build_remincross_flat_constraints(
      flat_constraints,
      rank_same_constraints,
      order_with_clusters,
      rem_groups,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  (rem_sizes, rem_flat_constraints)
}

///|
/// Graphviz parity: ReMincross reorder inputs derive cluster keys (including
/// vnode LCA assignments), local intercluster-node guards, size map extension,
/// and flat-constraint augmentation before final reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_reorder_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> (Map[String, String], Map[String, NodeSize], Map[String, Bool]) {
  let (rem_cluster_keys, intercluster_nodes) =
    build_remincross_cluster_inputs_for_reorder(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      order_with_clusters,
      ranks,
      cluster_meta,
      vnode_info,
    )
  let (rem_sizes, rem_flat_constraints) =
    build_remincross_sizes_and_flat_constraints(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
      cluster_meta.flat_constraints,
      rank_same_constraints,
      order_with_clusters,
      rem_groups,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  (rem_cluster_keys, rem_sizes, rem_flat_constraints)
}

///|
/// Debug trace: dump selected ReMincross per-tail edge lists when
/// DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_order_edges_by_tail(
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  match rem_order_edges_by_tail.get("arbiter_vadam") {
    Some(list) => {
      let mut idx = 0
      while idx < list.length() {
        let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
        println("remincross arbiter edge \{idx}: \{t} -> \{h}")
        idx = idx + 1
      }
    }
    None => ()
  }
  let debug_tails : Array[String] = ["front_end_jz", "others"]
  for name in debug_tails {
    match rem_order_edges_by_tail.get(name) {
      Some(list) => {
        let mut idx = 0
        while idx < list.length() {
          let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
          println("remincross out \{name} \{idx}: \{t} -> \{h}")
          idx = idx + 1
        }
      }
      None => ()
    }
  }
}

///|
/// Debug trace: dump materialized ReMincross edges (high-pen and selected
/// endpoints) when DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_materialized_edges(
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let mut idx = 0
  while idx < rem_edges_out.length() {
    let edge = rem_edges_out[idx]
    let pen = edge_xpenalty(edge)
    if pen >= CL_CROSS {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      println("remincross high-pen edge \{tail} -> \{head} pen=\{pen}")
    }
    idx = idx + 1
  }
  let mut edge_idx = 0
  while edge_idx < rem_edge_tail_out.length() {
    let tail = rem_edge_tail_out[edge_idx]
    let head = rem_edge_head_out[edge_idx]
    if tail == "z_req" || tail == "z_req1" || head == "z_req" ||
      head == "z_req1" {
      println("remincross edge \{edge_idx}: \{tail} -> \{head}")
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: clustered ReMincross final reorder runs with real-node
/// cleanup after vnode-inclusive rematerialized edge ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_final_reorder(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_remincross_reorder_and_collect_real_groups(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    rank_same_groups,
    rank_same_order,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    rem_flat_constraints,
    graphviz_flip,
    real_nodes,
  )
}

///|
/// Graphviz parity: clustered ReMincross derives rank map, order-node list,
/// and temporary order graph directly from vnode-augmented rem_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_graph_inputs(
  rem_groups : Map[Int, Array[String]],
  rem_rank_keys : Array[Int],
) -> (Map[String, Int], Array[String], @cgraph.Graph, Map[String, @cgraph.Node]) {
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nodes = build_order_nodes_from_groups(rem_groups, rem_rank_keys)
  let (rem_graph, rem_node_map) =
    build_order_graph_and_nodes("order_remincross", rem_nodes)
  (rem_ranks, rem_nodes, rem_graph, rem_node_map)
}

///|
/// Graphviz parity: clustered ReMincross order-edge rematerialization uses
/// Graphviz ND_out chain expansion with vnode creation + edge creation outputs.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_order_edges_by_tail(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  let rem_edges_by_tail = edges_by_tail
  let (rem_order_edges_by_tail_raw, rem_vnode_creation, _rem_edge_creation_raw) =
    build_order_edges_by_tail_graphviz(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      false,
      false,
      rem_edges_by_tail,
    )
  let rem_order_edges_by_tail_coalesced =
    coalesce_order_edges_by_tail(rem_order_edges_by_tail_raw)
  let intercluster_bonus =
    collect_intercluster_vnode_tail_bonus(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      rem_edges_by_tail,
      cluster_keys,
    )
  let rem_order_edges_by_tail =
    apply_intercluster_vnode_tail_bonus(
      rem_order_edges_by_tail_coalesced,
      intercluster_bonus,
    )
  let rem_edge_creation =
    rebuild_edge_creation_from_tail_order(
      creation_order,
      rem_order_edges_by_tail,
    )
  (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation)
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge flow traces
/// ND_out-derived remapped edge chains immediately after Graphviz-style
/// edge rematerialization inputs are constructed.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_order_edges_by_tail_with_trace(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  let (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation) =
    build_clustered_remincross_order_edges_by_tail(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      edges_by_tail,
    )
  trace_remincross_order_edges_by_tail(rem_order_edges_by_tail)
  (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation)
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge flow rebuilds
/// remapped order graph arrays, then traces edge endpoints before tuple output.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_graph_with_trace(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_remincross_materialized_order_graph(
      flat_rank_constraints,
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  trace_remincross_materialized_edges(
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
  )
  (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge output preserves
/// node-order and remapped edge/port arrays in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges_output(
  rem_node_order : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}


///|
/// Graphviz parity: clustered ReMincross materialized-edge output phase keeps
/// graph-materialization tuple ordering before returning remapped edge arrays.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges_output_phase(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_clustered_remincross_materialized_graph_with_trace(
      flat_rank_constraints,
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  build_clustered_remincross_materialized_edges_output(
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: clustered ReMincross materializes remapped order edges
/// from ND_out chains, then rebuilds GD_nlist-seeded edge arrays with traces.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  flat_rank_constraints : Map[String, Bool],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation) =
    build_clustered_remincross_order_edges_by_tail_with_trace(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      edges_by_tail,
    )
  build_clustered_remincross_materialized_edges_output_phase(
    flat_rank_constraints,
    creation_order,
    rem_vnode_creation,
    rem_edge_creation,
    rem_order_edges_by_tail,
    rem_graph,
    rem_node_map,
    rem_groups,
  )
}

///|
/// Graphviz parity: clustered ReMincross edge index inputs are derived from
/// rematerialized edge arrays before the final startpass=2 reorder call.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_edge_indices_for_reorder(
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  build_order_edge_indices_and_order(
    rem_nodes,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_ranks,
    rem_edges_out,
  )
}

///|
/// Graphviz parity: clustered ReMincross reorder step forwards rematerialized
/// edge/reorder inputs with cluster metadata into final cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_from_reorder_inputs(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_final_reorder(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    rem_flat_constraints,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step edge-index phase builds
/// parent/child maps plus edge-order indices from rematerialized edge arrays.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs_edge_indices_phase(
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  build_clustered_remincross_edge_indices_for_reorder(
    rem_nodes,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_ranks,
    rem_edges_out,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step metadata phase derives
/// cluster keys, sizes, and flat constraints from current rem_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs_metadata_phase(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> (Map[String, String], Map[String, NodeSize], Map[String, Bool]) {
  build_remincross_reorder_inputs(
    graph,
    edges,
    edge_tail,
    edge_head,
    order_with_vnodes,
    order_with_clusters,
    ranks,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_groups,
    real_nodes,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step input payload keeps
/// edge-index and cluster-aware metadata tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
type ClusteredReMincrossReorderStepInputsOutput = (
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, String],
  Map[String, NodeSize],
  Map[String, Bool],
)

///|
/// Graphviz parity: clustered ReMincross reorder-step input output preserves
/// edge-index maps and cluster-aware metadata tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs_output(
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_edge_order : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_sizes : Map[String, NodeSize],
  rem_flat_constraints : Map[String, Bool],
) -> ClusteredReMincrossReorderStepInputsOutput {
  (
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step input phase derives edge
/// indices plus cluster-aware reorder maps before final cleanup forwarding.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> ClusteredReMincrossReorderStepInputsOutput {
  let (rem_parents, rem_children, rem_edge_order) =
    build_clustered_remincross_reorder_step_inputs_edge_indices_phase(
      rem_nodes,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_ranks,
      rem_edges_out,
    )
  let (rem_cluster_keys, rem_sizes, rem_flat_constraints) =
    build_clustered_remincross_reorder_step_inputs_metadata_phase(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      order_with_clusters,
      ranks,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      rem_groups,
      real_nodes,
    )
  build_clustered_remincross_reorder_step_inputs_output(
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  )
}

///|
/// Graphviz parity: clustered ReMincross reorder-step execution forwards
/// prepared indices/cluster maps into startpass=2 cleanup reorder call.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_reorder_phase(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_reorder_step_from_reorder_inputs(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    cluster_meta,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    rem_flat_constraints,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step finalize phase forwards
/// prepared index/cluster maps into final cleanup reorder execution.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_finalize_phase(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_reorder_step_reorder_phase(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    cluster_meta,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    rem_flat_constraints,
    graphviz_flip,
    real_nodes,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step input phase prepares
/// edge-index maps and cluster-aware reorder metadata before cleanup phase.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_input_phase(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> ClusteredReMincrossReorderStepInputsOutput {
  build_clustered_remincross_reorder_step_inputs(
    graph,
    edges,
    edge_tail,
    edge_head,
    order_with_vnodes,
    order_with_clusters,
    ranks,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_groups,
    real_nodes,
    rem_nodes,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_ranks,
    rem_edges_out,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step finalize dispatch context
/// preserves cleanup reorder arguments in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_finalize_dispatch_context(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  cluster_meta : ClusterMetadata,
  rem_node_order : Map[String, Int],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> ClusteredReMincrossReorderStepFinalizeDispatchContext {
  {
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    cluster_meta,
    rem_node_order,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    real_nodes,
  }
}


///|
/// Graphviz parity: clustered ReMincross reorder-step finalize dispatch reads
/// input-phase tuple and forwards values in Graphviz finalize-call order.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_finalize_phase_from_input_phase_output(
  dispatch_context : ClusteredReMincrossReorderStepFinalizeDispatchContext,
  input_phase_output : ClusteredReMincrossReorderStepInputsOutput,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  ) = input_phase_output
  run_clustered_remincross_reorder_step_finalize_phase(
    dispatch_context.rem_rank_keys,
    dispatch_context.rem_groups,
    dispatch_context.rem_edges_out,
    dispatch_context.rem_edge_tail_out,
    dispatch_context.rem_edge_head_out,
    dispatch_context.rem_edge_tail_port_x,
    dispatch_context.rem_edge_head_port_x,
    dispatch_context.rem_edge_tail_port_order,
    dispatch_context.rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    dispatch_context.cluster_meta,
    rem_edge_order,
    dispatch_context.rem_node_order,
    rem_sizes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    rem_flat_constraints,
    dispatch_context.graphviz_flip,
    dispatch_context.real_nodes,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step context builder keeps
/// rematerialized arrays and cleanup metadata argument ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_context(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> ClusteredReMincrossReorderStepContext {
  {
    graph,
    edges,
    edge_tail,
    edge_head,
    order_with_vnodes,
    order_with_clusters,
    ranks,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_node_order,
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  }
}


///|
/// Graphviz parity: clustered ReMincross computes edge indices, prepares
/// cluster-aware reorder inputs, then runs final real-node cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step(
  context : ClusteredReMincrossReorderStepContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let input_phase_output =
    run_clustered_remincross_reorder_step_input_phase(
      context.graph,
      context.edges,
      context.edge_tail,
      context.edge_head,
      context.order_with_vnodes,
      context.order_with_clusters,
      context.ranks,
      context.cluster_meta,
      context.vnode_info,
      context.order_sizes,
      context.rank_same_constraints,
      context.rem_groups,
      context.real_nodes,
      context.rem_nodes,
      context.rem_edge_tail_out,
      context.rem_edge_head_out,
      context.rem_ranks,
      context.rem_edges_out,
    )
  let dispatch_context =
    build_clustered_remincross_reorder_step_finalize_dispatch_context(
      context.rem_rank_keys,
      context.rem_groups,
      context.rem_edges_out,
      context.rem_edge_tail_out,
      context.rem_edge_head_out,
      context.rem_edge_tail_port_x,
      context.rem_edge_head_port_x,
      context.rem_edge_tail_port_order,
      context.rem_edge_head_port_order,
      context.cluster_meta,
      context.rem_node_order,
      context.nodesep_pt,
      context.has_edge_labels,
      context.port_order_positions,
      context.port_order_contrib,
      context.graphviz_flip,
      context.real_nodes,
    )
  run_clustered_remincross_reorder_step_finalize_phase_from_input_phase_output(
    dispatch_context,
    input_phase_output,
  )
}

///|
/// Graphviz parity: clustered ReMincross output keeps vnode-augmented and
/// cleaned real-node groups in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  next_final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (next_ordered_with_vnodes, next_final_groups)
}

///|
/// Graphviz parity: clustered ReMincross multi-rank input tuple preserves
/// node-order, rank map, and rematerialized edge/port arrays ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_reorder_inputs_output(
  rem_node_order : Map[String, Int],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
) -> (
  Map[String, Int],
  Array[String],
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  (
    rem_node_order,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: clustered ReMincross multi-rank edge materialization keeps
/// cluster-key and vnode maps sourced from stage metadata before forwarding.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_materialized_edges(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  build_clustered_remincross_materialized_edges(
    creation_order,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    vnode_info.edge_vnodes,
    order_with_vnodes,
    cluster_meta.cluster_keys,
    order_with_clusters,
    edges_by_tail,
    flat_rank_constraints,
    rem_graph,
    rem_node_map,
    rem_groups,
  )
}


///|
/// Graphviz parity: clustered ReMincross multi-rank reorder inputs are built
/// from vnode-augmented rem_groups via temporary order graph + rematerialized
/// edge arrays seeded from GD_nlist order.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_reorder_inputs(
  input_context : ClusteredReMincrossMultiRankReorderInputsContext,
  rem_groups : Map[Int, Array[String]],
  rem_rank_keys : Array[Int],
) -> (
  Map[String, Int],
  Array[String],
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (rem_ranks, rem_nodes, rem_graph, rem_node_map) =
    build_clustered_remincross_graph_inputs(rem_groups, rem_rank_keys)
  // Graphviz parity: ReMincross uses real intercluster edges
  // (no cluster skeleton mapping).
  let (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_clustered_remincross_multi_rank_materialized_edges(
      input_context.creation_order,
      input_context.edges,
      input_context.edge_tail,
      input_context.edge_head,
      input_context.edge_tail_port_x,
      input_context.edge_head_port_x,
      input_context.edge_tail_port_order,
      input_context.edge_head_port_order,
      input_context.ranks,
      input_context.order_with_vnodes,
      input_context.order_with_clusters,
      input_context.flat_rank_constraints,
      input_context.edges_by_tail,
      input_context.cluster_meta,
      input_context.vnode_info,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  build_clustered_remincross_multi_rank_reorder_inputs_output(
    rem_node_order,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: clustered ReMincross multi-rank forwarding keeps
/// rematerialized arrays and reorder metadata in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_from_reorder_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_step_context =
    build_clustered_remincross_reorder_step_context(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      order_with_clusters,
      ranks,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      rem_rank_keys,
      rem_groups,
      rem_nodes,
      rem_ranks,
      rem_edges_out,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_edge_tail_port_x,
      rem_edge_head_port_x,
      rem_edge_tail_port_order,
      rem_edge_head_port_order,
      rem_node_order,
      real_nodes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      graphviz_flip,
    )
  run_clustered_remincross_reorder_step(reorder_step_context)
}


///|
/// Graphviz parity: clustered ReMincross multi-rank input phase keeps
/// rematerialized reorder arrays in Graphviz tuple ordering before cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_reorder_inputs_phase(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  rem_groups : Map[Int, Array[String]],
  rem_rank_keys : Array[Int],
) -> (
  Map[String, Int],
  Array[String],
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let input_context : ClusteredReMincrossMultiRankReorderInputsContext = {
    creation_order,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    order_with_vnodes,
    order_with_clusters,
    flat_rank_constraints,
    edges_by_tail,
    cluster_meta,
    vnode_info,
  }
  build_clustered_remincross_multi_rank_reorder_inputs(
    input_context,
    rem_groups,
    rem_rank_keys,
  )
}

///|
/// Graphviz parity: clustered ReMincross multi-rank reorder phase forwards
/// rematerialized arrays into startpass=2 cleanup without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_reorder_phase(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_multi_rank_from_reorder_inputs(
    graph,
    edges,
    edge_tail,
    edge_head,
    order_with_vnodes,
    order_with_clusters,
    ranks,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_node_order,
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: clustered ReMincross multi-rank finalize phase runs
/// startpass=2 cleanup reorder using rematerialized reorder payload tuple.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_finalize_phase(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_multi_rank_reorder_phase(
    graph,
    edges,
    edge_tail,
    edge_head,
    order_with_vnodes,
    order_with_clusters,
    ranks,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_node_order,
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: clustered ReMincross finalize output dispatch unpacks
/// rematerialized reorder tuple and forwards typed payload unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output_with_context(
  finalize_context : ClusteredReMincrossMultiRankFinalizeContext,
  reorder_inputs_output : (
    Map[String, Int],
    Array[String],
    Map[String, Int],
    Array[@cgraph.Edge],
    Array[String],
    Array[String],
    Array[Double],
    Array[Double],
    Array[Double],
    Array[Double],
  ),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (
    rem_node_order,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) = reorder_inputs_output
  run_clustered_remincross_multi_rank_finalize_phase(
    finalize_context.graph,
    finalize_context.edges,
    finalize_context.edge_tail,
    finalize_context.edge_head,
    finalize_context.order_with_vnodes,
    finalize_context.order_with_clusters,
    finalize_context.ranks,
    finalize_context.cluster_meta,
    finalize_context.vnode_info,
    finalize_context.order_sizes,
    finalize_context.rank_same_constraints,
    finalize_context.rem_rank_keys,
    finalize_context.rem_groups,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_node_order,
    finalize_context.real_nodes,
    finalize_context.nodesep_pt,
    finalize_context.has_edge_labels,
    finalize_context.port_order_positions,
    finalize_context.port_order_contrib,
    finalize_context.graphviz_flip,
  )
}


///|
/// Graphviz parity: clustered ReMincross multi-rank finalize dispatch reads
/// rematerialized reorder tuple then forwards values in Graphviz call order.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  reorder_inputs_output : (
    Map[String, Int],
    Array[String],
    Map[String, Int],
    Array[@cgraph.Edge],
    Array[String],
    Array[String],
    Array[Double],
    Array[Double],
    Array[Double],
    Array[Double],
  ),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let finalize_context : ClusteredReMincrossMultiRankFinalizeContext = {
    graph,
    edges,
    edge_tail,
    edge_head,
    order_with_vnodes,
    order_with_clusters,
    ranks,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  }
  run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output_with_context(
    finalize_context,
    reorder_inputs_output,
  )
}


///|
/// Graphviz parity: clustered ReMincross multi-rank dispatch context builder
/// preserves rematerialize/finalize argument ordering before phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_dispatch_context(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> ClusteredReMincrossMultiRankDispatchContext {
  {
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    order_with_vnodes,
    order_with_clusters,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    real_nodes,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  }
}


///|
/// Graphviz parity: clustered ReMincross multi-rank branch materializes
/// remapped edges and executes clustered cleanup reorder in startpass=2 flow.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank(
  dispatch_context : ClusteredReMincrossMultiRankDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_inputs_output =
    build_clustered_remincross_multi_rank_reorder_inputs_phase(
      dispatch_context.creation_order,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_tail_port_x,
      dispatch_context.edge_head_port_x,
      dispatch_context.edge_tail_port_order,
      dispatch_context.edge_head_port_order,
      dispatch_context.ranks,
      dispatch_context.order_with_vnodes,
      dispatch_context.order_with_clusters,
      dispatch_context.flat_rank_constraints,
      dispatch_context.edges_by_tail,
      dispatch_context.cluster_meta,
      dispatch_context.vnode_info,
      dispatch_context.rem_groups,
      dispatch_context.rem_rank_keys,
    )
  run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output(
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.order_with_vnodes,
    dispatch_context.order_with_clusters,
    dispatch_context.ranks,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    dispatch_context.rem_rank_keys,
    dispatch_context.rem_groups,
    dispatch_context.real_nodes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    dispatch_context.graphviz_flip,
    reorder_inputs_output,
  )
}

///|
/// Graphviz parity: clustered ReMincross multi-rank branch delegates to full
/// rematerialize+reorder flow and returns vnode/full + cleaned real groups.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_groups_multi_rank_branch(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let dispatch_context =
    build_clustered_remincross_multi_rank_dispatch_context(
      graph,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      order_with_vnodes,
      order_with_clusters,
      flat_rank_constraints,
      creation_order,
      edges_by_tail,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      rem_rank_keys,
      rem_groups,
      real_nodes,
      graphviz_flip,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
    )
  run_clustered_remincross_multi_rank(dispatch_context)
}

///|
/// Graphviz parity: clustered ReMincross keeps prior groups when rank count is
/// <= 1, otherwise executes full multi-rank rematerialize+reorder flow.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_groups_output(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  base_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  if rem_rank_keys.length() > 1 {
    run_clustered_remincross_groups_multi_rank_branch(
      graph,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      order_with_vnodes,
      order_with_clusters,
      flat_rank_constraints,
      creation_order,
      edges_by_tail,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      rem_rank_keys,
      rem_groups,
      real_nodes,
      graphviz_flip,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
    )
  } else {
    (ordered_with_vnodes, base_groups)
  }
}

///|
/// Graphviz parity: ReMincross can seed from current vnode-inclusive rank
/// order while keeping real-node relative order from cleaned base groups.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_from_ordered_with_vnodes(
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in ordered_with_vnodes {
    let filtered : Array[String] = []
    for name in names {
      if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
        filtered.push(name)
      }
    }
    if filtered.length() == 0 {
      continue
    }
    let base_real = match base_groups.get(rank) {
      Some(list) => list
      None => []
    }
    if base_real.length() == 0 {
      rem_groups[rank] = filtered
      continue
    }
    let real_order : Map[String, Int] = Map::new()
    for i in 0..<base_real.length() {
      real_order[base_real[i]] = i
    }
    let prev_real : Array[Int?] = []
    let mut last_real : Int? = None
    for name in filtered {
      match real_order.get(name) {
        Some(idx) => last_real = Some(idx)
        None => ()
      }
      prev_real.push(last_real)
    }
    let next_rev : Array[Int?] = []
    let mut next_real : Int? = None
    let mut rev_idx = filtered.length()
    while rev_idx > 0 {
      rev_idx = rev_idx - 1
      let name = filtered[rev_idx]
      match real_order.get(name) {
        Some(idx) => next_real = Some(idx)
        None => ()
      }
      next_rev.push(next_real)
    }
    let next_real_by_pos : Array[Int?] = []
    let mut idx = next_rev.length()
    while idx > 0 {
      idx = idx - 1
      next_real_by_pos.push(next_rev[idx])
    }
    let keyed : Array[(String, Int, Int)] = []
    for i in 0..<filtered.length() {
      let name = filtered[i]
      let key = match real_order.get(name) {
        Some(real_idx) => real_idx * 2
        None =>
          match prev_real[i] {
            Some(prev_idx) => prev_idx * 2 + 1
            None =>
              match next_real_by_pos[i] {
                Some(next_idx) => next_idx * 2 - 1
                None => i * 2
              }
          }
      }
      keyed.push((name, key, i))
    }
    keyed.sort_by((a, b) => {
      let (_, key_a, idx_a) = a
      let (_, key_b, idx_b) = b
      if key_a < key_b {
        -1
      } else if key_a > key_b {
        1
      } else if idx_a < idx_b {
        -1
      } else if idx_a > idx_b {
        1
      } else {
        0
      }
    })
    let ordered_rank : Array[String] = []
    for entry in keyed {
      let (name, _, _) = entry
      ordered_rank.push(name)
    }
    rem_groups[rank] = ordered_rank
  }
  rem_groups
}

///|
/// Graphviz parity: clustered ReMincross seeds rem_groups from current
/// vnode-inclusive order for single-cluster graphs; fallback rebuild keeps
/// existing multi-cluster behavior unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_groups(
  ordered_with_vnodes : Map[Int, Array[String]],
  base_groups : Map[Int, Array[String]],
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> Map[Int, Array[String]] {
  if order_with_vnodes && cluster_meta.cluster_order.length() == 1 {
    let seeded =
      build_remincross_groups_from_ordered_with_vnodes(
        base_groups,
        ordered_with_vnodes,
      )
    if seeded.length() > 0 {
      dot_trace_groups("remincross_groups", seeded)
      return seeded
    }
  }
  let rem_groups =
    build_remincross_groups_with_optional_vnodes(
      base_groups,
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
      vnode_info.vnodes_by_rank,
    )
  dot_trace_groups("remincross_groups", rem_groups)
  rem_groups
}

///|
/// Graphviz parity: clustered ReMincross pass dispatch context keeps
/// rematerialize+cleanup inputs in Graphviz argument ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_dispatch_context(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  base_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> ClusteredReMincrossPassDispatchContext {
  {
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    order_with_vnodes,
    order_with_clusters,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    ordered_with_vnodes,
    base_groups,
    real_nodes,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  }
}


///|
/// Graphviz parity: clustered ReMincross pass derives rem_rank_keys from
/// vnode-augmented rem_groups before rank-count branch and cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_groups_output_from_rem_groups(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
  rem_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_rank_keys = collect_rank_keys(rem_groups)
  build_clustered_remincross_groups_output(
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_tail_port_x,
    dispatch_context.edge_head_port_x,
    dispatch_context.edge_tail_port_order,
    dispatch_context.edge_head_port_order,
    dispatch_context.ranks,
    dispatch_context.order_with_vnodes,
    dispatch_context.order_with_clusters,
    dispatch_context.flat_rank_constraints,
    dispatch_context.creation_order,
    dispatch_context.edges_by_tail,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    dispatch_context.ordered_with_vnodes,
    dispatch_context.base_groups,
    dispatch_context.real_nodes,
    dispatch_context.graphviz_flip,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
  )
}


///|
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_pass(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_groups =
    build_clustered_remincross_pass_groups(
      dispatch_context.ordered_with_vnodes,
      dispatch_context.base_groups,
      dispatch_context.order_with_vnodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_reversed,
      dispatch_context.ranks,
      dispatch_context.cluster_meta,
      dispatch_context.vnode_info,
    )
  let (next_ordered_with_vnodes, next_final_groups) =
    build_clustered_remincross_pass_groups_output_from_rem_groups(
      dispatch_context,
      rem_groups,
    )
  build_clustered_remincross_pass_output(next_ordered_with_vnodes, next_final_groups)
}

///|
/// Graphviz parity: non-cluster reorder output keeps reordered rank groups from
/// the Graphviz-style single-pass mincross call unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_reorder_pass_output(
  ordered_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  ordered_groups
}

///|
/// Graphviz parity: non-cluster reorder seeds build_ranks node order from
/// GD_nlist, then falls back to existing node order for missing nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_order_node_order(
  nlist_order : Array[String],
  node_order : Map[String, Int],
) -> Map[String, Int] {
  let order_node_order : Map[String, Int] = Map::new()
  let mut order_idx = 0
  for name in nlist_order {
    order_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  for name, idx in node_order {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  order_node_order
}

///|
/// Graphviz parity: non-cluster ND_in neighbor entries preserve AGSEQ edge
/// traversal order while resolving tail/head from materialized arrays.
/// Do not change behavior without updating fixtures/tests.
fn collect_noncluster_in_neighbor_entries(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Array[String]] {
  let in_entries : Map[String, Array[String]] = Map::new()
  let mut edge_idx = 0
  while edge_idx < edges.length() {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edges[edge_idx].tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edges[edge_idx].head().name()
      }
    match in_entries.get(head) {
      Some(list) => list.push(tail)
      None => in_entries[head] = [tail]
    }
    edge_idx = edge_idx + 1
  }
  in_entries
}


///|
/// Graphviz parity: non-cluster neighbor maps preserve ND_out tail order from
/// edge_out_order and ND_in head order from edge sequence (AGSEQ).
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_graphviz_neighbor_maps(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for i in 0..<nodes.length() {
    let name = nodes[i].name()
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  for name, list in edge_out_order {
    let heads : Array[String] = []
    for edge_idx in list {
      let head =
        if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
          edges[edge_idx].head().name()
        }
      heads.push(head)
    }
    graphviz_out_neighbors[name] = heads
  }
  let in_entries =
    collect_noncluster_in_neighbor_entries(edges, edge_tail, edge_head)
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
  (graphviz_out_neighbors, graphviz_in_neighbors)
}

///|
/// Graphviz parity: non-cluster reorder edge indices follow build_ranks input
/// maps built from order-edge arrays and rank map before rank permutation.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_edge_indices_for_reorder(
  nodes : Array[@cgraph.Node],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  ranks : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]]) {
  build_edge_index_for_order(
    nodes,
    order_edges,
    order_edge_tail,
    order_edge_head,
    ranks,
  )
}

///|
/// Graphviz parity: per-component neighbor filtering preserves the local ND_out
/// / ND_in order used when mincross runs each connected component separately.
/// Do not change behavior without updating fixtures/tests.
fn filter_noncluster_neighbor_map_for_component(
  component_nodes : Array[String],
  component_set : Map[String, Bool],
  neighbors : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let filtered : Map[String, Array[String]] = Map::new()
  for name in component_nodes {
    let values = match neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let keep : Array[String] = []
    for other in values {
      if component_set.get(other) is Some(_) {
        keep.push(other)
      }
    }
    filtered[name] = keep
  }
  filtered
}

///|
/// Graphviz parity: component-local flat constraints are forwarded to mincross
/// only when both endpoints belong to the current connected component.
/// Do not change behavior without updating fixtures/tests.
fn filter_noncluster_flat_constraints_for_component(
  flat_constraints : Map[String, Bool],
  component_set : Map[String, Bool],
) -> Map[String, Bool] {
  let filtered : Map[String, Bool] = Map::new()
  for key, enabled in flat_constraints {
    if !enabled {
      continue
    }
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        if tail == "" || head == "" {
          continue
        }
        if component_set.get(tail) is Some(_) && component_set.get(head) is Some(_) {
          filtered[key] = true
        }
      }
      None => ()
    }
  }
  filtered
}

///|
/// Graphviz parity: component reorder keeps each rank's relative extraction order
/// from the full group list before running mincross on that component.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_reorder_component_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  component_set : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let component_groups : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let keep : Array[String] = []
    for name in names {
      if component_set.get(name) is Some(_) {
        keep.push(name)
      }
    }
    if keep.length() > 0 {
      component_groups[rank] = keep
    }
  }
  component_groups
}

///|
/// Graphviz parity: non-cluster mincross traverses connected components in
/// GD_nlist order (real nodes first), then runs mincross on each component.
/// Do not change behavior without updating fixtures/tests.
fn collect_noncluster_reorder_components(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  order_node_order : Map[String, Int],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  flat_constraints : Map[String, Bool],
) -> Array[Array[String]] {
  let order_nodes = build_order_nodes_from_groups(groups, rank_keys)
  if order_nodes.length() == 0 {
    return []
  }
  let node_set = build_node_membership_set(order_nodes)
  let fallback_order : Map[String, Int] = Map::new()
  for i, name in order_nodes {
    fallback_order[name] = i
  }
  let start_nodes = order_nodes.copy()
  if start_nodes.length() > 1 {
    start_nodes.sort_by((a, b) => {
      let a_idx = match order_node_order.get(a) {
        Some(value) => value
        None =>
          match fallback_order.get(a) {
            Some(value) => value
            None => 0
          }
      }
      let b_idx = match order_node_order.get(b) {
        Some(value) => value
        None =>
          match fallback_order.get(b) {
            Some(value) => value
            None => 0
          }
      }
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
  }
  let preferred_start_nodes : Array[String] = []
  for name in start_nodes {
    if !name.has_prefix(EDGE_VNODE_PREFIX) {
      preferred_start_nodes.push(name)
    }
  }
  let traversal_starts =
    if preferred_start_nodes.length() > 0 { preferred_start_nodes } else { start_nodes }

  let out_neighbors : Map[String, Array[String]] = Map::new()
  let in_neighbors : Map[String, Array[String]] = Map::new()
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    let out_list = match graphviz_out_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let out_keep : Array[String] = []
    for other in out_list {
      if node_set.get(other) is Some(_) {
        out_keep.push(other)
      }
    }
    out_neighbors[name] = out_keep

    let in_list = match graphviz_in_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    let in_keep : Array[String] = []
    for other in in_list {
      if node_set.get(other) is Some(_) {
        in_keep.push(other)
      }
    }
    in_neighbors[name] = in_keep
    flat_out[name] = []
    flat_in[name] = []
  }
  for key, enabled in flat_constraints {
    if !enabled {
      continue
    }
    match key.find("|") {
      Some(pos) => {
        let len = key.length()
        let tail = if pos > 0 { key.unsafe_substring(start=0, end=pos) } else { "" }
        let head =
          if pos + 1 < len { key.unsafe_substring(start=pos + 1, end=len) } else {
            ""
          }
        if tail == "" || head == "" {
          continue
        }
        if node_set.get(tail) is None || node_set.get(head) is None {
          continue
        }
        match flat_out.get(tail) {
          Some(list) => list.push(head)
          None => flat_out[tail] = [head]
        }
        match flat_in.get(head) {
          Some(list) => list.push(tail)
          None => flat_in[head] = [tail]
        }
      }
      None => ()
    }
  }

  let visited : Map[String, Bool] = Map::new()
  for name in order_nodes {
    visited[name] = false
  }
  let components : Array[Array[String]] = []
  let stack : Array[String] = []
  let push_neighbors = (list : Array[String]) => {
    let mut idx = list.length()
    while idx > 0 {
      idx = idx - 1
      let other = list[idx]
      if node_set.get(other) is None {
        continue
      }
      if visited.get(other) != Some(true) {
        stack.push(other)
      }
    }
  }
  let visit_start = (start : String) => {
    if visited.get(start) == Some(true) {
      ()
    } else {
      let component : Array[String] = []
      stack.push(start)
      while stack.length() > 0 {
        let current = stack[stack.length() - 1]
        let _ = stack.pop()
        if visited.get(current) == Some(true) {
          continue
        }
        visited[current] = true
        component.push(current)
        let fin = match flat_in.get(current) {
          Some(list) => list
          None => []
        }
        let fout = match flat_out.get(current) {
          Some(list) => list
          None => []
        }
        let inn = match in_neighbors.get(current) {
          Some(list) => list
          None => []
        }
        let out = match out_neighbors.get(current) {
          Some(list) => list
          None => []
        }
        push_neighbors(fin)
        push_neighbors(fout)
        push_neighbors(inn)
        push_neighbors(out)
      }
      if component.length() > 0 {
        components.push(component)
      }
    }
  }
  for start in traversal_starts {
    visit_start(start)
  }
  for start in start_nodes {
    visit_start(start)
  }
  components
}

///|
/// Graphviz parity: non-cluster rank reorder runs build_ranks permutation using
/// Graphviz ND_out/ND_in neighbor ordering and current edge/materialized maps.
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_graphviz_rank_reorder(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    rank_keys,
    groups,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    parents,
    children,
    cluster_meta.cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    edge_order,
    order_node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    cluster_meta.cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
    graphviz_flip=graphviz_flip,
  )
}

///|
/// Graphviz parity: non-cluster reorder path seeds node order from GD_nlist,
/// builds Graphviz-style ND_out/ND_in neighbor order, and runs rank reorder
/// without cluster remapping.
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_reorder_pass(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let order_node_order =
    build_noncluster_order_node_order(nlist_order, node_order)
  let (parents, children) =
    build_noncluster_edge_indices_for_reorder(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      ranks,
    )
  let (graphviz_out_neighbors, graphviz_in_neighbors) =
    build_noncluster_graphviz_neighbor_maps(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
    )
  let ordered_groups =
    run_noncluster_graphviz_rank_reorder(
      rank_keys,
      groups,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      parents,
      children,
      cluster_meta,
      edge_order,
      order_node_order,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      graphviz_flip,
    )
  build_noncluster_reorder_pass_output(ordered_groups)
}

///|
/// Debug trace: dump GD_nlist sequence and skeleton-node subset when
/// DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_nlist_order_debug(
  nlist_order : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let order_joined = nlist_order.join(" ")
  if order_joined.length() > 0 {
    println("nlist_order \{order_joined}")
  }
  let skeleton_names =
    nlist_order.filter(name => name.has_prefix(CLUSTER_SKELETON_PREFIX))
  let joined = skeleton_names.join(" ")
  if joined.length() > 0 {
    println("nlist_skeleton \{joined}")
  }
}

///|
/// Debug trace: dump selected order-node positions when DOT_TRACE_GROUPS is
/// enabled (diagnostic only).
fn trace_order_node_order_debug(
  order_node_order : Map[String, Int],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let debug_names : Array[String] = [
    "z_req",
    "z_req1",
    "handle_x",
    "handle_1",
    "mobvm_a_req",
    "mobvm_a_req1",
    "front_end_jz",
    "other_xprot",
    "z_shapeshifter",
  ]
  for name in debug_names {
    match order_node_order.get(name) {
      Some(value) => println("order_node_order \{name}=\{value}")
      None => ()
    }
  }
}

///|
/// Debug trace: dump materialized order edges with rank/real-node flags when
/// DOT_TRACE_ORDER_EDGES is enabled (diagnostic only).
fn trace_order_edges_with_ranks(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  real_nodes : Map[String, Bool],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_ORDER_EDGES") is None {
    return
  }
  let mut edge_idx = 0
  for _edge in order_edges_out {
    let tail = order_edge_tail_out[edge_idx]
    let head = order_edge_head_out[edge_idx]
    let tail_rank = match order_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match order_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    let tail_real = real_nodes.get(tail) is Some(_)
    let head_real = real_nodes.get(head) is Some(_)
    println(
      "order_edge \{edge_idx}: \{tail}(\{tail_rank},\{tail_real}) -> \{head}(\{head_rank},\{head_real})",
    )
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: mapped/unmapped order-edge materialization output keeps
/// both edge-array bundles and sampled port arrays unchanged.
/// Do not change behavior without updating fixtures/tests.
fn materialize_mapped_and_unmapped_order_edges_output(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
}

///|
/// Graphviz parity: mapped order-edge arrays are materialized from GD_nlist
/// tail order against the cluster-remapped order graph.
/// Do not change behavior without updating fixtures/tests.
fn materialize_mapped_order_edges_for_tail_sequence(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  append_order_edges_for_tail_sequence(
    nlist_order,
    order_edges_by_tail,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
  (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}


///|
/// Graphviz parity: unmapped order-edge arrays are materialized from GD_nlist
/// tail order against the non-remapped order graph.
/// Do not change behavior without updating fixtures/tests.
fn materialize_unmapped_order_edges_for_tail_sequence(
  nlist_order : Array[String],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let order_edges_out_unmapped : Array[@cgraph.Edge] = []
  let order_edge_tail_out_unmapped : Array[String] = []
  let order_edge_head_out_unmapped : Array[String] = []
  let order_edge_tail_port_x_unmapped : Array[Double] = []
  let order_edge_head_port_x_unmapped : Array[Double] = []
  let order_edge_tail_port_order_unmapped : Array[Double] = []
  let order_edge_head_port_order_unmapped : Array[Double] = []
  append_order_edges_for_tail_sequence(
    nlist_order,
    order_edges_by_tail_unmapped,
    order_graph_unmapped,
    order_node_map_unmapped,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
  (
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
}


///|
/// Graphviz parity: order-graph edge arrays are materialized from GD_nlist
/// tail order for both mapped (cluster-remapped) and unmapped variants.
/// Do not change behavior without updating fixtures/tests.
fn materialize_mapped_and_unmapped_order_edges(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  ) =
    materialize_mapped_order_edges_for_tail_sequence(
      nlist_order,
      order_edges_by_tail,
      order_graph,
      order_node_map,
    )
  let (
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  ) =
    materialize_unmapped_order_edges_for_tail_sequence(
      nlist_order,
      order_edges_by_tail_unmapped,
      order_graph_unmapped,
      order_node_map_unmapped,
    )
  materialize_mapped_and_unmapped_order_edges_output(
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
}

///|
/// Graphviz parity: order-stage group/sizes output preserves order groups,
/// order sizes, cluster keys, and skeleton flags without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_order_groups_sizes_and_cluster_skeleton_output(
  order_groups : Map[Int, Array[String]],
  order_sizes_out : Map[String, NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> (
  Map[Int, Array[String]],
  Map[String, NodeSize],
  Map[String, String],
  Map[String, Bool],
) {
  (
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: cluster skeleton nodes are installed by cluster_order
/// first, then by cluster_min_rank fallback, using virtual_node() defaults.
/// Do not change behavior without updating fixtures/tests.
fn install_order_cluster_skeleton_nodes(
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  order_groups : Map[Int, Array[String]],
) -> Unit {
  if !order_with_clusters {
    return
  }
  // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
  let skeleton_size = vnode_size_from_widths(1.0, 1.0)
  let cluster_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_meta.cluster_order {
    match cluster_meta.cluster_min_rank.get(cluster) {
      Some(min_rank) => {
        let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
          Some(value) => value
          None => min_rank
        }
        append_order_cluster_skeleton_range(
          cluster,
          min_rank,
          max_rank,
          order_cluster_keys,
          order_cluster_skeleton,
          order_sizes_out,
          order_groups,
          skeleton_size,
        )
        cluster_seen[cluster] = true
      }
      None => ()
    }
  }
  for cluster, min_rank in cluster_meta.cluster_min_rank {
    if cluster_seen.get(cluster) is Some(_) {
      continue
    }
    let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    append_order_cluster_skeleton_range(
      cluster,
      min_rank,
      max_rank,
      order_cluster_keys,
      order_cluster_skeleton,
      order_sizes_out,
      order_groups,
      skeleton_size,
    )
  }
}


///|
/// Graphviz parity: order-stage groups clone rank groups, optionally merge edge
/// vnodes, and install cluster skeleton nodes with virtual-node defaults.
/// Do not change behavior without updating fixtures/tests.
fn build_order_groups_sizes_and_cluster_skeleton(
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_sizes : Map[String, NodeSize],
) -> (
  Map[Int, Array[String]],
  Map[String, NodeSize],
  Map[String, String],
  Map[String, Bool],
) {
  let order_groups =
    if order_with_vnodes {
      build_x_groups_with_vnodes(
        ordering_groups_base,
        base_order_index,
        vnode_info.vnodes_by_rank,
        vnode_order_keys_for_ordering,
      )
    } else {
      let out : Map[Int, Array[String]] = Map::new()
      for rank, names in ordering_groups_base {
        out[rank] = names.copy()
      }
      out
    }
  let order_sizes_out =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
    )
  let order_cluster_keys =
    build_order_cluster_keys_for_order_graph(
      cluster_meta.cluster_keys,
      order_with_vnodes,
      vnode_info.vnode_clusters,
    )
  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  install_order_cluster_skeleton_nodes(
    order_with_clusters,
    cluster_meta,
    order_cluster_keys,
    order_cluster_skeleton,
    order_sizes_out,
    order_groups,
  )
  build_order_groups_sizes_and_cluster_skeleton_output(
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: unconstrained real nodes keep GD_nlist seed order, with
/// incoming-only local-cluster nodes reversed to match fast_node head-insert
/// behavior before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn apply_unconstrained_order_node_overrides(
  gdnlist_order : Array[String],
  real_nodes : Map[String, Bool],
  order_nodes : Array[String],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  rank_same_groups : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
  intercluster_keys : Map[String, String],
  order_node_order : Map[String, Int],
) -> Unit {
  // Graphviz parity: unconstrained nodes retain GD_nlist order for seeding.
  let gdnlist_order_index =
    build_gdnlist_order_index_for_real_nodes(gdnlist_order, real_nodes)
  let unconstrained_nodes =
    collect_unconstrained_order_nodes(
      order_nodes,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
    )
  for name, idx in gdnlist_order_index {
    if real_nodes.get(name) is Some(_) &&
      unconstrained_nodes.get(name) is Some(_) &&
      rank_same_groups.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: incoming-only unconstrained nodes inside local
  // clusters follow reverse input order (fast_node inserts at head).
  let (node_has_out, node_has_in) =
    build_node_in_out_presence_maps(edge_tail, edge_head)
  let local_creation =
    build_local_cluster_creation_order(nodes, intercluster_keys)
  reorder_incoming_only_unconstrained_local_nodes(
    local_creation,
    unconstrained_nodes,
    rank_same_groups,
    node_has_out,
    node_has_in,
    order_node_order,
  )
}

///|
/// Graphviz parity: seeded build_ranks transpose phase runs only when crossing
/// count remains positive after component-scoped initial ordering.
/// Do not change behavior without updating fixtures/tests.
fn apply_seeded_groups_transpose_phase(
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  flat_rank_constraints : Map[String, Bool],
) -> Unit {
  // Graphviz parity: build_ranks applies transpose if crossings remain;
  // crossing count uses endpoint port x offsets for tie-correct ordering.
  let seed_cross = count_crossings_graphviz(
    seeded_groups,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    edge_tail_port_x=order_edge_tail_port_x,
    edge_head_port_x=order_edge_head_port_x,
  )
  if seed_cross > 0 {
    let (edge_penalty, edge_in, edge_out) =
      build_transpose_seed_edge_maps(
        order_rank_keys,
        seeded_groups,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_ranks,
      )
    let _ = transpose_rank_groups_graphviz(
      order_rank_keys,
      seeded_groups,
      order_ranks,
      edge_in,
      edge_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      edge_penalty,
      order_cluster_keys,
      order_cluster_skeleton,
      flat_rank_constraints,
      false,
      0,
    )
  }
}

///|
/// Graphviz parity: build_ranks seeding runs component-scoped ordering first,
/// then applies transpose when crossings remain (port-offset aware tie-breaks).
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_groups_for_order_reorder(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  // Graphviz parity: seed build_ranks from component-scoped walk,
  // matching decompose/install traversal used by remincross with
  // cluster-expanded flat constraints.
  let seeded_groups = build_rank_groups_graphviz_components(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    0,
    order_flat_constraints,
    flip=graphviz_flip,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
  )
  apply_seeded_groups_transpose_phase(
    order_rank_keys,
    seeded_groups,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_cluster_keys,
    order_cluster_skeleton,
    flat_rank_constraints,
  )
  dot_trace_groups("seeded_groups", seeded_groups)
  seeded_groups
}

///|
/// Graphviz parity: clustered order pass runs cluster-local build_ranks on the
/// unmapped order graph, then stores vnode-inclusive rank groups for later xpos.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_build_ranks_and_track_vnodes(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if order_with_clusters {
    reorder_groups_by_cluster_build_ranks(
      graph,
      ordered,
      cluster_meta,
      order_node_order,
      order_edges_out_unmapped,
      order_edge_tail_out_unmapped,
      order_edge_head_out_unmapped,
      order_edge_tail_port_x_unmapped,
      order_edge_head_port_x_unmapped,
      order_edge_tail_port_order_unmapped,
      order_edge_head_port_order_unmapped,
      ranks,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      vnode_info,
      graphviz_flip,
      order_with_vnodes,
    )
  }
  let mut next_ordered_with_vnodes = ordered_with_vnodes
  if order_with_vnodes {
    next_ordered_with_vnodes = ordered
  }
  next_ordered_with_vnodes
}

///|
/// Graphviz parity: cluster skeleton edge chains are appended by cluster_order
/// first, then remaining cluster_min_rank keys, matching Graphviz ordering.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_edges_for_order_graph(
  cluster_order : Array[String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
) -> Unit {
  let cluster_seen : Map[String, Bool] = Map::new()
  for cluster in cluster_order {
    match cluster_min_rank.get(cluster) {
      Some(min_rank) => {
        let max_rank = match cluster_max_rank.get(cluster) {
          Some(value) => value
          None => min_rank
        }
        append_cluster_skeleton_edges(
          cluster,
          min_rank,
          max_rank,
          order_edges_by_tail,
          order_edges_by_tail_root,
          skeleton_edge_creation,
        )
        cluster_seen[cluster] = true
      }
      None => ()
    }
  }
  for cluster, min_rank in cluster_min_rank {
    if cluster_seen.get(cluster) is Some(_) {
      continue
    }
    let max_rank = match cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    append_cluster_skeleton_edges(
      cluster,
      min_rank,
      max_rank,
      order_edges_by_tail,
      order_edges_by_tail_root,
      skeleton_edge_creation,
    )
  }
}


///|
/// Graphviz parity: cluster skeleton edge chains are emitted in Graphviz
/// cluster-order sequence first, then for any remaining cluster-min-rank keys.
/// Do not change behavior without updating fixtures/tests.
fn build_skeleton_edge_creation_for_order_graph(
  order_with_clusters : Bool,
  cluster_order : Array[String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Array[(String, String)] {
  let skeleton_edge_creation : Array[(String, String)] = []
  if !order_with_clusters {
    return skeleton_edge_creation
  }
  append_cluster_skeleton_edges_for_order_graph(
    cluster_order,
    cluster_min_rank,
    cluster_max_rank,
    order_edges_by_tail,
    order_edges_by_tail_root,
    skeleton_edge_creation,
  )
  skeleton_edge_creation
}

///|
/// Graphviz parity: final cleanup output preserves vnode-augmented groups and
/// finalized real-node groups in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_order_groups_with_cluster_remincross_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (next_ordered_with_vnodes, final_groups)
}

///|
/// Graphviz parity: cluster-rank reorder is skipped when root reorder exposes
/// a single-cluster single-anchor shape (one cluster bucket globally and at
/// most one clustered node per rank), so cluster-local ordering remains
/// anchored at the root-skeleton expansion position.
/// Do not change behavior without updating fixtures/tests.
fn has_single_cluster_rank_order_bucket(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
) -> Bool {
  let seen_clusters : Map[String, Bool] = Map::new()
  for _rank, order_map in cluster_rank_order {
    for cluster, _order in order_map {
      if cluster == "" {
        continue
      }
      seen_clusters[cluster] = true
      if seen_clusters.length() > 1 {
        return false
      }
    }
  }
  if seen_clusters.length() != 1 {
    return false
  }
  for _rank, names in final_groups {
    let mut cluster_nodes = 0
    for name in names {
      if cluster_key_or_empty(cluster_keys, name) != "" {
        cluster_nodes = cluster_nodes + 1
        if cluster_nodes > 1 {
          return false
        }
      }
    }
  }
  true
}

///|
/// Graphviz parity: cluster-enabled final groups apply cluster-rank ordering
/// then local-cluster bucket ordering before clustered ReMincross refinement.
/// Do not change behavior without updating fixtures/tests.
fn reorder_final_groups_for_cluster_remincross(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
  intercluster_keys : Map[String, String],
  local_cluster_order : Map[String, Int],
) -> Map[Int, Array[String]] {
  let reordered =
    if has_single_cluster_rank_order_bucket(
      final_groups,
      cluster_rank_order,
      cluster_keys,
    ) {
      final_groups
    } else {
      reorder_rank_groups_by_cluster_rank_order(
        final_groups,
        cluster_rank_order,
        cluster_keys,
      )
    }
  // Graphviz parity: order local subclusters within outer clusters by minrank/first order.
  reorder_groups_by_local_cluster_order(
    reordered,
    cluster_keys,
    intercluster_keys,
    local_cluster_order,
  )
  dot_trace_groups("cleaned_groups_post", reordered)
  reordered
}


///|
/// Graphviz parity: cluster-enabled finalize phase forwards cleaned groups
/// into clustered ReMincross refinement with Graphviz argument ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_finalize_order_groups_cluster_remincross_phase(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  final_groups : Map[Int, Array[String]],
  next_ordered_with_vnodes : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let dispatch_context =
    build_clustered_remincross_pass_dispatch_context(
      graph,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      order_with_vnodes,
      order_with_clusters,
      flat_rank_constraints,
      creation_order,
      edges_by_tail,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      next_ordered_with_vnodes,
      final_groups,
      real_nodes,
      graphviz_flip,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
    )
  run_clustered_remincross_pass(dispatch_context)
}


///|
/// Graphviz parity: cluster-enabled final cleanup phase applies cluster/local
/// ordering then forwards into clustered ReMincross refinement unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_finalize_order_groups_cluster_enabled_phase(
  dispatch_context : FinalizeOrderGroupsDispatchContext,
  cleaned_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let final_groups =
    reorder_final_groups_for_cluster_remincross(
      cleaned_groups,
      dispatch_context.cluster_rank_order,
      dispatch_context.cluster_meta.cluster_keys,
      dispatch_context.cluster_meta.intercluster_keys,
      dispatch_context.local_cluster_order,
    )
  run_finalize_order_groups_cluster_remincross_phase(
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_reversed,
    dispatch_context.edge_tail_port_x,
    dispatch_context.edge_head_port_x,
    dispatch_context.edge_tail_port_order,
    dispatch_context.edge_head_port_order,
    dispatch_context.ranks,
    dispatch_context.order_with_vnodes,
    true,
    dispatch_context.flat_rank_constraints,
    dispatch_context.creation_order,
    dispatch_context.edges_by_tail,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    final_groups,
    dispatch_context.ordered_with_vnodes,
    dispatch_context.real_nodes,
    dispatch_context.graphviz_flip,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
  )
}


///|
/// Graphviz parity: final cleanup pre-phase keeps only real nodes from ordered
/// groups before cluster/local reorder and clustered ReMincross refinement.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_order_groups_cleaned_groups_phase(
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let cleaned_groups =
    collect_real_only_rank_groups(order_rank_keys, ordered, real_nodes)
  dot_trace_groups("cleaned_groups_pre", cleaned_groups)
  cleaned_groups
}



///|
/// Graphviz parity: final cleanup dispatch phase keeps cluster-enabled and
/// non-clustered branches in Graphviz-equivalent control-flow ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_finalize_order_groups_dispatch_phase(
  dispatch_context : FinalizeOrderGroupsDispatchContext,
  cleaned_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  if dispatch_context.order_with_clusters {
    run_finalize_order_groups_cluster_enabled_phase(
      dispatch_context,
      cleaned_groups,
    )
  } else {
    (dispatch_context.ordered_with_vnodes, cleaned_groups)
  }
}

///|
/// Graphviz parity: final group cleanup context builder preserves clustered
/// cleanup payload ordering before branch dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_finalize_order_groups_dispatch_context(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> FinalizeOrderGroupsDispatchContext {
  {
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order,
    cluster_meta,
    local_cluster_order,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    real_nodes,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  }
}


///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
fn finalize_order_groups_with_cluster_remincross(
  dispatch_context : FinalizeOrderGroupsDispatchContext,
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let cleaned_groups =
    build_finalize_order_groups_cleaned_groups_phase(
      order_rank_keys,
      ordered,
      dispatch_context.real_nodes,
    )
  let (next_ordered_with_vnodes, final_groups) =
    run_finalize_order_groups_dispatch_phase(
      dispatch_context,
      cleaned_groups,
    )
  build_finalize_order_groups_with_cluster_remincross_output(
    next_ordered_with_vnodes,
    final_groups,
  )
}

///|
/// Graphviz parity: class2 nlist/vnode output keeps GD_nlist order and vnode
/// creation sequence unchanged after cluster-flip adjustment.
/// Do not change behavior without updating fixtures/tests.
fn build_nlist_order_and_vnode_creation_order_output(
  nlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> (Array[String], Array[String]) {
  (nlist_order, vnode_creation_order)
}

///|
/// Graphviz parity: class2 creation and decompose build GD_nlist from cluster
/// skeletons + real-node/vnode creation order, with cluster-flip adjustment.
/// Do not change behavior without updating fixtures/tests.
fn build_nlist_order_and_vnode_creation_order(
  cluster_skeleton_creation : Array[String],
  creation_order : Array[String],
  vnode_creation_by_tail : Map[String, Array[String]],
  edge_creation_order : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  has_clusters : Bool,
  cluster_keys : Map[String, String],
) -> (Array[String], Array[String]) {
  // Graphviz parity: class2 creates cluster skeletons first, then interleaves
  // real nodes with their edge vnodes in agfstnode order.
  let (order_creation, vnode_creation_order) =
    build_order_creation_with_vnodes(
      cluster_skeleton_creation,
      creation_order,
      vnode_creation_by_tail,
    )
  // Graphviz parity: decompose DFS starts from agfstnode (creation) order
  // regardless of rankdir flip.
  // Do not change behavior without updating fixtures/tests.
  let nlist_tail_order : Array[String] = creation_order
  let nlist_order_raw =
    build_graphviz_nlist_order_from_edges(
      nlist_tail_order,
      order_creation,
      edge_creation_order,
      flat_rank_constraints,
    )
  let nlist_order =
    adjust_nlist_order_for_cluster_flip(
      nlist_order_raw,
      graphviz_flip,
      has_clusters,
      cluster_keys,
    )
  trace_nlist_order_debug(nlist_order)
  build_nlist_order_and_vnode_creation_order_output(nlist_order, vnode_creation_order)
}

///|
/// Graphviz parity: root ReMincross output preserves root ordering groups and
/// merged ordered groups for downstream cluster build_ranks stages.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_reorder_output(
  order_groups_for_mincross : Map[Int, Array[String]],
  ordered : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (order_groups_for_mincross, ordered)
}

///|
/// Graphviz parity: root ReMincross preferred positions use vnode ordering
/// keys only when vnode ordering is enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_preferred_positions(
  order_with_vnodes : Bool,
  vnode_order_keys_for_ordering : Map[String, Double],
) -> Map[String, Double] {
  if !order_with_vnodes {
    return Map::new()
  }
  let filtered : Map[String, Double] = Map::new()
  for name, value in vnode_order_keys_for_ordering {
    if name.has_prefix(EDGE_VNODE_PREFIX) {
      filtered[name] = value
    }
  }
  filtered
}

///|
/// Graphviz parity: root ReMincross final ordered groups merge reordered root
/// nodes back into seeded groups only in clustered mode.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_final_ordered_groups(
  order_with_clusters : Bool,
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
) -> Map[Int, Array[String]] {
  if order_with_clusters {
    merge_root_mincross_order_into_seeded_groups(
      order_rank_keys,
      seeded_groups,
      ordered_mincross,
      mincross_nodes,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  } else {
    ordered_mincross
  }
}

///|
/// Graphviz parity: root ReMincross traverses seeded groups by collected
/// rank keys to build the exact order-node sequence used for edge filtering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_rank_keys_and_nodes(
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (Array[Int], Array[String]) {
  let order_rank_keys_for_mincross = collect_rank_keys(order_groups_for_mincross)
  let order_nodes_for_mincross =
    build_order_nodes_from_groups(
      order_groups_for_mincross,
      order_rank_keys_for_mincross,
    )
  (order_rank_keys_for_mincross, order_nodes_for_mincross)
}

///|
/// Graphviz parity: root ReMincross builds rank-key/node flattening and
/// membership map from seeded root/skeleton groups before edge filtering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_node_membership_inputs(
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (Array[Int], Array[String], Map[String, Bool]) {
  let (order_rank_keys_for_mincross, order_nodes_for_mincross) =
    build_root_mincross_rank_keys_and_nodes(order_groups_for_mincross)
  let mincross_nodes = build_node_membership_set(order_nodes_for_mincross)
  (order_rank_keys_for_mincross, order_nodes_for_mincross, mincross_nodes)
}

///|
/// Graphviz parity: root ReMincross filters order edges to root/skeleton
/// membership before mincross reorder, preserving sampled port metadata.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_order_edges(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  collect_mincross_order_edges(
    mincross_nodes,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}

///|
/// Graphviz parity: root ReMincross builds parent/child adjacency and edge
/// ordering from filtered root/skeleton edges before reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_edge_indices_and_order(
  order_nodes_for_mincross : Array[String],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_ranks : Map[String, Int],
  order_edges_out_mincross : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  build_order_edge_indices_and_order(
    order_nodes_for_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_ranks,
    order_edges_out_mincross,
  )
}

///|
/// Graphviz parity: root ReMincross materializes filtered root/skeleton edges
/// and builds parent/child + edge-order indices before reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_edges_and_indices(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_nodes_for_mincross : Array[String],
  order_ranks : Map[String, Int],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
) {
  let (
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
  ) =
    build_root_mincross_order_edges(
      mincross_nodes,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
    )
  let (parents, children, edge_order) =
    build_root_mincross_edge_indices_and_order(
      order_nodes_for_mincross,
      order_edge_tail_out_mincross,
      order_edge_head_out_mincross,
      order_ranks,
      order_edges_out_mincross,
    )
  (
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    edge_order,
  )
}


///|
/// Graphviz parity: root ReMincross debug trace prints selected ND_in/ND_out
/// neighbor lists only when DOT_TRACE_GROUPS is enabled.
/// Do not change behavior without updating fixtures/tests.
fn trace_root_mincross_graphviz_neighbors(
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_out_neighbors : Map[String, Array[String]],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_nodes : Array[String] = ["front_end_jz", "z_req1", "z_req"]
    for name in debug_nodes {
      let inn = match graphviz_in_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      let out = match graphviz_out_neighbors.get(name) {
        Some(list) => list
        None => []
      }
      println("order_neighbors \{name} in=\{inn} out=\{out}")
    }
  }
}

///|
/// Graphviz parity: component-local node-position hints are passed to mincross
/// only for nodes belonging to the active connected component.
/// Do not change behavior without updating fixtures/tests.
fn filter_node_double_map_for_component(
  component_set : Map[String, Bool],
  values : Map[String, Double],
) -> Map[String, Double] {
  let filtered : Map[String, Double] = Map::new()
  for name, value in values {
    if component_set.get(name) is Some(_) {
      filtered[name] = value
    }
  }
  filtered
}

///|
/// Graphviz parity: component-local port-order contributor lists drop endpoints
/// outside the active connected component before mincross.
/// Do not change behavior without updating fixtures/tests.
fn filter_node_contrib_map_for_component(
  component_set : Map[String, Bool],
  values : Map[String, Array[(String, Double)]],
) -> Map[String, Array[(String, Double)]] {
  let filtered : Map[String, Array[(String, Double)]] = Map::new()
  for name, entries in values {
    if component_set.get(name) is None {
      continue
    }
    let keep : Array[(String, Double)] = []
    for entry in entries {
      let (other, weight) = entry
      if component_set.get(other) is Some(_) {
        keep.push((other, weight))
      }
    }
    filtered[name] = keep
  }
  filtered
}

///|
/// Graphviz parity: root ReMincross runs mincross per connected component
/// (dot_mincross init_mccomp loop), then concatenates rank output by component.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_rank_reorder(
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out_mincross : Array[@cgraph.Edge],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_edge_tail_port_x_mincross : Array[Double],
  order_edge_head_port_x_mincross : Array[Double],
  order_edge_tail_port_order_mincross : Array[Double],
  order_edge_head_port_order_mincross : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let mut has_cluster_keys = false
  for _name, cluster in order_cluster_keys {
    if cluster != "" {
      has_cluster_keys = true
      break
    }
  }
  let components =
    if has_cluster_keys {
      []
    } else {
      collect_noncluster_reorder_components(
        order_rank_keys_for_mincross,
        order_groups_for_mincross,
        order_node_order,
        graphviz_out_neighbors,
        graphviz_in_neighbors,
        order_flat_constraints,
      )
    }
  if components.length() <= 1 {
    return reorder_rank_groups(
      order_rank_keys_for_mincross,
      order_groups_for_mincross,
      order_edges_out_mincross,
      order_edge_tail_out_mincross,
      order_edge_head_out_mincross,
      order_edge_tail_port_x_mincross,
      order_edge_head_port_x_mincross,
      order_edge_tail_port_order_mincross,
      order_edge_head_port_order_mincross,
      parents,
      children,
      order_cluster_keys,
      cluster_meta.rank_same_groups,
      cluster_meta.rank_same_order,
      edge_order,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      preferred_positions,
      order_cluster_skeleton,
      order_flat_constraints,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
      graphviz_flip=graphviz_flip,
      // Graphviz parity: root ReMincross coalesces parallel edge segments
      // into a single crossing edge with summed xpenalty.
      coalesce_parallel_edges=true,
    )
  }

  let merged : Map[Int, Array[String]] = Map::new()
  for rank in order_rank_keys_for_mincross {
    merged[rank] = []
  }
  for component_nodes in components {
    let component_set = build_node_membership_set(component_nodes)
    let component_groups =
      build_noncluster_reorder_component_groups(
        order_rank_keys_for_mincross,
        order_groups_for_mincross,
        component_set,
      )
    let (
      component_edges,
      component_edge_tail,
      component_edge_head,
      component_edge_tail_port_x,
      component_edge_head_port_x,
      component_edge_tail_port_order,
      component_edge_head_port_order,
    ) =
      collect_mincross_order_edges(
        component_set,
        order_edges_out_mincross,
        order_edge_tail_out_mincross,
        order_edge_head_out_mincross,
        order_edge_tail_port_x_mincross,
        order_edge_head_port_x_mincross,
        order_edge_tail_port_order_mincross,
        order_edge_head_port_order_mincross,
      )
    let component_parents =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        parents,
      )
    let component_children =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        children,
      )
    let component_graphviz_out_neighbors =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        graphviz_out_neighbors,
      )
    let component_graphviz_in_neighbors =
      filter_noncluster_neighbor_map_for_component(
        component_nodes,
        component_set,
        graphviz_in_neighbors,
      )
    let component_port_order_positions =
      filter_node_double_map_for_component(
        component_set,
        port_order_positions,
      )
    let component_preferred_positions =
      filter_node_double_map_for_component(
        component_set,
        preferred_positions,
      )
    let component_port_order_contrib =
      filter_node_contrib_map_for_component(
        component_set,
        port_order_contrib,
      )
    let component_flat_constraints =
      filter_noncluster_flat_constraints_for_component(
        order_flat_constraints,
        component_set,
      )
    let ordered_component =
      reorder_rank_groups(
        order_rank_keys_for_mincross,
        component_groups,
        component_edges,
        component_edge_tail,
        component_edge_head,
        component_edge_tail_port_x,
        component_edge_head_port_x,
        component_edge_tail_port_order,
        component_edge_head_port_order,
        component_parents,
        component_children,
        order_cluster_keys,
        cluster_meta.rank_same_groups,
        cluster_meta.rank_same_order,
        edge_order,
        order_node_order,
        order_sizes_out,
        nodesep_pt,
        has_edge_labels,
        component_port_order_positions,
        component_port_order_contrib,
        component_preferred_positions,
        order_cluster_skeleton,
        component_flat_constraints,
        graphviz_out_neighbors=component_graphviz_out_neighbors,
        graphviz_in_neighbors=component_graphviz_in_neighbors,
        graphviz_flip=graphviz_flip,
        // Graphviz parity: component root reorder uses the same
        // parallel-edge xpenalty coalescing as init_mccomp.
        coalesce_parallel_edges=true,
      )
    for rank in order_rank_keys_for_mincross {
      let names = match ordered_component.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() == 0 {
        continue
      }
      let merged_names = match merged.get(rank) {
        Some(list) => list
        None => []
      }
      for name in names {
        merged_names.push(name)
      }
      merged[rank] = merged_names
    }
  }
  merged
}

///|
/// Graphviz parity: root ReMincross seeds root/skeleton rank groups and keeps
/// DOT_TRACE_GROUPS neighbor tracing aligned to Graphviz debug flow.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_groups_with_trace(
  order_with_clusters : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_out_neighbors : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let order_groups_for_mincross =
    build_order_groups_for_root_mincross(
      order_with_clusters,
      seeded_groups,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  if @sys.get_env_var("DOT_TRACE_ROOT_INPUT") is Some(_) {
    for rank, names in order_groups_for_mincross {
      let rank_joined = names.join(" ")
      println("root_input_rank \{rank}: \{rank_joined}")
      for name in names {
        let cluster = match order_cluster_keys.get(name) {
          Some(value) => value
          None => ""
        }
        let skel = order_cluster_skeleton.get(name) == Some(true)
        println("root_input_node \{name} cluster=\{cluster} skel=\{skel}")
      }
    }
  }
  trace_root_mincross_graphviz_neighbors(
    graphviz_in_neighbors,
    graphviz_out_neighbors,
  )
  order_groups_for_mincross
}

///|
/// Graphviz parity: root ReMincross stage output merges reordered root nodes
/// into seeded groups (clustered mode) and preserves tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_reorder_stage_output(
  order_with_clusters : Bool,
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let ordered =
    build_root_mincross_final_ordered_groups(
      order_with_clusters,
      order_rank_keys,
      seeded_groups,
      ordered_mincross,
      mincross_nodes,
      order_cluster_keys,
      order_cluster_skeleton,
    )
  build_root_mincross_reorder_output(order_groups_for_mincross, ordered)
}


///|
/// Graphviz parity: root ReMincross rank-reorder input tuple alias keeps
/// membership/edge/preferred-position field ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
type RootMincrossRankReorderInputsPhaseOutput = (
  Array[Int],
  Map[String, Bool],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, Double],
)

///|
/// Graphviz parity: root ReMincross rank-reorder input tuple preserves
/// Graphviz field ordering across membership/edge/preferred-position outputs.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_rank_reorder_inputs_output(
  order_rank_keys_for_mincross : Array[Int],
  mincross_nodes : Map[String, Bool],
  order_edges_out_mincross : Array[@cgraph.Edge],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_edge_tail_port_x_mincross : Array[Double],
  order_edge_head_port_x_mincross : Array[Double],
  order_edge_tail_port_order_mincross : Array[Double],
  order_edge_head_port_order_mincross : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  edge_order : Map[String, Int],
  preferred_positions : Map[String, Double],
) -> RootMincrossRankReorderInputsPhaseOutput {
  (
    order_rank_keys_for_mincross,
    mincross_nodes,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    edge_order,
    preferred_positions,
  )
}


///|
/// Graphviz parity: root ReMincross edge-input phase filters root-only edges,
/// ports, and parent/child maps from mincross node membership.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_rank_reorder_inputs_edge_phase(
  mincross_nodes : Map[String, Bool],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_nodes_for_mincross : Array[String],
  order_ranks : Map[String, Int],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
) {
  build_root_mincross_edges_and_indices(
    mincross_nodes,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_nodes_for_mincross,
    order_ranks,
  )
}


///|
/// Graphviz parity: root ReMincross rank-reorder inputs derive root-node
/// membership, filtered edge arrays, and preferred positions in pass order.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_rank_reorder_inputs(
  order_with_vnodes : Bool,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_ranks : Map[String, Int],
) -> RootMincrossRankReorderInputsPhaseOutput {
  let (order_rank_keys_for_mincross, order_nodes_for_mincross, mincross_nodes) =
    build_root_mincross_node_membership_inputs(order_groups_for_mincross)
  let (
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    edge_order,
  ) =
    build_root_mincross_rank_reorder_inputs_edge_phase(
      mincross_nodes,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_nodes_for_mincross,
      order_ranks,
    )
  let preferred_positions =
    build_root_mincross_preferred_positions(
      order_with_vnodes,
      vnode_order_keys_for_ordering,
    )
  build_root_mincross_rank_reorder_inputs_output(
    order_rank_keys_for_mincross,
    mincross_nodes,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    edge_order,
    preferred_positions,
  )
}


///|
/// Graphviz parity: root ReMincross rank-reorder execution consumes prepared
/// root-only inputs and applies Graphviz reorder_rank_groups semantics.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_rank_reorder_from_inputs(
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out_mincross : Array[@cgraph.Edge],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_edge_tail_port_x_mincross : Array[Double],
  order_edge_head_port_x_mincross : Array[Double],
  order_edge_tail_port_order_mincross : Array[Double],
  order_edge_head_port_order_mincross : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  run_root_mincross_rank_reorder(
    order_rank_keys_for_mincross,
    order_groups_for_mincross,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    order_cluster_keys,
    cluster_meta,
    edge_order,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    preferred_positions,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: root ReMincross rank-reorder execution phase forwards
/// prepared root-only inputs into Graphviz reorder_rank_groups semantics.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_rank_reorder_pass_reorder_phase(
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out_mincross : Array[@cgraph.Edge],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_edge_tail_port_x_mincross : Array[Double],
  order_edge_head_port_x_mincross : Array[Double],
  order_edge_tail_port_order_mincross : Array[Double],
  order_edge_head_port_order_mincross : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  run_root_mincross_rank_reorder_from_inputs(
    order_rank_keys_for_mincross,
    order_groups_for_mincross,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    order_cluster_keys,
    cluster_meta,
    edge_order,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    preferred_positions,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: root ReMincross rank-reorder pass input phase builds
/// root-only membership/edge/preferred-position tuples without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_rank_reorder_pass_inputs_phase(
  order_with_vnodes : Bool,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_ranks : Map[String, Int],
) -> RootMincrossRankReorderInputsPhaseOutput {
  build_root_mincross_rank_reorder_inputs(
    order_with_vnodes,
    vnode_order_keys_for_ordering,
    order_groups_for_mincross,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_ranks,
  )
}


///|
/// Graphviz parity: root ReMincross rank-reorder pass output preserves
/// reordered-root groups plus mincross-node membership tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_rank_reorder_pass_output(
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[String, Bool]) {
  (ordered_mincross, mincross_nodes)
}


///|
/// Graphviz parity: root ReMincross rank-reorder pass finalize phase runs
/// reorder execution and packages mincross-node membership output tuple.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_rank_reorder_pass_finalize_phase(
  order_rank_keys_for_mincross : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out_mincross : Array[@cgraph.Edge],
  order_edge_tail_out_mincross : Array[String],
  order_edge_head_out_mincross : Array[String],
  order_edge_tail_port_x_mincross : Array[Double],
  order_edge_head_port_x_mincross : Array[Double],
  order_edge_tail_port_order_mincross : Array[Double],
  order_edge_head_port_order_mincross : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
  mincross_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[String, Bool]) {
  if @sys.get_env_var("DOT_TRACE_ROOT_INPUT") is Some(_) {
    let mut edge_idx = 0
    while edge_idx < order_edges_out_mincross.length() {
      let tail = order_edge_tail_out_mincross[edge_idx]
      let head = order_edge_head_out_mincross[edge_idx]
      let pen = edge_xpenalty(order_edges_out_mincross[edge_idx])
      println("root_input_edge \{edge_idx}: \{tail} -> \{head} pen=\{pen}")
      edge_idx = edge_idx + 1
    }
  }
  let ordered_mincross =
    run_root_mincross_rank_reorder_pass_reorder_phase(
      order_rank_keys_for_mincross,
      order_groups_for_mincross,
      order_edges_out_mincross,
      order_edge_tail_out_mincross,
      order_edge_head_out_mincross,
      order_edge_tail_port_x_mincross,
      order_edge_head_port_x_mincross,
      order_edge_tail_port_order_mincross,
      order_edge_head_port_order_mincross,
      parents,
      children,
      order_cluster_keys,
      cluster_meta,
      edge_order,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      preferred_positions,
      order_cluster_skeleton,
      order_flat_constraints,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      graphviz_flip,
    )
  build_root_mincross_rank_reorder_pass_output(
    ordered_mincross,
    mincross_nodes,
  )
}

///|
/// Graphviz parity: root ReMincross rank-reorder finalize dispatch reads
/// input-phase tuple and forwards values in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_rank_reorder_pass_finalize_phase_from_inputs_phase_output(
  dispatch_context : RootMincrossRankReorderFinalizeDispatchContext,
  inputs_phase_output : RootMincrossRankReorderInputsPhaseOutput,
) -> (Map[Int, Array[String]], Map[String, Bool]) {
  let (
    order_rank_keys_for_mincross,
    mincross_nodes,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    edge_order,
    preferred_positions,
  ) = inputs_phase_output
  run_root_mincross_rank_reorder_pass_finalize_phase(
    order_rank_keys_for_mincross,
    dispatch_context.order_groups_for_mincross,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    parents,
    children,
    dispatch_context.order_cluster_keys,
    dispatch_context.cluster_meta,
    edge_order,
    dispatch_context.order_node_order,
    dispatch_context.order_sizes_out,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    preferred_positions,
    dispatch_context.order_cluster_skeleton,
    dispatch_context.order_flat_constraints,
    dispatch_context.graphviz_out_neighbors,
    dispatch_context.graphviz_in_neighbors,
    dispatch_context.graphviz_flip,
    mincross_nodes,
  )
}


///|
/// Graphviz parity: root ReMincross rank-reorder pass keeps input preparation
/// and reorder_rank_groups execution in the same Graphviz call sequence.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_rank_reorder_pass(
  order_with_vnodes : Bool,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[String, Bool]) {
  let inputs_phase_output =
    build_root_mincross_rank_reorder_pass_inputs_phase(
      order_with_vnodes,
      vnode_order_keys_for_ordering,
      order_groups_for_mincross,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_ranks,
    )
  let dispatch_context : RootMincrossRankReorderFinalizeDispatchContext = {
    order_groups_for_mincross,
    order_cluster_keys,
    cluster_meta,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    graphviz_flip,
  }
  run_root_mincross_rank_reorder_pass_finalize_phase_from_inputs_phase_output(
    dispatch_context,
    inputs_phase_output,
  )
}


///|
/// Graphviz parity: root ReMincross stage first derives root/skeleton groups,
/// then runs root rank-reorder pass before final seeded-group merge output.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder_rank_reorder_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_out_neighbors : Map[String, Array[String]],
  vnode_order_keys_for_ordering : Map[String, Double],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]], Map[String, Bool]) {
  let order_groups_for_mincross =
    build_root_mincross_groups_with_trace(
      order_with_clusters,
      seeded_groups,
      order_cluster_keys,
      order_cluster_skeleton,
      graphviz_in_neighbors,
      graphviz_out_neighbors,
    )
  let (ordered_mincross, mincross_nodes) =
    run_root_mincross_rank_reorder_pass(
      order_with_vnodes,
      vnode_order_keys_for_ordering,
      order_groups_for_mincross,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_ranks,
      order_cluster_keys,
      cluster_meta,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      order_cluster_skeleton,
      order_flat_constraints,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      graphviz_flip,
    )
  (order_groups_for_mincross, ordered_mincross, mincross_nodes)
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  // Graphviz parity: root ReMincross only reorders root/skeleton nodes;
  // cluster-internal nodes are handled by cluster-local build_ranks passes.
  let (order_groups_for_mincross, ordered_mincross, mincross_nodes) =
    run_root_mincross_reorder_rank_reorder_phase(
      order_with_clusters,
      order_with_vnodes,
      seeded_groups,
      order_cluster_keys,
      order_cluster_skeleton,
      graphviz_in_neighbors,
      graphviz_out_neighbors,
      vnode_order_keys_for_ordering,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      order_ranks,
      cluster_meta,
      order_node_order,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      order_flat_constraints,
      graphviz_flip,
    )
  build_root_mincross_reorder_stage_output(
    order_with_clusters,
    order_rank_keys,
    seeded_groups,
    ordered_mincross,
    mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
    order_groups_for_mincross,
  )
}

///|
/// Graphviz parity: edge-port data output keeps original and deduplicated edge
/// arrays plus sampled port coordinates/orders unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data_output(
  edge_order : Map[String, Int],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
) -> OrderingEdgePortData {
  {
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: edge-port original phase keeps original edge order map and
/// per-edge port position/order arrays before any ordering-edge deduplication.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data_original_phase(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> (Map[String, Int], Array[Double], Array[Double], Array[Double], Array[Double]) {
  let edge_order = collect_edge_order(edges)
  let (edge_tail_port_x, edge_head_port_x) =
    compute_edge_port_positions(nodes, edges, edge_tail, edge_head, order_sizes)
  let (edge_tail_port_order, edge_head_port_order) =
    compute_edge_port_orders(nodes, edges, edge_tail, edge_head, order_sizes)
  (
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
  )
}


///|
/// Graphviz parity: edge-port dedup phase derives ordering-edge arrays and
/// recomputes port position/order samples on deduplicated ordering edges.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data_dedup_phase(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (order_edges, order_edge_tail, order_edge_head) =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let (order_edge_tail_port_x, order_edge_head_port_x) =
    compute_edge_port_positions(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  let (order_edge_tail_port_order, order_edge_head_port_order) =
    compute_edge_port_orders(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  (
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}


///|
/// Graphviz parity: order-graph edge arrays preserve original edge sequence,
/// then reuse deduplicated order edges for mincross-specific port sampling.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> OrderingEdgePortData {
  let (
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
  ) =
    build_ordering_edge_port_data_original_phase(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  let (
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  ) =
    build_ordering_edge_port_data_dedup_phase(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  build_ordering_edge_port_data_output(
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}


///|
/// Graphviz parity: class2/decompose stage output preserves edge-chain maps and
/// node-order arrays used by later ordering passes.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_data_output(
  edges_by_tail : Map[String, Array[Int]],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_edge_creation : Array[(String, String)],
  skeleton_edge_creation : Array[(String, String)],
  edge_creation_order : Array[(String, String)],
  nlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> OrderingClass2Data {
  {
    edges_by_tail,
    order_edges_by_tail,
    order_edges_by_tail_root,
    order_edges_by_tail_unmapped,
    root_edge_creation,
    skeleton_edge_creation,
    edge_creation_order,
    nlist_order,
    vnode_creation_order,
  }
}

///|
/// Graphviz parity: root edge-chain phase derives root-only ND_out chains and
/// root edge creation order before unmapped edge-chain derivation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_root_and_unmapped_edge_chains_root_phase(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  edges_by_tail : Map[String, Array[Int]],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
) {
  build_root_order_edges_by_tail(
    order_with_clusters,
    order_edges_by_tail,
    order_edge_creation,
    creation_order,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    edge_vnodes,
    order_with_vnodes,
    cluster_keys,
    edges_by_tail,
  )
}


///|
/// Graphviz parity: unmapped edge-chain phase keeps pre-remap cluster-local
/// endpoints for cluster build_ranks passes before root/cluster remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_root_and_unmapped_edge_chains_unmapped_phase(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  edges_by_tail : Map[String, Array[Int]],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  build_unmapped_order_edges_by_tail(
    order_with_clusters,
    order_edges_by_tail,
    creation_order,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    edge_vnodes,
    order_with_vnodes,
    cluster_keys,
    edges_by_tail,
  )
}


///|
/// Graphviz parity: root/unmapped edge-chain output preserves tuple ordering
/// consumed by class2 edge-chain assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_root_and_unmapped_edge_chains_output(
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_edge_creation : Array[(String, String)],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) {
  (
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  )
}


///|
/// Graphviz parity: root and unmapped edge chains are derived from ND_out
/// ordering after class2 edge-chain construction for clustered passes.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_root_and_unmapped_edge_chains(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  edges_by_tail : Map[String, Array[Int]],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) {
  let (order_edges_by_tail_root, root_edge_creation) =
    build_ordering_root_and_unmapped_edge_chains_root_phase(
      order_with_clusters,
      order_edges_by_tail,
      order_edge_creation,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      edges_by_tail,
    )
  // Graphviz parity: cluster-local build_ranks uses edge chains before
  // root/cluster remapping so local passes see original cluster endpoints.
  let order_edges_by_tail_unmapped =
    build_ordering_root_and_unmapped_edge_chains_unmapped_phase(
      order_with_clusters,
      order_edges_by_tail,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      edges_by_tail,
    )
  build_ordering_root_and_unmapped_edge_chains_output(
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  )
}


///|
/// Graphviz parity: class2 base edge-chain build follows agfstnode creation
/// order and ND_out traversal before root/unmapped derivations.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_base_edge_chains(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_keys : Map[String, String],
) -> (
  Array[String],
  Map[String, Array[Int]],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  // Graphviz parity: class2 iterates agfstnode order (creation order) for edge traversal.
  let creation_order = collect_creation_order(nodes)
  // Graphviz parity: order-graph edges follow ND_out ordering after acyclic.
  let edges_by_tail =
    build_edges_by_tail_from_out_order(nodes, edge_out_order)
  let (order_edges_by_tail, vnode_creation_by_tail, order_edge_creation) =
    build_order_edges_by_tail_graphviz(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      false,
      true,
      edges_by_tail,
    )
  (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
  )
}


///|
/// Graphviz parity: class2 edge-chain data output preserves tuple field order
/// consumed by subsequent build_ranks + ordering preprocessing stages.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_edge_chain_data_output(
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  vnode_creation_by_tail : Map[String, Array[String]],
  order_edge_creation : Array[(String, String)],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_edge_creation : Array[(String, String)],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> (
  Array[String],
  Map[String, Array[Int]],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) {
  (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  )
}

///|
/// Graphviz parity: class2 edge-chain assembly extends base ND_out chains
/// with root/unmapped variants before emitting tuple-ordered chain data.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_edge_chain_data_from_base_chains(
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  vnode_creation_by_tail : Map[String, Array[String]],
  order_edge_creation : Array[(String, String)],
  order_with_clusters : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
) -> (
  Array[String],
  Map[String, Array[Int]],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) {
  let (
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  ) =
    build_ordering_root_and_unmapped_edge_chains(
      order_with_clusters,
      order_edges_by_tail,
      order_edge_creation,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      edges_by_tail,
    )
  build_ordering_class2_edge_chain_data_output(
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  )
}


///|
/// Graphviz parity: class2 builds ND_out edge chains in agfstnode order,
/// then derives root/unmapped variants for clustered build_ranks passes.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_edge_chain_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_keys : Map[String, String],
) -> (
  Array[String],
  Map[String, Array[Int]],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) {
  let (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
  ) =
    build_ordering_class2_base_edge_chains(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      cluster_keys,
    )
  build_ordering_class2_edge_chain_data_from_base_chains(
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_with_clusters,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    edge_vnodes,
    order_with_vnodes,
    cluster_keys,
  )
}


///|
/// Graphviz parity: class2 creation prep builds cluster skeleton node sequence,
/// skeleton edge sequence, and merged edge creation order in pass order.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_skeleton_and_edge_creation_sequences(
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
) -> (Array[String], Array[(String, String)], Array[(String, String)]) {
  let cluster_skeleton_creation =
    build_cluster_skeleton_creation(
      order_with_clusters,
      cluster_meta.cluster_order,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
    )
  let skeleton_edge_creation =
    build_skeleton_edge_creation_for_order_graph(
      order_with_clusters,
      cluster_meta.cluster_order,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
      order_edges_by_tail,
      order_edges_by_tail_root,
    )
  let edge_creation_order =
    build_edge_creation_order(
      skeleton_edge_creation,
      order_edge_creation,
    )
  (cluster_skeleton_creation, skeleton_edge_creation, edge_creation_order)
}

///|
/// Graphviz parity: class2 creation-sequence output preserves tuple field order
/// consumed by class2/decompose preprocessing.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_creation_sequences_output(
  skeleton_edge_creation : Array[(String, String)],
  edge_creation_order : Array[(String, String)],
  nlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> (Array[(String, String)], Array[(String, String)], Array[String], Array[String]) {
  (
    skeleton_edge_creation,
    edge_creation_order,
    nlist_order,
    vnode_creation_order,
  )
}

///|
/// Graphviz parity: class2 creation sequences build cluster skeleton edges,
/// then edge creation order and GD_nlist ordering in Graphviz pass order.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_creation_sequences(
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
  creation_order : Array[String],
  vnode_creation_by_tail : Map[String, Array[String]],
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> (Array[(String, String)], Array[(String, String)], Array[String], Array[String]) {
  let (cluster_skeleton_creation, skeleton_edge_creation, edge_creation_order) =
    build_ordering_class2_skeleton_and_edge_creation_sequences(
      order_with_clusters,
      cluster_meta,
      order_edges_by_tail,
      order_edges_by_tail_root,
      order_edge_creation,
    )
  let (nlist_order, vnode_creation_order) =
    build_nlist_order_and_vnode_creation_order(
      cluster_skeleton_creation,
      creation_order,
      vnode_creation_by_tail,
      edge_creation_order,
      flat_rank_constraints,
      graphviz_flip,
      cluster_meta.has_clusters,
      cluster_meta.cluster_keys,
    )
  build_ordering_class2_creation_sequences_output(
    skeleton_edge_creation,
    edge_creation_order,
    nlist_order,
    vnode_creation_order,
  )
}


///|
/// Graphviz parity: class2 data assembly consumes edge-chain outputs, then
/// appends creation-sequence outputs without tuple field reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_data_from_edge_chain_data(
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  vnode_creation_by_tail : Map[String, Array[String]],
  order_edge_creation : Array[(String, String)],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_edge_creation : Array[(String, String)],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> OrderingClass2Data {
  let (
    skeleton_edge_creation,
    edge_creation_order,
    nlist_order,
    vnode_creation_order,
  ) =
    build_ordering_class2_creation_sequences(
      order_with_clusters,
      cluster_meta,
      order_edges_by_tail,
      order_edges_by_tail_root,
      order_edge_creation,
      creation_order,
      vnode_creation_by_tail,
      flat_rank_constraints,
      graphviz_flip,
    )
  build_ordering_class2_data_output(
    edges_by_tail,
    order_edges_by_tail,
    order_edges_by_tail_root,
    order_edges_by_tail_unmapped,
    root_edge_creation,
    skeleton_edge_creation,
    edge_creation_order,
    nlist_order,
    vnode_creation_order,
  )
}


///|
/// Graphviz parity: class2/decompose ordering prep follows creation order,
/// ND_out traversal, cluster skeleton insertion, then GD_nlist construction.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> OrderingClass2Data {
  let (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  ) =
    build_ordering_class2_edge_chain_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      cluster_meta.cluster_keys,
    )
  build_ordering_class2_data_from_edge_chain_data(
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
    order_with_clusters,
    cluster_meta,
    flat_rank_constraints,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: vnode ordering keys use cluster-aware class2 traversal when
/// clusters exist, otherwise GD_nlist fallback ordering for vnode ranks.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_keys_for_nonzero_vnodes(
  cluster_meta : ClusterMetadata,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  base_order_index : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  ordering_groups_base : Map[Int, Array[String]],
  nlist_order_index : Map[String, Int],
) -> Map[String, Double] {
  if cluster_meta.has_clusters {
    build_vnode_order_keys(
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      base_order_index,
      cluster_meta.cluster_keys,
      cluster_meta.cluster_parents,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
    )
  } else {
    build_vnode_order_keys_from_nlist(
      ordering_groups_base,
      vnode_info.vnodes_by_rank,
      base_order_index,
      nlist_order_index,
      Map::new(),
      false,
    )
  }
}

///|
/// Graphviz parity: vnode ordering keys come from cluster-aware class2 walks,
/// or from GD_nlist fallback ordering when clusters are absent.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_keys_for_ordering_stage(
  vnode_count : Int,
  cluster_meta : ClusterMetadata,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  base_order_index : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  ordering_groups_base : Map[Int, Array[String]],
  nlist_order_index : Map[String, Int],
) -> Map[String, Double] {
  if vnode_count > 0 {
    build_vnode_order_keys_for_nonzero_vnodes(
      cluster_meta,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      base_order_index,
      vnode_info,
      ordering_groups_base,
      nlist_order_index,
    )
  } else {
    Map::new()
  }
}

///|
/// Graphviz parity: order-reorder context output keeps order-graph handles,
/// creation ordering, and build_ranks node order mapping unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_order_reorder_context_output(
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_nodes : Array[String],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
  creation_order : Array[String],
  order_node_order : Map[String, Int],
) -> OrderReorderContext {
  {
    order_rank_keys,
    order_ranks,
    order_nodes,
    order_graph,
    order_node_map,
    order_graph_unmapped,
    order_node_map_unmapped,
    creation_order,
    order_node_order,
  }
}


///|
/// Graphviz parity: order-reorder context builds paired mapped/unmapped order
/// graphs from the same order-node sequence before edge materialization passes.
/// Do not change behavior without updating fixtures/tests.
fn build_order_graph_pairs_for_reorder_context(
  order_nodes : Array[String],
) -> (
  @cgraph.Graph,
  Map[String, @cgraph.Node],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
) {
  let (order_graph, order_node_map) =
    build_order_graph_and_nodes("order_graph", order_nodes)
  let (order_graph_unmapped, order_node_map_unmapped) =
    build_order_graph_and_nodes("order_graph_unmapped", order_nodes)
  (order_graph, order_node_map, order_graph_unmapped, order_node_map_unmapped)
}


///|
/// Graphviz parity: reorder context derives creation order from GD_nlist and
/// computes build_ranks seed node-order map before order-edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_creation_and_node_order_for_reorder_context(
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  order_groups : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> (Array[String], Map[String, Int]) {
  let creation_order =
    build_reverse_creation_order_from_nlist(nlist_order)
  let order_node_order =
    build_order_node_order_for_build_ranks(
      gdnlist_order,
      nlist_order,
      node_order,
      real_nodes,
      order_groups,
      base_order_index,
      rank_same_groups,
      rank_same_order,
      port_edge_nodes,
    )
  (creation_order, order_node_order)
}

///|
/// Graphviz parity: order-graph rebuild uses GD_nlist-derived creation order
/// and build_ranks seed order before mapped/unmapped edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_order_reorder_context(
  order_groups : Map[Int, Array[String]],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  base_order_index : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> OrderReorderContext {
  let order_rank_keys = collect_rank_keys(order_groups)
  let order_ranks = build_node_ranks(order_groups)
  let order_nodes =
    build_order_nodes_from_groups(order_groups, order_rank_keys)
  let (order_graph, order_node_map, order_graph_unmapped, order_node_map_unmapped) =
    build_order_graph_pairs_for_reorder_context(order_nodes)
  let (creation_order, order_node_order) =
    build_creation_and_node_order_for_reorder_context(
      nlist_order,
      gdnlist_order,
      node_order,
      real_nodes,
      order_groups,
      base_order_index,
      rank_same_groups,
      rank_same_order,
      port_edge_nodes,
    )
  build_order_reorder_context_output(
    order_rank_keys,
    order_ranks,
    order_nodes,
    order_graph,
    order_node_map,
    order_graph_unmapped,
    order_node_map_unmapped,
    creation_order,
    order_node_order,
  )
}

///|
/// Graphviz parity: materialized order-edge output preserves mapped/unmapped
/// arrays plus Graphviz neighbor maps for downstream reorder stages.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_output(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_flat_constraints : Map[String, Bool],
) -> OrderMaterializationData {
  {
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_flat_constraints,
  }
}

///|
/// Graphviz parity: neighbor/constraint output keeps ND_out, ND_in, and flat
/// constraint maps in fixed tuple order for ordering stages.
/// Do not change behavior without updating fixtures/tests.
fn build_order_neighbors_and_flat_constraints_output(
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_flat_constraints : Map[String, Bool],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Bool]) {
  (graphviz_out_neighbors, graphviz_in_neighbors, order_flat_constraints)
}

///|
/// Graphviz parity: Graphviz neighbor maps and flat constraints are derived
/// before unconstrained-node seed-order overrides for build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn build_order_neighbors_and_flat_constraints(
  order_nodes : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
  cluster_meta : ClusterMetadata,
  gdnlist_order : Array[String],
  real_nodes : Map[String, Bool],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
  order_node_order : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Bool]) {
  let (graphviz_out_neighbors, graphviz_in_neighbors) =
    build_graphviz_neighbor_maps(
      order_nodes,
      order_edges_by_tail,
      edge_creation_order,
    )
  let order_flat_constraints =
    clone_flat_constraints(cluster_meta.flat_constraints)
  apply_unconstrained_order_node_overrides(
    gdnlist_order,
    real_nodes,
    order_nodes,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    cluster_meta.rank_same_groups,
    edge_tail,
    edge_head,
    nodes,
    cluster_meta.intercluster_keys,
    order_node_order,
  )
  build_order_neighbors_and_flat_constraints_output(
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_flat_constraints,
  )
}


///|
/// Graphviz parity: mapped/unmapped materialization output preserves tuple field
/// order consumed by downstream ordering/reorder stages.
/// Do not change behavior without updating fixtures/tests.
fn build_materialize_order_edges_with_trace_output(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
}

///|
/// Graphviz parity: order-edge trace/output phase emits mapped-edge rank traces
/// before returning mapped/unmapped edge tuples in Graphviz field order.
/// Do not change behavior without updating fixtures/tests.
fn materialize_order_edges_with_trace_output_phase(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  order_ranks : Map[String, Int],
  real_nodes : Map[String, Bool],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  trace_order_edges_with_ranks(
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    real_nodes,
  )
  build_materialize_order_edges_with_trace_output(
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  )
}


///|
/// Graphviz parity: order-edge trace context builder preserves mapped/unmapped
/// materialization inputs before trace-output dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_materialize_order_edges_with_trace_context(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
  order_ranks : Map[String, Int],
  real_nodes : Map[String, Bool],
) -> MaterializeOrderEdgesWithTraceContext {
  {
    nlist_order,
    order_edges_by_tail,
    order_graph,
    order_node_map,
    order_edges_by_tail_unmapped,
    order_graph_unmapped,
    order_node_map_unmapped,
    order_ranks,
    real_nodes,
  }
}


///|
/// Graphviz parity: mapped/unmapped order-edge arrays are materialized first,
/// and trace emission observes the mapped arrays before neighbor construction.
/// Do not change behavior without updating fixtures/tests.
fn materialize_order_edges_with_trace(
  trace_context : MaterializeOrderEdgesWithTraceContext,
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  ) =
    materialize_mapped_and_unmapped_order_edges(
      trace_context.nlist_order,
      trace_context.order_edges_by_tail,
      trace_context.order_graph,
      trace_context.order_node_map,
      trace_context.order_edges_by_tail_unmapped,
      trace_context.order_graph_unmapped,
      trace_context.order_node_map_unmapped,
    )
  materialize_order_edges_with_trace_output_phase(
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    trace_context.order_ranks,
    trace_context.real_nodes,
  )
}


///|
/// Graphviz parity: order-edge materialization phase uses mapped/unmapped
/// GD_nlist-seeded traces before neighbor/constraint reconstruction.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_materialization_phase(
  context : MaterializedOrderEdgesAndNeighborsContext,
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let trace_context =
    build_materialize_order_edges_with_trace_context(
      context.nlist_order,
      context.order_edges_by_tail,
      context.order_graph,
      context.order_node_map,
      context.order_edges_by_tail_unmapped,
      context.order_graph_unmapped,
      context.order_node_map_unmapped,
      context.order_ranks,
      context.real_nodes,
    )
  materialize_order_edges_with_trace(trace_context)
}

///|
/// Graphviz parity: order-edge neighbor/constraint phase derives Graphviz
/// in/out neighbor maps and flat constraints before build_ranks reuse.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_neighbor_phase(
  context : MaterializedOrderEdgesAndNeighborsContext,
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Bool]) {
  build_order_neighbors_and_flat_constraints(
    context.order_nodes,
    context.order_edges_by_tail,
    context.edge_creation_order,
    context.cluster_meta,
    context.gdnlist_order,
    context.real_nodes,
    context.edge_tail,
    context.edge_head,
    context.nodes,
    context.order_node_order,
  )
}

///|
/// Graphviz parity: materialized order-edge output phase packages mapped/
/// unmapped edge arrays with neighbor/flat-constraint maps in tuple order.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_output_phase(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_flat_constraints : Map[String, Bool],
) -> OrderMaterializationData {
  build_materialized_order_edges_and_neighbors_output(
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_flat_constraints,
  )
}


///|
/// Graphviz parity: mapped/unmapped order-edge materialization context keeps
/// Graphviz traversal/neighbor inputs unchanged before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
priv struct MaterializedOrderEdgesAndNeighborsContext {
  nlist_order : Array[String]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  order_ranks : Map[String, Int]
  real_nodes : Map[String, Bool]
  order_nodes : Array[String]
  edge_creation_order : Array[(String, String)]
  cluster_meta : ClusterMetadata
  gdnlist_order : Array[String]
  edge_tail : Array[String]
  edge_head : Array[String]
  nodes : Array[@cgraph.Node]
  order_node_order : Map[String, Int]
}

///|
/// Graphviz parity: materialized order-edge context builder keeps reorder
/// graph fields and neighbor inputs in Graphviz materialization order.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_context(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  reorder_context : OrderReorderContext,
  real_nodes : Map[String, Bool],
  edge_creation_order : Array[(String, String)],
  cluster_meta : ClusterMetadata,
  gdnlist_order : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
) -> MaterializedOrderEdgesAndNeighborsContext {
  {
    nlist_order,
    order_edges_by_tail,
    order_graph: reorder_context.order_graph,
    order_node_map: reorder_context.order_node_map,
    order_edges_by_tail_unmapped,
    order_graph_unmapped: reorder_context.order_graph_unmapped,
    order_node_map_unmapped: reorder_context.order_node_map_unmapped,
    order_ranks: reorder_context.order_ranks,
    real_nodes,
    order_nodes: reorder_context.order_nodes,
    edge_creation_order,
    cluster_meta,
    gdnlist_order,
    edge_tail,
    edge_head,
    nodes,
    order_node_order: reorder_context.order_node_order,
  }
}


///|
/// Graphviz parity: mapped/unmapped order-edge materialization and neighbor
/// maps must follow GD_nlist/AGSEQ traversal before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors(
  context : MaterializedOrderEdgesAndNeighborsContext,
) -> OrderMaterializationData {
  let (
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
  ) =
    build_materialized_order_edges_and_neighbors_materialization_phase(context)
  let (graphviz_out_neighbors, graphviz_in_neighbors, order_flat_constraints) =
    build_materialized_order_edges_and_neighbors_neighbor_phase(context)
  build_materialized_order_edges_and_neighbors_output_phase(
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_flat_constraints,
  )
}

///|
/// Graphviz parity: root+cluster build_ranks stage output preserves root
/// mincross groups and vnode-augmented ordering groups unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_build_ranks_stage_output(
  order_groups_for_mincross : Map[Int, Array[String]],
  ordered : Map[Int, Array[String]],
  next_ordered_with_vnodes : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  {
    order_groups_for_mincross,
    ordered,
    ordered_with_vnodes: next_ordered_with_vnodes,
  }
}

///|
/// Graphviz parity: root+cluster build_ranks stage seeds reorder groups via
/// Graphviz-style build_ranks pass before root ReMincross execution.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_seeded_groups(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  build_seeded_groups_for_order_reorder(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_flip,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    flat_rank_constraints,
  )
}

///|
/// Graphviz parity: root+cluster build_ranks stage runs root ReMincross on
/// seeded groups before any cluster-local build_ranks vnode remapping.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder_in_root_cluster_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_mincross_reorder(
    order_with_clusters,
    order_with_vnodes,
    seeded_groups,
    order_rank_keys,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_cluster_keys,
    order_cluster_skeleton,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    graphviz_flip,
  )
}

///|
/// Graphviz parity: root+cluster build_ranks stage applies clustered
/// build_ranks on unmapped order edges to update vnode-augmented ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_ordered_with_vnodes(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  apply_cluster_build_ranks_and_track_vnodes(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
  )
}

///|
/// Graphviz parity: root+cluster root-reorder mincross phase forwards seeded
/// build_ranks groups into root ReMincross without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_mincross_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_mincross_reorder_in_root_cluster_stage(
    order_with_clusters,
    order_with_vnodes,
    seeded_groups,
    order_rank_keys,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_cluster_keys,
    order_cluster_skeleton,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: root+cluster root-reorder seed phase builds build_ranks
/// seeded groups from order graph inputs before root ReMincross dispatch.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_seed_phase(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  build_root_and_cluster_seeded_groups(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_flip,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster seed dispatch reads typed root-reorder
/// context and forwards build_ranks seed inputs in Graphviz ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_seed_phase_from_context(
  reorder_context : RootClusterRootReorderContext,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  run_root_and_cluster_root_reorder_seed_phase(
    order_rank_keys,
    order_groups,
    reorder_context.order_edge_tail_out,
    reorder_context.order_edge_head_out,
    reorder_context.order_ranks,
    reorder_context.order_node_order,
    reorder_context.order_cluster_keys,
    reorder_context.order_cluster_skeleton,
    reorder_context.order_flat_constraints,
    reorder_context.graphviz_flip,
    reorder_context.graphviz_out_neighbors,
    reorder_context.graphviz_in_neighbors,
    reorder_context.order_edges_out,
    reorder_context.order_edge_tail_port_x,
    reorder_context.order_edge_head_port_x,
    reorder_context.flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster output dispatch forwards seeded groups and
/// typed root-reorder context into root ReMincross unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_output_phase_from_seeded_groups(
  reorder_context : RootClusterRootReorderContext,
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_and_cluster_root_reorder_mincross_phase(
    reorder_context.order_with_clusters,
    reorder_context.order_with_vnodes,
    seeded_groups,
    order_rank_keys,
    reorder_context.order_ranks,
    reorder_context.order_edges_out,
    reorder_context.order_edge_tail_out,
    reorder_context.order_edge_head_out,
    reorder_context.order_edge_tail_port_x,
    reorder_context.order_edge_head_port_x,
    reorder_context.order_edge_tail_port_order,
    reorder_context.order_edge_head_port_order,
    reorder_context.order_cluster_keys,
    reorder_context.order_cluster_skeleton,
    reorder_context.cluster_meta,
    reorder_context.vnode_order_keys_for_ordering,
    reorder_context.order_node_order,
    reorder_context.order_sizes_out,
    reorder_context.nodesep_pt,
    reorder_context.has_edge_labels,
    reorder_context.port_order_positions,
    reorder_context.port_order_contrib,
    reorder_context.order_flat_constraints,
    reorder_context.graphviz_out_neighbors,
    reorder_context.graphviz_in_neighbors,
    reorder_context.graphviz_flip,
  )
}


///|
/// Graphviz parity: root+cluster stage seeds build_ranks groups then runs
/// root ReMincross before any cluster-local unmapped-edge build_ranks pass.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder(
  reorder_context : RootClusterRootReorderContext,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let seeded_groups =
    run_root_and_cluster_root_reorder_seed_phase_from_context(
      reorder_context,
      order_rank_keys,
      order_groups,
    )
  run_root_and_cluster_root_reorder_output_phase_from_seeded_groups(
    reorder_context,
    order_rank_keys,
    seeded_groups,
  )
}

///|
/// Graphviz parity: clustered build_ranks stage derives the vnode-inclusive
/// ordering from the root-reordered groups on the unmapped order graph.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_next_ordered_with_vnodes(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  build_root_and_cluster_ordered_with_vnodes(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
  )
}

///|
/// Graphviz parity: clustered build_ranks stage first runs root-level mincross
/// reorder on the order graph before local-cluster build_ranks application.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_root_reorder_result(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_context : RootClusterRootReorderContext = {
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    order_ranks,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    flat_rank_constraints,
  }
  run_root_and_cluster_root_reorder(
    reorder_context,
    order_rank_keys,
    order_groups,
  )
}

///|
/// Graphviz parity: post-root-reorder stage applies clustered build_ranks on
/// unmapped order edges and returns Graphviz tuple-ordered stage output.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_stage_output_after_root_reorder(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  order_groups_for_mincross : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  dot_trace_groups("ordered_after_root_merge", ordered)
  let next_ordered_with_vnodes =
    build_root_and_cluster_next_ordered_with_vnodes(
      order_with_clusters,
      order_with_vnodes,
      graph,
      ordered,
      cluster_meta,
      order_node_order,
      order_edges_out_unmapped,
      order_edge_tail_out_unmapped,
      order_edge_head_out_unmapped,
      order_edge_tail_port_x_unmapped,
      order_edge_head_port_x_unmapped,
      order_edge_tail_port_order_unmapped,
      order_edge_head_port_order_unmapped,
      ranks,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      vnode_info,
      graphviz_flip,
      ordered_with_vnodes,
    )
  dot_trace_groups("ordered_before_clean", ordered)
  build_root_and_cluster_build_ranks_stage_output(
    order_groups_for_mincross,
    ordered,
    next_ordered_with_vnodes,
  )
}


///|
/// Graphviz parity: root-reorder outputs are forwarded unchanged into the
/// unmapped-edge build_ranks stage before final root+cluster stage output.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_from_root_reorder_result(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  order_groups_for_mincross : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  build_root_and_cluster_stage_output_after_root_reorder(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    order_groups_for_mincross,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks stage computes root-level
/// mincross reorder outputs before unmapped-edge build_ranks forwarding.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_root_reorder_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  build_root_and_cluster_root_reorder_result(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    order_rank_keys,
    order_groups,
    order_ranks,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize phase applies clustered
/// unmapped-edge build_ranks and forwards root-reorder outputs unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  order_groups_for_mincross : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_from_root_reorder_result(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    order_groups_for_mincross,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize dispatch reads
/// root-reorder tuple and forwards values in Graphviz argument order.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase_from_root_reorder_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  root_reorder_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> OrderRootClusterStageData {
  let (order_groups_for_mincross, ordered) = root_reorder_output
  run_root_and_cluster_build_ranks_stage_finalize_phase(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    order_groups_for_mincross,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks root-reorder dispatch reads
/// stage inputs and forwards them in Graphviz phase-call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_root_reorder_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_and_cluster_build_ranks_stage_root_reorder_phase(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    order_rank_keys,
    order_groups,
    order_ranks,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize-stage output dispatch
/// reads root-reorder output and forwards payload in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  root_reorder_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_finalize_phase_from_root_reorder_output(
    order_with_clusters,
    order_with_vnodes,
    graph,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    root_reorder_output,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks stage context builder preserves
/// runtime dispatch field ordering before phase forwarding.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_build_ranks_stage_context(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
) -> RootClusterBuildRanksStageContext {
  {
    order_with_clusters,
    order_with_vnodes,
    graph,
    cluster_meta,
    vnode_order_keys_for_ordering,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    flat_rank_constraints,
    ranks,
    vnode_info,
  }
}


///|
/// Graphviz parity: root+cluster build_ranks root-reorder phase dispatch reads
/// typed stage context and stage inputs in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_root_reorder_phase_output_from_context(
  stage_context : RootClusterBuildRanksStageContext,
  stage_inputs : RootClusterBuildRanksStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_and_cluster_build_ranks_stage_root_reorder_phase_output(
    stage_context.order_with_clusters,
    stage_context.order_with_vnodes,
    stage_context.cluster_meta,
    stage_context.vnode_order_keys_for_ordering,
    stage_inputs.order_node_order,
    stage_inputs.order_sizes_out,
    stage_context.nodesep_pt,
    stage_context.has_edge_labels,
    stage_context.port_order_positions,
    stage_context.port_order_contrib,
    stage_context.graphviz_flip,
    stage_inputs.order_rank_keys,
    stage_inputs.order_groups,
    stage_inputs.order_ranks,
    stage_inputs.order_cluster_keys,
    stage_inputs.order_cluster_skeleton,
    stage_inputs.order_flat_constraints,
    stage_inputs.graphviz_out_neighbors,
    stage_inputs.graphviz_in_neighbors,
    stage_inputs.order_edges_out,
    stage_inputs.order_edge_tail_out,
    stage_inputs.order_edge_head_out,
    stage_inputs.order_edge_tail_port_x,
    stage_inputs.order_edge_head_port_x,
    stage_inputs.order_edge_tail_port_order,
    stage_inputs.order_edge_head_port_order,
    stage_context.flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize-phase dispatch reads
/// typed stage context and root-reorder output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase_output_from_context(
  stage_context : RootClusterBuildRanksStageContext,
  stage_inputs : RootClusterBuildRanksStageInputs,
  root_reorder_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_finalize_phase_output(
    stage_context.order_with_clusters,
    stage_context.order_with_vnodes,
    stage_context.graph,
    stage_context.cluster_meta,
    stage_inputs.order_node_order,
    stage_inputs.order_edges_out_unmapped,
    stage_inputs.order_edge_tail_out_unmapped,
    stage_inputs.order_edge_head_out_unmapped,
    stage_inputs.order_edge_tail_port_x_unmapped,
    stage_inputs.order_edge_head_port_x_unmapped,
    stage_inputs.order_edge_tail_port_order_unmapped,
    stage_inputs.order_edge_head_port_order_unmapped,
    stage_context.ranks,
    stage_inputs.order_sizes_out,
    stage_context.nodesep_pt,
    stage_context.has_edge_labels,
    stage_context.port_order_positions,
    stage_context.port_order_contrib,
    stage_context.vnode_info,
    stage_context.graphviz_flip,
    stage_inputs.ordered_with_vnodes,
    root_reorder_output,
  )
}


///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks application on the unmapped order graph before final cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  stage_inputs : RootClusterBuildRanksStageInputs,
) -> OrderRootClusterStageData {
  let stage_context =
    build_root_and_cluster_build_ranks_stage_context(
      order_with_clusters,
      order_with_vnodes,
      graph,
      cluster_meta,
      vnode_order_keys_for_ordering,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      graphviz_flip,
      flat_rank_constraints,
      ranks,
      vnode_info,
    )
  let root_reorder_output =
    run_root_and_cluster_build_ranks_stage_root_reorder_phase_output_from_context(
      stage_context,
      stage_inputs,
    )
  run_root_and_cluster_build_ranks_stage_finalize_phase_output_from_context(
    stage_context,
    stage_inputs,
    root_reorder_output,
  )
}


///|
/// Graphviz parity: clustered finalize stage output keeps final rank groups and
/// vnode-augmented groups in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_and_finalize_stage_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (next_ordered_with_vnodes, final_groups)
}

///|
/// Graphviz parity: clustered finalize stage builds root-cluster rank-order
/// mappings from root-only reorder before clustered ReMincross cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_for_finalize_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_for_cluster_reorder(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: clustered finalize stage applies cluster-rank-order maps
/// before the final clustered ReMincross cleanup pass.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_remincross_finalize_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let dispatch_context =
    build_finalize_order_groups_dispatch_context(
      order_with_clusters,
      order_with_vnodes,
      cluster_rank_order,
      cluster_meta,
      local_cluster_order,
      ordered_with_vnodes,
      graph,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      flat_rank_constraints,
      creation_order,
      edges_by_tail,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      real_nodes,
      graphviz_flip,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
    )
  finalize_order_groups_with_cluster_remincross(
    dispatch_context,
    order_rank_keys,
    ordered,
  )
}

///|
/// Graphviz parity: finalize-stage ReMincross consumes cluster-rank-order
/// output without argument reshuffling before clustered cleanup execution.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_remincross_from_cluster_rank_order(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_remincross_finalize_stage(
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: finalize-stage cluster-rank-order phase consumes
/// root-cluster reorder inputs before clustered ReMincross forwarding.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_for_finalize_stage(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage ReMincross phase forwards derived
/// cluster-rank-order maps into clustered cleanup without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_remincross_from_cluster_rank_order(
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: finalize-stage ReMincross dispatch reads derived
/// cluster-rank-order output then forwards payload without reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase_from_cluster_rank_order_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase(
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order_output,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage cluster-rank-order dispatch reads
/// root finalize inputs and forwards them in Graphviz phase-call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage cluster-rank-order output dispatch forwards
/// typed stage payload fields in Graphviz phase-call ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_stage_inputs(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  stage_inputs : ClusterFinalizeStageInputs,
) -> Map[Int, Map[String, Int]] {
  run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    stage_inputs.order_rank_keys,
    stage_inputs.order_groups_for_mincross,
    stage_inputs.order_cluster_keys,
    stage_inputs.order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    stage_inputs.order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage ReMincross phase dispatch reads
/// cluster-rank-order output and forwards payload in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase_from_cluster_rank_order_output(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: finalize-stage ReMincross output dispatch forwards typed
/// stage payload fields with cluster-rank-order output unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase_output_from_stage_inputs(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  stage_inputs : ClusterFinalizeStageInputs,
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase_output(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    local_cluster_order,
    stage_inputs.order_rank_keys,
    stage_inputs.ordered,
    real_nodes,
    stage_inputs.ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    stage_inputs.creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: finalize-pass cluster-rank-order context dispatch reads
/// typed finalize runtime payloads and preserves Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_context(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> Map[Int, Map[String, Int]] {
  run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_stage_inputs(
    dispatch_context.order_with_clusters,
    dispatch_context.order_with_vnodes,
    dispatch_context.graphviz_flip,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.nlist_order,
    dispatch_context.ranks,
    dispatch_context.order_edges_by_tail_root,
    dispatch_context.skeleton_edge_creation,
    dispatch_context.root_edge_creation,
    dispatch_context.flat_rank_constraints,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.vnode_order_keys_for_ordering,
    dispatch_context.real_nodes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    stage_inputs,
  )
}


///|
/// Graphviz parity: finalize-pass output dispatch reads cluster-rank-order
/// output plus typed runtime payload and forwards ReMincross unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_output_phase_from_cluster_rank_order_output(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase_output_from_stage_inputs(
    dispatch_context.order_with_clusters,
    dispatch_context.order_with_vnodes,
    dispatch_context.cluster_meta,
    dispatch_context.local_cluster_order,
    dispatch_context.real_nodes,
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_reversed,
    dispatch_context.edge_tail_port_x,
    dispatch_context.edge_head_port_x,
    dispatch_context.edge_tail_port_order,
    dispatch_context.edge_head_port_order,
    dispatch_context.ranks,
    dispatch_context.flat_rank_constraints,
    dispatch_context.edges_by_tail,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    dispatch_context.graphviz_flip,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    stage_inputs,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: finalize-stage cluster rank order is derived first, then
/// consumed by final clustered ReMincross without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let cluster_rank_order_output =
    run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_context(
      dispatch_context,
      stage_inputs,
    )
  run_cluster_rank_ordered_finalize_pass_output_phase_from_cluster_rank_order_output(
    dispatch_context,
    stage_inputs,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: clustered cleanup finalize-pass dispatch reads typed
/// context+stage inputs and forwards clustered ReMincross unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_finalize_pass(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass(
    dispatch_context,
    stage_inputs,
  )
}


///|
/// Graphviz parity: clustered finalize stage output dispatch reads finalize
/// pass tuple and preserves Graphviz output tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_output_phase_from_finalize_pass_output(
  finalize_pass_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (next_ordered_with_vnodes, final_groups) = finalize_pass_output
  build_cluster_rank_order_and_finalize_stage_output(
    next_ordered_with_vnodes,
    final_groups,
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
  let finalize_pass_output =
    run_cluster_rank_order_and_finalize_stage_finalize_pass(
      dispatch_context,
      stage_inputs,
    )
  run_cluster_rank_order_and_finalize_stage_output_phase_from_finalize_pass_output(
    finalize_pass_output,
  )
}

///|
/// Graphviz parity: existing-name map is seeded from declared nodes before
/// vnode synthesis and flat-label augmentation overlays.
/// Do not change behavior without updating fixtures/tests.
fn build_existing_node_names_map_for_positions(
  nodes : Array[@cgraph.Node],
) -> Map[String, Bool] {
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  existing_names
}

///|
/// Graphviz parity: vnode names are overlaid onto existing-name maps before
/// helper calls that need collision-safe synthetic node naming.
/// Do not change behavior without updating fixtures/tests.
fn add_vnode_names_to_existing_names_for_positions(
  existing_names : Map[String, Bool],
  vnode_ranks : Map[String, Int],
) -> Unit {
  for vnode, _ in vnode_ranks {
    existing_names[vnode] = true
  }
}

///|
/// Graphviz parity: ordering base-context port-edge map marks both endpoints
/// for edges with explicit tail/head ports before rank-same constraints build.
/// Do not change behavior without updating fixtures/tests.
fn build_port_edge_nodes_for_ordering_base_context(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Bool] {
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = port_is_explicit(edge.tail_port()) ||
      port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  port_edge_nodes
}

///|
/// Graphviz parity: ordering base-context output object maps precomputed node,
/// cluster, vnode, and rank-same artifacts without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_base_context_output(
  real_nodes : Map[String, Bool],
  edge_cluster_keys : Map[String, String],
  vnode_info : EdgeVnodeInfo,
  port_edge_nodes : Map[String, Bool],
  local_cluster_order : Map[String, Int],
  rank_same_constraints : Map[String, Bool],
) -> OrderingBaseContext {
  {
    real_nodes,
    edge_cluster_keys,
    vnode_info,
    port_edge_nodes,
    local_cluster_order,
    rank_same_constraints,
  }
}


///|
/// Graphviz parity: ordering pre-pass collects real-node maps, edge cluster
/// ownership, vnode chains, and local cluster/port constraints before class2.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_base_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingBaseContext {
  let real_nodes : Map[String, Bool] = Map::new()
  let existing_names = build_existing_node_names_map_for_positions(nodes)
  for node in nodes {
    let name = node.name()
    real_nodes[name] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_meta.cluster_parents,
  )
  let port_edge_nodes =
    build_port_edge_nodes_for_ordering_base_context(edges, edge_tail, edge_head)
  let local_cluster_order = build_local_cluster_order(
    nodes,
    cluster_meta.intercluster_keys,
    ranks,
    node_order,
  )
  let rank_same_constraints = build_rank_same_constraints(
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    node_order,
    port_edge_nodes,
    ranks,
  )
  build_ordering_base_context_output(
    real_nodes,
    edge_cluster_keys,
    vnode_info,
    port_edge_nodes,
    local_cluster_order,
    rank_same_constraints,
  )
}

///|
/// Graphviz parity: ordering runtime output object maps base-context fields and
/// vnode-count derivation without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context_output(
  base_context : OrderingBaseContext,
) -> OrderingRuntimeContext {
  {
    real_nodes: base_context.real_nodes,
    edge_cluster_keys: base_context.edge_cluster_keys,
    vnode_info: base_context.vnode_info,
    port_edge_nodes: base_context.port_edge_nodes,
    local_cluster_order: base_context.local_cluster_order,
    rank_same_constraints: base_context.rank_same_constraints,
    vnode_count: base_context.vnode_info.vnode_ranks.length(),
  }
}

///|
/// Graphviz parity: ordering runtime context keeps base-context extraction and
/// vnode-count derivation in the same sequence as Graphviz prep flow.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  let base_context =
    build_ordering_base_context(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      ranks,
      node_order,
      nodesep_pt,
      rankdir,
      cluster_meta,
    )
  build_ordering_runtime_context_output(base_context)
}

///|
/// Graphviz parity: vnode tail-constraint probe runs only when vnode ordering
/// data exists, preserving Graphviz-aligned diagnostic derivation path.
/// Do not change behavior without updating fixtures/tests.
fn maybe_probe_vnode_tail_constraints_for_ordering_runtime_context(
  runtime_context : OrderingRuntimeContext,
  edge_tail : Array[String],
) -> Unit {
  let _ =
    if runtime_context.vnode_count > 0 {
      build_vnode_tail_constraints(runtime_context.vnode_info.vnodes_by_rank, edge_tail)
    } else {
      Map::new()
    }
}

///|
/// Graphviz parity: ordering runtime prep keeps vnode tail-constraint derivation
/// in the same position as Graphviz ordering setup, even when only used for
/// parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context_with_tail_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  let runtime_context =
    build_ordering_runtime_context(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      ranks,
      node_order,
      nodesep_pt,
      rankdir,
      cluster_meta,
    )
  maybe_probe_vnode_tail_constraints_for_ordering_runtime_context(
    runtime_context,
    edge_tail,
  )
  runtime_context
}

///|
/// Graphviz parity: reorder-setup output object maps precomputed flags,
/// constraints, class2 payload, and vnode-order keys without extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_reorder_setup_output(
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  class2_data : OrderingClass2Data,
  gdnlist_order : Array[String],
  vnode_order_keys_for_ordering : Map[String, Double],
) -> OrderingReorderSetup {
  {
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip,
    flat_rank_constraints,
    class2_data,
    gdnlist_order,
    vnode_order_keys_for_ordering,
  }
}


///|
/// Graphviz parity: reorder setup derives class2 data, GD_nlist order, and
/// vnode ordering keys in Graphviz class2->decompose->vnode-key sequence.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_and_vnode_keys_for_reorder_setup(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  vnode_count : Int,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
) -> (OrderingClass2Data, Array[String], Map[String, Double]) {
  let class2_data =
    build_ordering_class2_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      vnode_info.edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      cluster_meta,
      flat_rank_constraints,
      graphviz_flip,
    )
  // Graphviz parity: GD_nlist follows decompose DFS order over fast graph edges.
  // Do not change behavior without updating fixtures/tests.
  let gdnlist_order = class2_data.nlist_order
  let nlist_order_index = build_nlist_order_index(class2_data.nlist_order)
  let vnode_order_keys_for_ordering =
    build_vnode_order_keys_for_ordering_stage(
      vnode_count,
      cluster_meta,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      base_order_index,
      vnode_info,
      ordering_groups_base,
      nlist_order_index,
    )
  (class2_data, gdnlist_order, vnode_order_keys_for_ordering)
}


///|
/// Graphviz parity: reorder setup derives rank-same-adjusted groups, order
/// indices, cluster/vnode flags, flip direction, and flat-rank constraints.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_reorder_flags_and_constraints(
  groups : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  vnode_count : Int,
  rankdir : RankDir,
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> (
  Map[Int, Array[String]],
  Map[String, Int],
  Bool,
  Bool,
  Bool,
  Map[String, Bool],
) {
  let ordering_groups_base = apply_rank_same_order_with_port_override(
    groups,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    node_order,
    port_edge_nodes,
  )
  let base_order_index = build_order_index(ordering_groups_base)
  let order_with_vnodes = vnode_count > 0
  let order_with_clusters =
    cluster_meta.has_clusters && cluster_meta.cluster_min_rank.length() > 0
  // Graphviz parity: GD_flip is true for horizontal rankdir (LR/RL).
  let graphviz_flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let flat_rank_constraints =
    build_flat_rank_constraints(
      edge_tail,
      edge_head,
      ranks,
    )
  (
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: reorder setup preserves class2/GD_nlist prep order before
/// clustered/nonclustered mincross paths diverge.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_reorder_setup(
  context : OrderingReorderSetupContext,
) -> OrderingReorderSetup {
  let (
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip,
    flat_rank_constraints,
  ) =
    build_ordering_reorder_flags_and_constraints(
      context.groups,
      context.cluster_meta,
      context.node_order,
      context.port_edge_nodes,
      context.vnode_count,
      context.rankdir,
      context.edge_tail,
      context.edge_head,
      context.ranks,
    )
  let (class2_data, gdnlist_order, vnode_order_keys_for_ordering) =
    build_ordering_class2_and_vnode_keys_for_reorder_setup(
      context.nodes,
      context.edges,
      context.edge_tail,
      context.edge_head,
      context.edge_reversed,
      context.edge_out_order,
      context.ranks,
      context.vnode_count,
      context.cluster_meta,
      context.vnode_info,
      ordering_groups_base,
      base_order_index,
      order_with_vnodes,
      order_with_clusters,
      flat_rank_constraints,
      graphviz_flip,
      context.edge_tail_port_x,
      context.edge_head_port_x,
      context.edge_tail_port_order,
      context.edge_head_port_order,
    )
  build_ordering_reorder_setup_output(
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip,
    flat_rank_constraints,
    class2_data,
    gdnlist_order,
    vnode_order_keys_for_ordering,
  )
}

///|
/// Graphviz parity: dispatch-setup output object maps edge-port data with
/// reorder/class2-derived traversal orders without extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup_output(
  edge_port_data : OrderingEdgePortData,
  reorder_setup : OrderingReorderSetup,
) -> OrderingDispatchSetup {
  let class2_data = reorder_setup.class2_data
  {
    edge_port_data,
    reorder_setup,
    nlist_order: class2_data.nlist_order,
    vnode_creation_order: class2_data.vnode_creation_order,
    gdnlist_order: reorder_setup.gdnlist_order,
  }
}

///|
/// Graphviz parity: dispatch setup keeps edge-port extraction and reorder setup
/// sequence identical to Graphviz class2/mincross preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup(
  context : OrderingDispatchSetupContext,
) -> OrderingDispatchSetup {
  let edge_port_data =
    build_ordering_edge_port_data(
      context.nodes,
      context.edges,
      context.edge_tail,
      context.edge_head,
      context.order_sizes,
    )
  let reorder_setup_context : OrderingReorderSetupContext = {
    nodes: context.nodes,
    edges: context.edges,
    edge_tail: context.edge_tail,
    edge_head: context.edge_head,
    edge_reversed: context.edge_reversed,
    edge_out_order: context.edge_out_order,
    ranks: context.ranks,
    groups: context.groups,
    node_order: context.node_order,
    port_edge_nodes: context.port_edge_nodes,
    vnode_count: context.vnode_count,
    rankdir: context.rankdir,
    cluster_meta: context.cluster_meta,
    vnode_info: context.vnode_info,
    edge_tail_port_x: edge_port_data.edge_tail_port_x,
    edge_head_port_x: edge_port_data.edge_head_port_x,
    edge_tail_port_order: edge_port_data.edge_tail_port_order,
    edge_head_port_order: edge_port_data.edge_head_port_order,
  }
  let reorder_setup =
    build_ordering_reorder_setup(reorder_setup_context)
  build_ordering_dispatch_setup_output(edge_port_data, reorder_setup)
}


///|
/// Graphviz parity: clustered pre-root stage output object maps grouped sizes,
/// cluster skeleton keys, reorder context, and materialized edges unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_pre_root_stage_output(
  order_groups : Map[Int, Array[String]],
  order_sizes_out : Map[String, NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  reorder_context : OrderReorderContext,
  materialized : OrderMaterializationData,
) -> OrderClusteredPreRootStageData {
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
/// Graphviz parity: clustered pre-root reorder context is built before
/// materialized order-edge/neighbor data, matching Graphviz stage sequence.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root_reorder_context_and_materialized(
  context : ClusteredPreRootReorderMaterializedContext,
) -> (OrderReorderContext, OrderMaterializationData) {
  let reorder_context =
    build_order_reorder_context(
      context.order_groups,
      context.nlist_order,
      context.gdnlist_order,
      context.node_order,
      context.real_nodes,
      context.base_order_index,
      context.cluster_meta.rank_same_groups,
      context.cluster_meta.rank_same_order,
      context.port_edge_nodes,
    )
  trace_order_node_order_debug(reorder_context.order_node_order)
  let materialized_inputs =
    build_materialized_order_edges_and_neighbors_context(
      context.nlist_order,
      context.order_edges_by_tail,
      context.order_edges_by_tail_unmapped,
      reorder_context,
      context.real_nodes,
      context.edge_creation_order,
      context.cluster_meta,
      context.gdnlist_order,
      context.edge_tail,
      context.edge_head,
      context.nodes,
    )
  let materialized =
    build_materialized_order_edges_and_neighbors(materialized_inputs)
  (reorder_context, materialized)
}


///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_pre_root_stage(
  context : ClusteredOrderingPreRootStageContext,
) -> OrderClusteredPreRootStageData {
  let (
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
  ) =
    build_order_groups_sizes_and_cluster_skeleton(
      context.ordering_groups_base,
      context.base_order_index,
      context.order_with_vnodes,
      context.order_with_clusters,
      context.cluster_meta,
      context.vnode_info,
      context.vnode_order_keys_for_ordering,
      context.order_sizes,
    )
  dot_trace_groups("order_groups_pre", order_groups)
  let reorder_materialized_context : ClusteredPreRootReorderMaterializedContext = {
    order_groups,
    nlist_order: context.nlist_order,
    gdnlist_order: context.gdnlist_order,
    node_order: context.node_order,
    real_nodes: context.real_nodes,
    base_order_index: context.base_order_index,
    cluster_meta: context.cluster_meta,
    port_edge_nodes: context.port_edge_nodes,
    order_edges_by_tail: context.order_edges_by_tail,
    order_edges_by_tail_unmapped: context.order_edges_by_tail_unmapped,
    edge_creation_order: context.edge_creation_order,
    edge_tail: context.edge_tail,
    edge_head: context.edge_head,
    nodes: context.nodes,
  }
  let (reorder_context, materialized) =
    build_clustered_pre_root_reorder_context_and_materialized(
      reorder_materialized_context,
    )
  build_clustered_ordering_pre_root_stage_output(
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
    reorder_context,
    materialized,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks stage input payload is assembled
/// from pre-root/reorder/materialized artifacts without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_build_ranks_stage_inputs_from_pre_root_payload(
  pre_root_stage : OrderClusteredPreRootStageData,
  reorder_context : OrderReorderContext,
  materialized : OrderMaterializationData,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> RootClusterBuildRanksStageInputs {
  {
    order_node_order: reorder_context.order_node_order,
    order_sizes_out: pre_root_stage.order_sizes_out,
    order_rank_keys: reorder_context.order_rank_keys,
    order_groups: pre_root_stage.order_groups,
    order_ranks: reorder_context.order_ranks,
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    order_flat_constraints: materialized.order_flat_constraints,
    graphviz_out_neighbors: materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: materialized.graphviz_in_neighbors,
    order_edges_out: materialized.order_edges_out,
    order_edge_tail_out: materialized.order_edge_tail_out,
    order_edge_head_out: materialized.order_edge_head_out,
    order_edge_tail_port_x: materialized.order_edge_tail_port_x,
    order_edge_head_port_x: materialized.order_edge_head_port_x,
    order_edge_tail_port_order: materialized.order_edge_tail_port_order,
    order_edge_head_port_order: materialized.order_edge_head_port_order,
    order_edges_out_unmapped: materialized.order_edges_out_unmapped,
    order_edge_tail_out_unmapped: materialized.order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped: materialized.order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped: materialized.order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped: materialized.order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped: materialized.order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped: materialized.order_edge_head_port_order_unmapped,
    ordered_with_vnodes,
  }
}


///|
/// Graphviz parity: pre-root payload forwarding into root+cluster build_ranks
/// keeps reorder/materialized field mapping in Graphviz stage-call order.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_from_pre_root_payload(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  pre_root_stage : OrderClusteredPreRootStageData,
  reorder_context : OrderReorderContext,
  materialized : OrderMaterializationData,
) -> OrderRootClusterStageData {
  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  let stage_inputs =
    build_root_and_cluster_build_ranks_stage_inputs_from_pre_root_payload(
      pre_root_stage,
      reorder_context,
      materialized,
      ordered_with_vnodes,
    )
  run_root_and_cluster_build_ranks_stage(
    order_with_clusters,
    order_with_vnodes,
    graph,
    cluster_meta,
    vnode_order_keys_for_ordering,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    flat_rank_constraints,
    ranks,
    vnode_info,
    stage_inputs,
  )
}


///|
/// Graphviz parity: root + cluster build_ranks stage reads clustered pre-root
/// context directly and forwards unchanged ordering/materialized maps.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_from_pre_root(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
  run_root_and_cluster_build_ranks_stage_from_pre_root_payload(
    order_with_clusters,
    order_with_vnodes,
    graph,
    cluster_meta,
    vnode_order_keys_for_ordering,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    flat_rank_constraints,
    ranks,
    vnode_info,
    pre_root_stage,
    reorder_context,
    materialized,
  )
}


///|
/// Graphviz parity: finalize-stage inputs are read directly from pre-root/root
/// stage payloads without reordering before clustered cleanup dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_finalize_stage_inputs_from_stages(
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (
  Array[Int],
  Map[Int, Array[String]],
  Map[String, String],
  Map[String, Bool],
  Map[String, NodeSize],
  Map[Int, Array[String]],
  Map[Int, Array[String]],
  Array[String],
) {
  let reorder_context = pre_root_stage.reorder_context
  (
    reorder_context.order_rank_keys,
    root_cluster_stage.order_groups_for_mincross,
    pre_root_stage.order_cluster_keys,
    pre_root_stage.order_cluster_skeleton,
    pre_root_stage.order_sizes_out,
    root_cluster_stage.ordered,
    root_cluster_stage.ordered_with_vnodes,
    reorder_context.creation_order,
  )
}


///|
/// Graphviz parity: clustered finalize dispatch context forwards typed payload
/// into cluster rank-order + finalize stage without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_from_stage_inputs_with_dispatch_context(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_order_and_finalize_stage(
    dispatch_context,
    stage_inputs,
  )
}


///|
/// Graphviz parity: clustered finalize-stage tuple output is unpacked into
/// named fields before forwarding to final cluster-rank-order dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_finalize_stage_inputs_from_stage_inputs_output(
  stage_inputs_output : (
    Array[Int],
    Map[Int, Array[String]],
    Map[String, String],
    Map[String, Bool],
    Map[String, NodeSize],
    Map[Int, Array[String]],
    Map[Int, Array[String]],
    Array[String],
  ),
) -> ClusterFinalizeStageInputs {
  let (
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_sizes_out,
    ordered,
    ordered_with_vnodes,
    creation_order,
  ) = stage_inputs_output
  {
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_sizes_out,
    ordered,
    ordered_with_vnodes,
    creation_order,
  }
}


///|
/// Graphviz parity: clustered finalize pre-root output dispatch consumes a
/// typed finalize context and stage tuple without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_from_pre_root_with_stage_inputs_output(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs_output : (
    Array[Int],
    Map[Int, Array[String]],
    Map[String, String],
    Map[String, Bool],
    Map[String, NodeSize],
    Map[Int, Array[String]],
    Map[Int, Array[String]],
    Array[String],
  ),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let stage_inputs =
    build_cluster_finalize_stage_inputs_from_stage_inputs_output(
      stage_inputs_output,
    )
  run_cluster_rank_order_and_finalize_stage_from_stage_inputs_with_dispatch_context(
    dispatch_context,
    stage_inputs,
  )
}


///|
/// Graphviz parity: clustered finalize stage consumes root/pre-root outputs
/// without argument reordering before final cluster ReMincross.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_from_pre_root(
  dispatch_context : ClusterFinalizePassDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let stage_inputs_output =
    build_cluster_finalize_stage_inputs_from_stages(
      pre_root_stage,
      root_cluster_stage,
    )
  run_cluster_rank_order_and_finalize_stage_from_pre_root_with_stage_inputs_output(
    dispatch_context,
    stage_inputs_output,
  )
}


///|
/// Graphviz parity: clustered pre-root/root stage output keeps stage tuple
/// ordering unchanged before clustered finalize-phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_pre_root_and_root_stage_output(
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (OrderClusteredPreRootStageData, OrderRootClusterStageData) {
  (pre_root_stage, root_cluster_stage)
}

///|
/// Graphviz parity: clustered ordering root+cluster build_ranks phase consumes
/// pre-root stage payload unchanged before finalize-stage dispatch.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_root_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_from_pre_root(
    order_with_clusters,
    order_with_vnodes,
    graph,
    cluster_meta,
    vnode_order_keys_for_ordering,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    flat_rank_constraints,
    ranks,
    vnode_info,
    pre_root_stage,
  )
}

///|
/// Graphviz parity: clustered ordering pre-root phase constructs reorder
/// context/materialized payload from ordering base inputs before root phase.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_pre_root_phase(
  nodes : Array[@cgraph.Node],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  cluster_meta : ClusterMetadata,
  real_nodes : Map[String, Bool],
  port_edge_nodes : Map[String, Bool],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
) -> OrderClusteredPreRootStageData {
  let pre_root_stage_context : ClusteredOrderingPreRootStageContext = {
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    order_sizes,
    nlist_order,
    gdnlist_order,
    node_order,
    real_nodes,
    port_edge_nodes,
    order_edges_by_tail,
    order_edges_by_tail_unmapped,
    edge_creation_order,
    edge_tail,
    edge_head,
    nodes,
  }
  build_clustered_ordering_pre_root_stage(pre_root_stage_context)
}


///|
/// Graphviz parity: clustered ordering pre-root/root stage output dispatch
/// reads root-phase output and preserves Graphviz tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_output_phase_from_root_phase_output(
  pre_root_stage : OrderClusteredPreRootStageData,
  root_phase_output : OrderRootClusterStageData,
) -> (OrderClusteredPreRootStageData, OrderRootClusterStageData) {
  build_clustered_ordering_pre_root_and_root_stage_output(
    pre_root_stage,
    root_phase_output,
  )
}

///|
/// Graphviz parity: clustered ordering pre-root phase dispatch reads typed
/// stage context fields and preserves Graphviz pre-root call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_pre_root_phase_from_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
) -> OrderClusteredPreRootStageData {
  run_clustered_ordering_pre_root_and_root_stage_pre_root_phase(
    phase_context.nodes,
    phase_context.edge_tail,
    phase_context.edge_head,
    phase_context.node_order,
    phase_context.order_sizes,
    phase_context.cluster_meta,
    phase_context.runtime_context.real_nodes,
    phase_context.runtime_context.port_edge_nodes,
    phase_context.reorder_setup.order_with_vnodes,
    phase_context.reorder_setup.order_with_clusters,
    phase_context.reorder_setup.ordering_groups_base,
    phase_context.reorder_setup.base_order_index,
    phase_context.runtime_context.vnode_info,
    phase_context.reorder_setup.vnode_order_keys_for_ordering,
    phase_context.class2_data.nlist_order,
    phase_context.reorder_setup.gdnlist_order,
    phase_context.class2_data.order_edges_by_tail,
    phase_context.class2_data.order_edges_by_tail_unmapped,
    phase_context.class2_data.edge_creation_order,
  )
}

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_root_phase_from_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  run_clustered_ordering_pre_root_and_root_stage_root_phase(
    phase_context.reorder_setup.order_with_clusters,
    phase_context.reorder_setup.order_with_vnodes,
    phase_context.graph,
    phase_context.cluster_meta,
    phase_context.reorder_setup.vnode_order_keys_for_ordering,
    phase_context.nodesep_pt,
    phase_context.has_edge_labels,
    phase_context.port_order_positions,
    phase_context.port_order_contrib,
    phase_context.reorder_setup.graphviz_flip,
    phase_context.reorder_setup.flat_rank_constraints,
    phase_context.ranks,
    phase_context.runtime_context.vnode_info,
    pre_root_stage,
  )
}

///|
/// Graphviz parity: clustered ordering pre-root/root phase execution preserves
/// Graphviz phase boundaries while forwarding through typed stage context.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_from_phase_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
) -> (OrderClusteredPreRootStageData, OrderRootClusterStageData) {
  let pre_root_stage =
    run_clustered_ordering_pre_root_and_root_stage_pre_root_phase_from_context(
      phase_context,
    )
  let root_phase_output =
    run_clustered_ordering_pre_root_and_root_stage_root_phase_from_context(
      phase_context,
      pre_root_stage,
    )
  run_clustered_ordering_pre_root_and_root_stage_output_phase_from_root_phase_output(
    pre_root_stage,
    root_phase_output,
  )
}

///|
/// Graphviz parity: clustered ordering finalize-phase forwarding keeps stage
/// payloads and rank-order inputs in Graphviz finalize-call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_finalize_phase_finalize_pass(
  dispatch_context : ClusterFinalizePassDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_order_and_finalize_stage_from_pre_root(
    dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
}

///|
/// Graphviz parity: clustered ordering finalize-stage output dispatch reads
/// finalize-pass tuple and preserves Graphviz tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_finalize_phase_output_from_finalize_pass_output(
  finalize_pass_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (next_ordered_with_vnodes, final_groups) = finalize_pass_output
  build_clustered_ordering_stage_output(next_ordered_with_vnodes, final_groups)
}


///|
/// Graphviz parity: clustered ordering finalize dispatch context preserves
/// finalize-stage payload ordering before cluster-rank-order execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_finalize_dispatch_context(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  local_cluster_order : Map[String, Int],
  graph : @cgraph.Graph,
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  edges_by_tail : Map[String, Array[Int]],
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
) -> ClusterFinalizePassDispatchContext {
  {
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    nlist_order,
    ranks,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    local_cluster_order,
    graph,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    edges_by_tail,
    order_sizes,
    rank_same_constraints,
  }
}

///|
/// Graphviz parity: clustered ordering finalize phase consumes pre-root/root
/// stage data before running cluster-rank-order + final ReMincross cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_finalize_phase(
  dispatch_context : ClusterFinalizePassDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let finalize_pass_output =
    run_clustered_ordering_finalize_phase_finalize_pass(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage,
    )
  run_clustered_ordering_finalize_phase_output_from_finalize_pass_output(
    finalize_pass_output,
  )
}


///|
/// Graphviz parity: clustered ordering stage forwards pre-root/root phase
/// outputs unchanged into finalize-phase clustered cleanup dispatch.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_from_phase_context(
  dispatch_context : ClusterFinalizePassDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_ordering_finalize_phase(
    dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
}

///|
/// Graphviz parity: clustered ordering pre-root/root phase context builder
/// preserves stage setup payload ordering before phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_pre_root_and_root_phase_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  reorder_setup : OrderingReorderSetup,
  class2_data : OrderingClass2Data,
) -> ClusteredOrderingPreRootAndRootPhaseContext {
  {
    graph,
    nodes,
    edge_tail,
    edge_head,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    reorder_setup,
    class2_data,
  }
}

///|
/// Graphviz parity: clustered ordering stage first computes pre-root/root phase
/// context and forwards the untouched stage tuple into finalize-phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_pre_root_and_root_phase(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
) -> (OrderClusteredPreRootStageData, OrderRootClusterStageData) {
  run_clustered_ordering_pre_root_and_root_stage_from_phase_context(
    phase_context,
  )
}

///|
/// Graphviz parity: clustered ordering finalize phase consumes pre-root/root
/// stage tuple and forwards unchanged payload into finalize dispatch helper.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_finalize_phase_from_stage_tuple(
  dispatch_context : ClusterFinalizePassDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_ordering_stage_from_phase_context(
    dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
}


///|
/// Graphviz parity: clustered ordering finalize dispatch unpacks pre-root/root
/// stage tuple and forwards payload to finalize-phase helper unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_finalize_phase_from_stage_output(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_output : (OrderClusteredPreRootStageData, OrderRootClusterStageData),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (pre_root_stage, root_cluster_stage) = stage_output
  run_clustered_ordering_stage_finalize_phase_from_stage_tuple(
    dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
}


///|
/// Graphviz parity: clustered ordering pre-root/root stage dispatch reads
/// typed runtime/reorder payloads and forwards Graphviz call ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_pre_root_and_root_phase_output_from_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
) -> (OrderClusteredPreRootStageData, OrderRootClusterStageData) {
  run_clustered_ordering_stage_pre_root_and_root_phase(phase_context)
}


///|
/// Graphviz parity: clustered ordering finalize output dispatch-context
/// builder preserves finalize-phase payload ordering before stage output run.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_output_phase_dispatch_context(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  edge_port_data : OrderingEdgePortData,
  reorder_setup : OrderingReorderSetup,
  class2_data : OrderingClass2Data,
) -> ClusterFinalizePassDispatchContext {
  build_clustered_ordering_finalize_dispatch_context(
    reorder_setup.order_with_clusters,
    reorder_setup.order_with_vnodes,
    reorder_setup.graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    class2_data.nlist_order,
    ranks,
    class2_data.order_edges_by_tail_root,
    class2_data.skeleton_edge_creation,
    class2_data.root_edge_creation,
    reorder_setup.flat_rank_constraints,
    cluster_meta,
    runtime_context.vnode_info,
    reorder_setup.vnode_order_keys_for_ordering,
    runtime_context.real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    runtime_context.local_cluster_order,
    graph,
    edge_port_data.edge_tail_port_x,
    edge_port_data.edge_head_port_x,
    edge_port_data.edge_tail_port_order,
    edge_port_data.edge_head_port_order,
    class2_data.edges_by_tail,
    order_sizes,
    runtime_context.rank_same_constraints,
  )
}

///|
/// Graphviz parity: clustered ordering finalize output dispatch reads typed
/// stage/context payloads and preserves Graphviz finalize call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_output_phase_from_stage_output(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_output : (OrderClusteredPreRootStageData, OrderRootClusterStageData),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_ordering_stage_finalize_phase_from_stage_output(
    dispatch_context,
    stage_output,
  )
}


///|
/// Graphviz parity: clustered ordering stage dispatch context builder keeps
/// full clustered stage payload ordering unchanged before stage execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_dispatch_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  edge_port_data : OrderingEdgePortData,
  reorder_setup : OrderingReorderSetup,
  class2_data : OrderingClass2Data,
) -> ClusteredOrderingStageDispatchContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    edge_port_data,
    reorder_setup,
    class2_data,
  }
}

///|
/// Graphviz parity: clustered ordering pre-root/root phase context extraction
/// reads stage dispatch fields without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_pre_root_and_root_phase_context_from_dispatch_context(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
) -> ClusteredOrderingPreRootAndRootPhaseContext {
  build_clustered_ordering_stage_pre_root_and_root_phase_context(
    stage_dispatch_context.graph,
    stage_dispatch_context.nodes,
    stage_dispatch_context.edge_tail,
    stage_dispatch_context.edge_head,
    stage_dispatch_context.ranks,
    stage_dispatch_context.node_order,
    stage_dispatch_context.order_sizes,
    stage_dispatch_context.nodesep_pt,
    stage_dispatch_context.has_edge_labels,
    stage_dispatch_context.cluster_meta,
    stage_dispatch_context.port_order_positions,
    stage_dispatch_context.port_order_contrib,
    stage_dispatch_context.runtime_context,
    stage_dispatch_context.reorder_setup,
    stage_dispatch_context.class2_data,
  )
}

///|
/// Graphviz parity: clustered ordering finalize dispatch context extraction
/// reads stage dispatch payloads without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_output_phase_dispatch_context_from_dispatch_context(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
) -> ClusterFinalizePassDispatchContext {
  build_clustered_ordering_stage_output_phase_dispatch_context(
    stage_dispatch_context.graph,
    stage_dispatch_context.edges,
    stage_dispatch_context.edge_tail,
    stage_dispatch_context.edge_head,
    stage_dispatch_context.edge_reversed,
    stage_dispatch_context.ranks,
    stage_dispatch_context.order_sizes,
    stage_dispatch_context.nodesep_pt,
    stage_dispatch_context.has_edge_labels,
    stage_dispatch_context.cluster_meta,
    stage_dispatch_context.port_order_positions,
    stage_dispatch_context.port_order_contrib,
    stage_dispatch_context.runtime_context,
    stage_dispatch_context.edge_port_data,
    stage_dispatch_context.reorder_setup,
    stage_dispatch_context.class2_data,
  )
}

///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let phase_context =
    build_clustered_ordering_stage_pre_root_and_root_phase_context_from_dispatch_context(
      stage_dispatch_context,
    )
  let stage_output =
    run_clustered_ordering_stage_pre_root_and_root_phase_output_from_context(
      phase_context,
    )
  let finalize_dispatch_context =
    build_clustered_ordering_stage_output_phase_dispatch_context_from_dispatch_context(
      stage_dispatch_context,
    )
  run_clustered_ordering_stage_output_phase_from_stage_output(
    finalize_dispatch_context,
    stage_output,
  )
}


///|
/// Graphviz parity: clustered ordering stage returns finalized groups and
/// vnode-augmented groups with Graphviz tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (final_groups, next_ordered_with_vnodes)
}

///|
/// Graphviz parity: non-clustered ordering stage returns mincross groups plus
/// an empty vnode map (matching Graphviz no-vnode ordering path).
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_ordering_stage_output(
  ordered_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  (ordered_groups, ordered_with_vnodes)
}

///|
/// Graphviz parity: non-clustered ordering path still runs the single mincross
/// pass directly (matching Graphviz control flow).
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_ordering_stage_dispatch_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> NonclusterOrderingStageDispatchContext {
  {
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    rank_keys,
    groups,
    nlist_order,
    node_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    cluster_meta,
    edge_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  }
}

///|
/// Graphviz parity: non-clustered ordering path still runs the single mincross
/// pass directly (matching Graphviz control flow).
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_ordering_stage(
  dispatch_context : NonclusterOrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let ordered_groups =
    run_noncluster_reorder_pass(
      dispatch_context.nodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_out_order,
      dispatch_context.ranks,
      dispatch_context.rank_keys,
      dispatch_context.groups,
      dispatch_context.nlist_order,
      dispatch_context.node_order,
      dispatch_context.order_edges,
      dispatch_context.order_edge_tail,
      dispatch_context.order_edge_head,
      dispatch_context.order_edge_tail_port_x,
      dispatch_context.order_edge_head_port_x,
      dispatch_context.order_edge_tail_port_order,
      dispatch_context.order_edge_head_port_order,
      dispatch_context.cluster_meta,
      dispatch_context.edge_order,
      dispatch_context.order_sizes,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      dispatch_context.graphviz_flip,
    )
  build_noncluster_ordering_stage_output(ordered_groups)
}

///|
/// Graphviz parity: dispatch setup fields are unpacked once and forwarded with
/// unchanged ordering into clustered/non-clustered stage dispatch helpers.
/// Do not change behavior without updating fixtures/tests.
fn unpack_ordering_dispatch_setup(
  dispatch_setup : OrderingDispatchSetup,
) -> (OrderingEdgePortData, OrderingReorderSetup, OrderingClass2Data) {
  let edge_port_data = dispatch_setup.edge_port_data
  let reorder_setup = dispatch_setup.reorder_setup
  let class2_data = reorder_setup.class2_data
  (edge_port_data, reorder_setup, class2_data)
}


///|
/// Graphviz parity: clustered dispatch path reads ordering inputs from a
/// shared stage-dispatch context and forwards them without reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_from_context(
  dispatch_context : OrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (edge_port_data, reorder_setup, class2_data) =
    unpack_ordering_dispatch_setup(dispatch_context.dispatch_setup)
  let clustered_dispatch_context =
    build_clustered_ordering_stage_dispatch_context(
      dispatch_context.graph,
      dispatch_context.nodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_reversed,
      dispatch_context.ranks,
      dispatch_context.node_order,
      dispatch_context.order_sizes,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.cluster_meta,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      dispatch_context.runtime_context,
      edge_port_data,
      reorder_setup,
      class2_data,
    )
  run_clustered_ordering_stage(clustered_dispatch_context)
}

///|
/// Graphviz parity: non-clustered dispatch path continues to run a single
/// mincross pass using the same stage-dispatch context payloads.
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_ordering_stage_from_context(
  dispatch_context : OrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (edge_port_data, reorder_setup, class2_data) =
    unpack_ordering_dispatch_setup(dispatch_context.dispatch_setup)
  let noncluster_dispatch_context =
    build_noncluster_ordering_stage_dispatch_context(
      dispatch_context.nodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_out_order,
      dispatch_context.ranks,
      dispatch_context.rank_keys,
      dispatch_context.groups,
      class2_data.nlist_order,
      dispatch_context.node_order,
      edge_port_data.order_edges,
      edge_port_data.order_edge_tail,
      edge_port_data.order_edge_head,
      edge_port_data.order_edge_tail_port_x,
      edge_port_data.order_edge_head_port_x,
      edge_port_data.order_edge_tail_port_order,
      edge_port_data.order_edge_head_port_order,
      dispatch_context.cluster_meta,
      edge_port_data.edge_order,
      dispatch_context.order_sizes,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      reorder_setup.graphviz_flip,
    )
  run_noncluster_ordering_stage(noncluster_dispatch_context)
}

///|
/// Graphviz parity: dispatch clustered ordering when vnode/cluster mode is
/// active, matching Graphviz mincross control gating.
/// Do not change behavior without updating fixtures/tests.
fn should_run_clustered_ordering_stage(
  reorder_setup : OrderingReorderSetup,
) -> Bool {
  reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters
}

///|
/// Graphviz parity: ordering-stage dispatch context builder preserves
/// clustered/non-clustered branch payload ordering before dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_stage_dispatch_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingStageDispatchContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    rank_keys,
    groups,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    dispatch_setup,
  }
}

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_stage_dispatch(
  dispatch_context : OrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_setup = dispatch_context.dispatch_setup.reorder_setup
  if should_run_clustered_ordering_stage(reorder_setup) {
    run_clustered_ordering_stage_from_context(dispatch_context)
  } else {
    run_noncluster_ordering_stage_from_context(dispatch_context)
  }
}


///|
/// Graphviz parity: final ordering result output object maps ordering arrays,
/// vnode metadata, and edge-port-derived edge order fields unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result_output(
  ordered_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  vnode_info : EdgeVnodeInfo,
  vnode_count : Int,
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  edge_order : Map[String, Int],
  edge_cluster_keys : Map[String, String],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> OrderingResult {
  {
    ordered_groups,
    ordered_groups_with_vnodes,
    vnode_info,
    vnode_count,
    order_edges,
    order_edge_tail,
    order_edge_head,
    edge_order,
    edge_cluster_keys,
    nlist_order,
    gdnlist_order,
    vnode_creation_order,
  }
}

///|
/// Graphviz parity: final ordering result must keep the exact arrays/maps produced
/// by ordering stages for downstream xpos/routing parity checks.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result(
  ordered_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  vnode_info : EdgeVnodeInfo,
  vnode_count : Int,
  edge_port_data : OrderingEdgePortData,
  edge_cluster_keys : Map[String, String],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> OrderingResult {
  build_ordering_result_output(
    ordered_groups,
    ordered_groups_with_vnodes,
    vnode_info,
    vnode_count,
    edge_port_data.order_edges,
    edge_port_data.order_edge_tail,
    edge_port_data.order_edge_head,
    edge_port_data.edge_order,
    edge_cluster_keys,
    nlist_order,
    gdnlist_order,
    vnode_creation_order,
  )
}

///|
/// Graphviz parity: ordering dispatch result mapping keeps runtime-context and
/// dispatch-setup arrays wired into OrderingResult without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_result(
  ordered_groups_internal : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  runtime_context : OrderingRuntimeContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingResult {
  build_ordering_result(
    ordered_groups_internal,
    ordered_with_vnodes,
    runtime_context.vnode_info,
    runtime_context.vnode_count,
    dispatch_setup.edge_port_data,
    runtime_context.edge_cluster_keys,
    dispatch_setup.nlist_order,
    dispatch_setup.gdnlist_order,
    dispatch_setup.vnode_creation_order,
  )
}

///|
/// Graphviz parity: dispatch setup uses runtime-context vnode/port fields in the
/// same order as Graphviz pre-microstep staging.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup_from_runtime_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchSetup {
  let setup_context : OrderingDispatchSetupContext = {
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    node_order,
    order_sizes,
    port_edge_nodes: runtime_context.port_edge_nodes,
    vnode_count: runtime_context.vnode_count,
    rankdir,
    cluster_meta,
    vnode_info: runtime_context.vnode_info,
  }
  build_ordering_dispatch_setup(setup_context)
}

///|
/// Graphviz parity: stage-dispatch context extraction reads execution payloads
/// without argument reordering before ordering stage dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_stage_dispatch_context_from_execution_context(
  execution_context : OrderingDispatchPipelineExecutionContext,
) -> OrderingStageDispatchContext {
  build_ordering_stage_dispatch_context(
    execution_context.graph,
    execution_context.nodes,
    execution_context.edges,
    execution_context.edge_tail,
    execution_context.edge_head,
    execution_context.edge_reversed,
    execution_context.edge_out_order,
    execution_context.ranks,
    execution_context.rank_keys,
    execution_context.groups,
    execution_context.node_order,
    execution_context.order_sizes,
    execution_context.nodesep_pt,
    execution_context.has_edge_labels,
    execution_context.cluster_meta,
    execution_context.port_order_positions,
    execution_context.port_order_contrib,
    execution_context.runtime_context,
    execution_context.dispatch_setup,
  )
}

///|
/// Graphviz parity: ordering dispatch stage forwards setup/runtime context
/// into clustered/non-clustered stage dispatch without argument reshuffling.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline_stage_dispatch_phase(
  execution_context : OrderingDispatchPipelineExecutionContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let stage_dispatch_context =
    build_ordering_stage_dispatch_context_from_execution_context(
      execution_context,
    )
  run_ordering_stage_dispatch(stage_dispatch_context)
}

///|
/// Graphviz parity: ordering-dispatch execution context builder preserves
/// stage-dispatch payload ordering before execution-phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_execution_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingDispatchPipelineExecutionContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    rank_keys,
    groups,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    dispatch_setup,
  }
}


///|
/// Graphviz parity: ordering dispatch execution phase consumes prepared
/// dispatch setup, then maps staged outputs into OrderingResult unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline_execution_phase(
  execution_context : OrderingDispatchPipelineExecutionContext,
) -> OrderingResult {
  let (ordered_groups_internal, ordered_with_vnodes) =
    run_ordering_dispatch_pipeline_stage_dispatch_phase(execution_context)
  build_ordering_dispatch_pipeline_result(
    ordered_groups_internal,
    ordered_with_vnodes,
    execution_context.runtime_context,
    execution_context.dispatch_setup,
  )
}


///|
/// Graphviz parity: ordering-dispatch pipeline context builder preserves
/// ordering/runtime payload ordering before pipeline execution.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchPipelineContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    rankdir,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
  }
}


///|
/// Graphviz parity: ordering dispatch setup extraction reads pipeline context
/// payloads without argument reordering before setup build.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup_from_pipeline_context(
  pipeline_context : OrderingDispatchPipelineContext,
) -> OrderingDispatchSetup {
  build_ordering_dispatch_setup_from_runtime_context(
    pipeline_context.nodes,
    pipeline_context.edges,
    pipeline_context.edge_tail,
    pipeline_context.edge_head,
    pipeline_context.edge_reversed,
    pipeline_context.edge_out_order,
    pipeline_context.ranks,
    pipeline_context.groups,
    pipeline_context.node_order,
    pipeline_context.order_sizes,
    pipeline_context.rankdir,
    pipeline_context.cluster_meta,
    pipeline_context.runtime_context,
  )
}

///|
/// Graphviz parity: ordering dispatch execution-context extraction reads
/// pipeline context + dispatch setup without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_execution_context_from_pipeline_context(
  pipeline_context : OrderingDispatchPipelineContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingDispatchPipelineExecutionContext {
  build_ordering_dispatch_pipeline_execution_context(
    pipeline_context.graph,
    pipeline_context.nodes,
    pipeline_context.edges,
    pipeline_context.edge_tail,
    pipeline_context.edge_head,
    pipeline_context.edge_reversed,
    pipeline_context.edge_out_order,
    pipeline_context.ranks,
    pipeline_context.rank_keys,
    pipeline_context.groups,
    pipeline_context.node_order,
    pipeline_context.order_sizes,
    pipeline_context.nodesep_pt,
    pipeline_context.has_edge_labels,
    pipeline_context.cluster_meta,
    pipeline_context.port_order_positions,
    pipeline_context.port_order_contrib,
    pipeline_context.runtime_context,
    dispatch_setup,
  )
}

///|
/// Graphviz parity: ordering dispatch pipeline keeps setup/dispatch/result stages
/// in Graphviz-equivalent sequence while using structured runtime context.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline(
  pipeline_context : OrderingDispatchPipelineContext,
) -> OrderingResult {
  let dispatch_setup =
    build_ordering_dispatch_setup_from_pipeline_context(pipeline_context)
  let execution_context =
    build_ordering_dispatch_pipeline_execution_context_from_pipeline_context(
      pipeline_context,
      dispatch_setup,
    )
  run_ordering_dispatch_pipeline_execution_phase(execution_context)
}


///|
/// Graphviz parity: ordering dispatch pipeline context extraction reads
/// ordering-stage inputs + runtime context without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_context_from_ordering_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchPipelineContext {
  build_ordering_dispatch_pipeline_context(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    rankdir,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
  )
}


///|
/// Graphviz parity: ordering runtime-context extraction reads ordering inputs
/// without argument reordering before runtime-context assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context_from_ordering_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  build_ordering_runtime_context_with_tail_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    node_order,
    nodesep_pt,
    rankdir,
    cluster_meta,
  )
}


///|
/// Graphviz parity: ordering+vnode input payload assembly reads ordering stage
/// inputs without argument reordering before runtime/pipeline dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_and_vnodes_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> OrderingAndVnodesInputs {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    rankdir,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
  }
}

///|
/// Graphviz parity: runtime-context extraction from ordering+vnode payload
/// reads typed inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context_from_ordering_and_vnodes_inputs(
  ordering_inputs : OrderingAndVnodesInputs,
) -> OrderingRuntimeContext {
  build_ordering_runtime_context_from_ordering_inputs(
    ordering_inputs.graph,
    ordering_inputs.nodes,
    ordering_inputs.edges,
    ordering_inputs.edge_tail,
    ordering_inputs.edge_head,
    ordering_inputs.edge_out_order,
    ordering_inputs.ranks,
    ordering_inputs.node_order,
    ordering_inputs.nodesep_pt,
    ordering_inputs.rankdir,
    ordering_inputs.cluster_meta,
  )
}

///|
/// Graphviz parity: dispatch-pipeline context extraction from ordering+vnode
/// payload keeps field ordering unchanged before pipeline execution.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_context_from_ordering_and_vnodes_inputs(
  ordering_inputs : OrderingAndVnodesInputs,
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchPipelineContext {
  build_ordering_dispatch_pipeline_context_from_ordering_inputs(
    ordering_inputs.graph,
    ordering_inputs.nodes,
    ordering_inputs.edges,
    ordering_inputs.edge_tail,
    ordering_inputs.edge_head,
    ordering_inputs.edge_reversed,
    ordering_inputs.edge_out_order,
    ordering_inputs.ranks,
    ordering_inputs.groups,
    ordering_inputs.rank_keys,
    ordering_inputs.node_order,
    ordering_inputs.order_sizes,
    ordering_inputs.nodesep_pt,
    ordering_inputs.has_edge_labels,
    ordering_inputs.rankdir,
    ordering_inputs.cluster_meta,
    ordering_inputs.port_order_positions,
    ordering_inputs.port_order_contrib,
    runtime_context,
  )
}

///|
/// Graphviz parity: ordering+vnode execution consumes typed input payload and
/// preserves runtime-context + dispatch-pipeline stage ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_compute_ordering_and_vnodes_from_inputs(
  ordering_inputs : OrderingAndVnodesInputs,
) -> OrderingResult {
  let runtime_context =
    build_ordering_runtime_context_from_ordering_and_vnodes_inputs(
      ordering_inputs,
    )
  let pipeline_context =
    build_ordering_dispatch_pipeline_context_from_ordering_and_vnodes_inputs(
      ordering_inputs,
      runtime_context,
    )
  run_ordering_dispatch_pipeline(pipeline_context)
}

///|
/// Graphviz parity: ordering + vnode expansion aligned to refs/graphviz/lib/dotgen/mincross.c + dotgen/flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_ordering_and_vnodes(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> OrderingResult {
  let ordering_inputs =
    build_ordering_and_vnodes_inputs(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      groups,
      rank_keys,
      node_order,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      rankdir,
      cluster_meta,
      port_order_positions,
      port_order_contrib,
    )
  run_compute_ordering_and_vnodes_from_inputs(ordering_inputs)
}

///|
/// Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_boundary_x_positions(
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  x_positions : Map[String, Double],
) -> (Map[String, Double], Map[String, Double]) {
  let cluster_ln_x : Map[String, Double] = Map::new()
  let cluster_rn_x : Map[String, Double] = Map::new()
  if cluster_meta.has_clusters {
    let cluster_names : Map[String, Bool] = Map::new()
    collect_cluster_names(graph, cluster_names)
    if cluster_names.length() > 0 {
      for name, pos_x in x_positions {
        if name.has_prefix(CLUSTER_LN_PREFIX) ||
          name.has_prefix(CLUSTER_RN_PREFIX) {
          match cluster_key_from_boundary_name(name, cluster_names) {
            Some(cluster_key) =>
              if name.has_prefix(CLUSTER_LN_PREFIX) {
                cluster_ln_x[cluster_key] = pos_x
              } else {
                cluster_rn_x[cluster_key] = pos_x
              }
            None => ()
          }
        }
      }
    }
  }
  (cluster_ln_x, cluster_rn_x)
}

///|
/// Graphviz parity: vnode output positions are either direct xpos/rank pairs
/// (when xpos consumed vnode graph) or endpoint-interpolated fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_positions_for_output(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  x_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> Map[String, @geom.Point] {
  if use_vnodes_for_xpos {
    let positions : Map[String, @geom.Point] = Map::new()
    for name, rank in ordering.vnode_info.vnode_ranks {
      let pos_x = match x_positions.get(name) {
        Some(value) => value
        None => 0.0
      }
      let pos_y = match rank_y.get(rank) {
        Some(value) => value
        None => 0.0
      }
      positions[name] = { x: pos_x, y: pos_y }
    }
    positions
  } else {
    vnode_positions_from_endpoints(
      prep.edges,
      rank_data.ranks,
      ordering.vnode_info.vnode_ranks,
      ordering.vnode_info.edge_vnodes,
      x_positions,
      rank_y,
    )
  }
}

///|
/// Graphviz parity: initial x-groups must preserve vnode-aware ordering and
/// strip cluster skeleton placeholders before xpos constraints run.
/// Do not change behavior without updating fixtures/tests.
fn build_initial_x_groups(
  use_vnodes_for_xpos : Bool,
  ordered_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  order_index : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys : Map[String, Double],
  cluster_meta : ClusterMetadata,
) -> Map[Int, Array[String]] {
  let mut x_groups =
    if use_vnodes_for_xpos {
      if ordered_groups_with_vnodes.length() > 0 {
        clone_rank_groups(ordered_groups_with_vnodes)
      } else {
        build_x_groups_with_vnodes(
          ordered_groups,
          order_index,
          vnodes_by_rank,
          vnode_order_keys,
        )
      }
    } else {
      ordered_groups
    }
  if cluster_meta.has_clusters {
    let cleaned : Map[Int, Array[String]] = Map::new()
    for rank, names in x_groups {
      let filtered : Array[String] = []
      for name in names {
        if cluster_key_from_skeleton_name(name) is None {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        cleaned[rank] = filtered
      }
    }
    x_groups = cleaned
  }
  x_groups
}

///|
/// Graphviz parity: xpos cluster ownership map starts from real cluster keys,
/// then overlays vnode cluster keys only when vnode xpos path is enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_x_cluster_keys_for_positions(
  cluster_meta : ClusterMetadata,
  use_vnodes_for_xpos : Bool,
  vnode_clusters : Map[String, String],
) -> Map[String, String] {
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_meta.cluster_keys {
    x_cluster_keys[name] = key
  }
  if use_vnodes_for_xpos {
    for name, key in vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  x_cluster_keys
}

///|
/// Graphviz parity: x-stage seed output object maps vnode-order probe result,
/// edge-port metadata, and prepared groups/cluster keys without remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_x_position_stage_seed_output_for_positions(
  has_vnode_order : Bool,
  x_order_edge_port_data : XposOrderEdgePortData,
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
) -> XPositionStageSeedData {
  {
    has_vnode_order,
    x_base_sizes: x_order_edge_port_data.x_base_sizes,
    x_order_sizes: x_order_edge_port_data.x_order_sizes,
    x_edge_tail_port_x: x_order_edge_port_data.x_edge_tail_port_x,
    x_edge_head_port_x: x_order_edge_port_data.x_edge_head_port_x,
    x_edge_tail_port_order: x_order_edge_port_data.x_edge_tail_port_order,
    x_edge_head_port_order: x_order_edge_port_data.x_edge_head_port_order,
    x_groups,
    x_cluster_keys,
  }
}

///|
/// Graphviz parity: x-stage seed group/cluster maps derive from initial x
/// groups and vnode-aware cluster-key overlays without remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_seed_group_and_cluster_data_for_positions(
  use_vnodes_for_xpos : Bool,
  ordering : OrderingResult,
  order_index : Map[String, Int],
  vnode_order_keys : Map[String, Double],
  cluster_meta : ClusterMetadata,
) -> XStageSeedGroupAndClusterData {
  let x_groups =
    build_initial_x_groups(
      use_vnodes_for_xpos,
      ordering.ordered_groups,
      ordering.ordered_groups_with_vnodes,
      order_index,
      ordering.vnode_info.vnodes_by_rank,
      vnode_order_keys,
      cluster_meta,
    )
  let x_cluster_keys =
    build_x_cluster_keys_for_positions(
      cluster_meta,
      use_vnodes_for_xpos,
      ordering.vnode_info.vnode_clusters,
    )
  { x_groups, x_cluster_keys }
}

///|
/// Graphviz parity: x-stage seed order-index and vnode-order probe are derived
/// before seed group/cluster maps and edge-port metadata assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_seed_order_and_vnode_data_for_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XStageSeedOrderAndVNodeData {
  let order_index = build_order_index(ordering.ordered_groups)
  let vnode_order_state =
    build_vnode_order_state_for_positions(
      use_vnodes_for_xpos,
      ordering.ordered_groups_with_vnodes,
      prep,
      rank_data,
      order_index,
      cluster_meta,
      ordering,
    )
  { order_index, vnode_order_state }
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build, vnode
/// order probing, edge-port metadata, and initial group/cluster maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_position_stage_seed_data_for_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XPositionStageSeedData {
  let seed_order_vnode_data =
    build_x_stage_seed_order_and_vnode_data_for_positions(
      use_vnodes_for_xpos,
      prep,
      rank_data,
      cluster_meta,
      ordering,
    )
  let has_vnode_order =
    seed_order_vnode_data.vnode_order_state.has_vnode_order
  let x_order_edge_port_data =
    build_x_order_edge_port_data_for_positions(
      use_vnodes_for_xpos,
      prep,
      rank_data,
      ordering,
    )
  let x_stage_seed_group_cluster_data =
    build_x_stage_seed_group_and_cluster_data_for_positions(
      use_vnodes_for_xpos,
      ordering,
      seed_order_vnode_data.order_index,
      seed_order_vnode_data.vnode_order_state.vnode_order_keys,
      cluster_meta,
    )
  build_x_position_stage_seed_output_for_positions(
    has_vnode_order,
    x_order_edge_port_data,
    x_stage_seed_group_cluster_data.x_groups,
    x_stage_seed_group_cluster_data.x_cluster_keys,
  )
}

///|
/// Graphviz parity: optional x-stage reorder preserves vnode-order gating,
/// port-order inputs, and trace emission before transpose cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_groups_after_optional_reorder_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  graphviz_flip : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_stage_seed : XPositionStageSeedData,
) -> Map[Int, Array[String]] {
  let x_groups =
    maybe_apply_xpos_reorder_for_positions(
      xpos_reorder_enabled,
      use_vnodes_for_xpos,
      allow_xpos_reorder,
      x_stage_seed.has_vnode_order,
      cluster_meta,
      prep,
      rank_data,
      rank_heights,
      ordering,
      x_stage_seed.x_order_sizes,
      x_stage_seed.x_cluster_keys,
      x_stage_seed.x_edge_tail_port_x,
      x_stage_seed.x_edge_head_port_x,
      x_stage_seed.x_edge_tail_port_order,
      x_stage_seed.x_edge_head_port_order,
      graphviz_flip,
      x_stage_seed.x_groups,
    )
  dot_trace_groups("x-groups", x_groups)
  x_groups
}

///|
/// Graphviz parity: x-stage reorder and transpose-cleanup are applied in
/// fixed order before flat-label augmentation consumes updated x_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_groups_after_reorder_and_cleanup_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  graphviz_flip : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_stage_seed : XPositionStageSeedData,
) -> Map[Int, Array[String]] {
  let x_groups =
    build_x_stage_groups_after_optional_reorder_for_positions(
      xpos_reorder_enabled,
      use_vnodes_for_xpos,
      allow_xpos_reorder,
      graphviz_flip,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_stage_seed,
    )
  maybe_apply_xpos_transpose_cleanup(
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    cluster_meta,
    prep.nodes,
    ordering,
    rank_data.ranks,
    x_groups,
  )
  x_groups
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_with_flat_label_augmentation_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  graphviz_flip : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_stage_seed : XPositionStageSeedData,
) -> XposFlatLabelAugmentation {
  let x_groups =
    build_x_stage_groups_after_reorder_and_cleanup_for_positions(
      xpos_reorder_enabled,
      use_vnodes_for_xpos,
      allow_xpos_reorder,
      graphviz_flip,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_stage_seed,
    )
  build_flat_label_vnode_augmentation_for_positions(
    use_vnodes_for_xpos,
    prep,
    rank_data,
    ordering,
    rank_heights,
    cluster_meta,
    x_stage_seed.x_base_sizes,
    x_groups,
    x_stage_seed.x_cluster_keys,
  )
}

///|
/// Graphviz parity: xpos solver inputs must preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_computation_input(
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  ordering : OrderingResult,
  virtual_slack_edges : Array[ConstraintEdge],
) -> XposComputationInput {
  let x_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let x_rank_keys = collect_rank_keys(x_groups)
  let x_ranks = build_node_ranks(x_groups)
  let vnode_extra_nodes =
    if use_vnodes_for_xpos {
      build_vnode_extra_nodes(
        ordering.vnode_creation_order,
        ordering.vnode_info.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if use_vnodes_for_xpos {
      ordering.vnode_info.edge_vnodes
    } else {
      Map::new()
    }
  let x_slack_edges =
    if use_vnodes_for_xpos {
      virtual_slack_edges
    } else {
      []
    }
  { x_sizes, x_rank_keys, x_ranks, x_extra_nodes, x_edge_vnodes, x_slack_edges }
}

///|
/// Graphviz parity: x-position solver call and trace emission consume
/// preassembled xpos inputs without additional remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_x_positions_from_xpos_input_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  flat_label_edges : Array[ConstraintEdge],
  xpos_input : XposComputationInput,
) -> Map[String, Double] {
  let x_positions = compute_x_positions(
    graph,
    prep.nodes,
    prep.edges,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_data.edge_out_order,
    ordering.nlist_order,
    ordering.gdnlist_order,
    xpos_input.x_ranks,
    xpos_input.x_rank_keys,
    x_groups,
    xpos_input.x_sizes,
    prep.output_sizes,
    x_cluster_keys,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    xpos_input.x_extra_nodes,
    flat_label_edges,
    xpos_input.x_edge_vnodes,
    xpos_input.x_slack_edges,
  )
  dot_trace("layout_dot: x positions computed")
  dot_trace_positions("xpos", x_positions)
  x_positions
}

///|
/// Graphviz parity: x-position stage must use identical xpos input assembly,
/// solver invocation, and trace points as Graphviz-aligned pipeline order.
/// Do not change behavior without updating fixtures/tests.
fn compute_x_positions_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  virtual_slack_edges : Array[ConstraintEdge],
  flat_label_edges : Array[ConstraintEdge],
) -> Map[String, Double] {
  let xpos_input =
    build_xpos_computation_input(
      use_vnodes_for_xpos,
      x_base_sizes,
      x_groups,
      ordering,
      virtual_slack_edges,
    )
  build_x_positions_from_xpos_input_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    ordering,
    x_groups,
    x_cluster_keys,
    flat_label_edges,
    xpos_input,
  )
}


///|
/// Graphviz parity: flat-edge label vnodes can raise per-rank half-heights,
/// and these maxima must feed y-rank placement exactly as in Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn apply_flat_label_rank_height_updates(
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  vnode_sizes : Map[String, NodeSize],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Unit {
  if flat_label_nodes.length() > 0 {
    for name, info in flat_label_nodes {
      let size = match vnode_sizes.get(name) {
        Some(value) => value
        None => continue
      }
      let half_height = size.height_pt / 2.0
      let rank = info.rank
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[rank] = half_height
      }
      let current_ht1 = match rank_ht1.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht1 {
        rank_ht1[rank] = half_height
      }
      let current_ht2 = match rank_ht2.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht2 {
        rank_ht2[rank] = half_height
      }
    }
  }
}

///|
/// Graphviz parity: y-rank sweep range expands to include inserted flat-label
/// vnode ranks, while preserving continuous rank iteration.
/// Do not change behavior without updating fixtures/tests.
fn build_y_all_ranks_with_flat_labels(
  rank_keys : Array[Int],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> Array[Int] {
  let y_all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let mut min_rank = rank_keys[0]
    let mut max_rank = rank_keys[rank_keys.length() - 1]
    if flat_label_nodes.length() > 0 {
      for _name, info in flat_label_nodes {
        if info.rank < min_rank {
          min_rank = info.rank
        }
        if info.rank > max_rank {
          max_rank = info.rank
        }
      }
    }
    for rank in min_rank..=max_rank {
      y_all_ranks.push(rank)
    }
  }
  y_all_ranks
}

///|
/// Graphviz parity: when flipped cluster-rank heights adjust rank_y, node y
/// coordinates are rebuilt from rank order/groups without extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_from_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
) -> Map[String, Double] {
  let y_positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let pos_y = match rank_y.get(rank) {
      Some(value) => value
      None => 0.0
    }
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      y_positions[name] = pos_y
    }
  }
  y_positions
}

///|
/// Graphviz parity: y-position stage runs fill_rank_positions first, then
/// optional flip-cluster height correction (cluster.c path) and y rebuild.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_with_cluster_flip_adjustment(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  cluster_bbox_heights : Map[String, (Double, Double)],
  y_all_ranks : Array[Int],
) -> (Map[String, Double], Map[Int, Double]) {
  let mut y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions(
    rank_keys,
    groups,
    y_all_ranks,
    rank_pht,
    rank_ht1,
    rank_ht2,
    ranksep_pt,
    y_positions,
    rank_y,
  )
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    graph_has_cluster(graph) {
    let min_root_rank = if y_all_ranks.length() > 0 { y_all_ranks[0] } else { 0 }
    let adjusted =
      adjust_flip_cluster_rank_heights(
      graph,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      cluster_bbox_heights,
      min_root_rank,
      0.0,
    )
    if adjusted {
      y_positions = build_y_positions_from_rank_groups(rank_keys, groups, rank_y)
    }
  }
  (y_positions, rank_y)
}

///|
/// Graphviz parity: cluster bbox heights for y-positioning are computed only
/// for clustered graphs and otherwise remain an empty map.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_bbox_heights_for_y_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
) -> Map[String, (Double, Double)] {
  if cluster_meta.has_clusters {
    compute_cluster_bbox_heights(
      graph,
      rank_data.ranks,
      prep.sizes,
      rank_data.self_edge_labels,
      prep.rankdir,
    )
  } else {
    Map::new()
  }
}

///|
/// Graphviz parity: y-position solve consumes rank-height maps after flat-label
/// updates and uses identical rank sweep + cluster-flip adjustment wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_and_rank_y_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  cluster_bbox_heights : Map[String, (Double, Double)],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> (Map[String, Double], Map[Int, Double]) {
  let y_all_ranks =
    build_y_all_ranks_with_flat_labels(rank_data.rank_keys, flat_label_nodes)
  build_y_positions_with_cluster_flip_adjustment(
    graph,
    prep.rankdir,
    rank_data.rank_keys,
    rank_data.groups,
    rank_data.ranks,
    rank_pht,
    rank_ht1,
    rank_ht2,
    rank_heights.ranksep_pt,
    cluster_bbox_heights,
    y_all_ranks,
  )
}

///|
/// Graphviz parity: y-position pre-solve in compute_positions keeps cluster bbox
/// derivation, flat-label rank-height updates, and y-sweep wiring unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_y_position_data_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> YPositionComputationData {
  let rank_pht = rank_heights.rank_pht
  let rank_ht1 = rank_heights.rank_ht1
  let rank_ht2 = rank_heights.rank_ht2
  let cluster_bbox_heights =
    build_cluster_bbox_heights_for_y_positions(
      graph,
      prep,
      rank_data,
      cluster_meta,
    )
  apply_flat_label_rank_height_updates(
    flat_label_nodes,
    ordering.vnode_info.vnode_sizes,
    rank_pht,
    rank_ht1,
    rank_ht2,
  )
  let (y_positions, rank_y) =
    build_y_positions_and_rank_y_for_positions(
      graph,
      prep,
      rank_data,
      rank_heights,
      flat_label_nodes,
      cluster_bbox_heights,
      rank_pht,
      rank_ht1,
      rank_ht2,
    )
  { y_positions, rank_y, cluster_bbox_heights }
}


///|
/// Graphviz parity: intercluster alignment is gated by DOT_INTERCLUSTER_ALIGN
/// and only applied for clustered dotted-edge graphs.
/// Do not change behavior without updating fixtures/tests.
fn is_intercluster_alignment_enabled() -> Bool {
  match @sys.get_env_var("DOT_INTERCLUSTER_ALIGN") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
/// Graphviz parity: intercluster alignment mutates x positions only under the
/// same runtime and graph-shape gates as Graphviz fixtures.
/// Do not change behavior without updating fixtures/tests.
fn maybe_adjust_intercluster_alignment(
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  x_positions : Map[String, Double],
) -> Unit {
  if cluster_meta.has_clusters && prep.has_dotted_edges &&
    is_intercluster_alignment_enabled() {
    adjust_intercluster_alignment(
      prep.nodes,
      prep.edges,
      rank_data.ranks,
      x_positions,
      cluster_meta.cluster_keys,
      cluster_meta.intercluster_keys,
      rank_heights.nodesep_pt,
      prep.has_edge_labels,
    )
  }
}

///|
/// Graphviz parity: final node output positions are direct x/y map lookups for
/// each real node, with missing coordinates defaulting to zero.
/// Do not change behavior without updating fixtures/tests.
fn build_node_positions_for_output(
  nodes : Array[@cgraph.Node],
  x_positions : Map[String, Double],
  y_positions : Map[String, Double],
) -> Map[String, @geom.Point] {
  let positions : Map[String, @geom.Point] = Map::new()
  for node in nodes {
    let name = node.name()
    let pos_x = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = match y_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    positions[name] = { x: pos_x, y: pos_y }
  }
  positions
}

///|
/// Graphviz parity: cluster rounding post-adjustment runs only for clustered
/// graphs when the runtime gate is enabled.
/// Do not change behavior without updating fixtures/tests.
fn maybe_adjust_cluster_positions_for_rounding_for_positions(
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  ordering : OrderingResult,
  prep : LayoutPrep,
) -> Unit {
  if cluster_meta.has_clusters && cluster_rounding_enabled() {
    let _ = adjust_cluster_positions_for_rounding(
      graph,
      positions,
      vnode_positions,
      ordering.vnode_info.vnode_clusters,
      prep.sizes,
    )
  }
}

///|
/// Graphviz parity: final node position map build and cluster-rounding
/// adjustment run after vnode projection data is available.
/// Do not change behavior without updating fixtures/tests.
fn build_positions_with_rounding_adjustment_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_positions : Map[String, Double],
  y_positions : Map[String, Double],
  vnode_positions : Map[String, @geom.Point],
) -> Map[String, @geom.Point] {
  let positions =
    build_node_positions_for_output(prep.nodes, x_positions, y_positions)
  maybe_adjust_cluster_positions_for_rounding_for_positions(
    graph,
    cluster_meta,
    positions,
    vnode_positions,
    ordering,
    prep,
  )
  positions
}

///|
/// Graphviz parity: intercluster alignment, cluster boundary x capture, and
/// vnode position projection are executed in fixed order before node map build.
/// Do not change behavior without updating fixtures/tests.
fn build_position_boundary_and_vnode_data_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> PositionBoundaryAndVnodeData {
  maybe_adjust_intercluster_alignment(
    cluster_meta,
    prep,
    rank_data,
    rank_heights,
    x_positions,
  )
  // Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
  let (cluster_ln_x, cluster_rn_x) =
    build_cluster_boundary_x_positions(graph, cluster_meta, x_positions)
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    build_vnode_positions_for_output(
      use_vnodes_for_xpos,
      prep,
      rank_data,
      ordering,
      x_positions,
      rank_y,
    )
  { cluster_ln_x, cluster_rn_x, vnode_positions }
}

///|
/// Graphviz parity: final output map assembly keeps intercluster alignment,
/// cluster boundary capture, vnode projection, and rounding adjustment order.
/// Do not change behavior without updating fixtures/tests.
fn build_position_output_maps_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_positions : Map[String, Double],
  y_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> PositionOutputMaps {
  let position_boundary_and_vnode_data =
    build_position_boundary_and_vnode_data_for_positions(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      use_vnodes_for_xpos,
      x_positions,
      rank_y,
    )
  let positions =
    build_positions_with_rounding_adjustment_for_positions(
      graph,
      prep,
      cluster_meta,
      ordering,
      x_positions,
      y_positions,
      position_boundary_and_vnode_data.vnode_positions,
    )
  {
    positions,
    vnode_positions: position_boundary_and_vnode_data.vnode_positions,
    cluster_ln_x: position_boundary_and_vnode_data.cluster_ln_x,
    cluster_rn_x: position_boundary_and_vnode_data.cluster_rn_x,
  }
}

///|
/// Graphviz parity: projection x-solve and output-map assembly consume
/// precomputed y positions/rank_y without changing solve or mapping order.
/// Do not change behavior without updating fixtures/tests.
fn build_position_output_maps_with_x_solve_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  virtual_slack_edges : Array[ConstraintEdge],
  flat_label_edges : Array[ConstraintEdge],
  y_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> PositionOutputMaps {
  let x_positions =
    compute_x_positions_for_positions(
      graph,
      prep,
      rank_data,
      rank_heights,
      ordering,
      use_vnodes_for_xpos,
      x_base_sizes,
      x_groups,
      x_cluster_keys,
      virtual_slack_edges,
      flat_label_edges,
    )
  build_position_output_maps_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    use_vnodes_for_xpos,
    x_positions,
    y_positions,
    rank_y,
  )
}

///|
/// Graphviz parity: y-position precompute output is threaded into x-solve
/// output-map assembly without altering y/rank map selection.
/// Do not change behavior without updating fixtures/tests.
fn build_position_output_maps_from_y_data_with_x_solve_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  virtual_slack_edges : Array[ConstraintEdge],
  flat_label_edges : Array[ConstraintEdge],
  y_position_data : YPositionComputationData,
) -> PositionOutputMaps {
  build_position_output_maps_with_x_solve_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    use_vnodes_for_xpos,
    x_base_sizes,
    x_groups,
    x_cluster_keys,
    virtual_slack_edges,
    flat_label_edges,
    y_position_data.y_positions,
    y_position_data.rank_y,
  )
}

///|
/// Graphviz parity: projection output object directly reuses y-position data
/// fields and computed output maps with no extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_position_projection_data_output_from_y_data_for_positions(
  y_position_data : YPositionComputationData,
  position_output_maps : PositionOutputMaps,
) -> PositionProjectionData {
  {
    rank_y: y_position_data.rank_y,
    cluster_bbox_heights: y_position_data.cluster_bbox_heights,
    position_output_maps,
  }
}

///|
/// Graphviz parity: position projection stage keeps y-precompute, x solve, and
/// final output-map assembly wiring identical to Graphviz-aligned pipeline.
/// Do not change behavior without updating fixtures/tests.
fn build_position_projection_data_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  virtual_slack_edges : Array[ConstraintEdge],
  flat_label_edges : Array[ConstraintEdge],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> PositionProjectionData {
  let y_position_data =
    build_y_position_data_for_positions(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      flat_label_nodes,
    )
  let position_output_maps =
    build_position_output_maps_from_y_data_with_x_solve_for_positions(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      use_vnodes_for_xpos,
      x_base_sizes,
      x_groups,
      x_cluster_keys,
      virtual_slack_edges,
      flat_label_edges,
      y_position_data,
    )
  build_position_projection_data_output_from_y_data_for_positions(
    y_position_data,
    position_output_maps,
  )
}

///|
/// Graphviz parity: virtual slack edges are only synthesized on vnode-xpos
/// paths and must preserve node-singleton and cluster-key inputs.
/// Do not change behavior without updating fixtures/tests.
fn build_virtual_slack_edges_for_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  cluster_meta : ClusterMetadata,
) -> Array[ConstraintEdge] {
  if use_vnodes_for_xpos {
    let node_singletons = build_node_singletons(prep.nodes, prep.edges)
    let edges_out = build_virtual_slack_edges(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.edge_reversed,
      rank_data.ranks,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_ranks,
      node_singletons,
      cluster_meta.cluster_keys,
    )
    dot_trace("layout_dot: virtual slack edges=\{edges_out.length()}")
    edges_out
  } else {
    dot_trace("layout_dot: virtual slack edges=0 (skipped)")
    []
  }
}

///|
/// Graphviz parity: vnode order-key derivation follows Graphviz: explicit
/// ordered_groups_with_vnodes means vnode order is present; otherwise build
/// keys from edge-vnode chains and mark presence by non-empty key map.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_state_for_positions(
  use_vnodes_for_xpos : Bool,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  prep : LayoutPrep,
  rank_data : RankData,
  order_index : Map[String, Int],
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XposVNodeOrderState {
  let mut vnode_order_keys : Map[String, Double] = Map::new()
  let mut has_vnode_order = false
  if use_vnodes_for_xpos && ordered_groups_with_vnodes.length() == 0 {
    vnode_order_keys = build_vnode_order_keys(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.edge_reversed,
      rank_data.ranks,
      order_index,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_ranks,
    )
    for _name, _ in vnode_order_keys {
      has_vnode_order = true
      break
    }
  }
  if use_vnodes_for_xpos && ordered_groups_with_vnodes.length() > 0 {
    has_vnode_order = true
  }
  { vnode_order_keys, has_vnode_order }
}

///|
/// Graphviz parity: x-order sizes and edge port position/order arrays are
/// derived from layout-coordinate sizes before any xpos reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_x_order_edge_port_data_for_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
) -> XposOrderEdgePortData {
  // Graphviz parity: x-positioning uses layout-coordinate node sizes,
  // so rankdir flip is handled via prep.sizes (not ordering-space widths).
  let x_base_sizes = apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    prep.sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let x_order_sizes =
    if use_vnodes_for_xpos {
      merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let (x_edge_tail_port_x, x_edge_head_port_x) =
    compute_edge_port_positions(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let (x_edge_tail_port_order, x_edge_head_port_order) =
    compute_edge_port_orders(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  {
    x_base_sizes,
    x_order_sizes,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
  }
}


///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, and vnode cluster-key overlay only on vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_vnode_augmentation_for_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
) -> XposFlatLabelAugmentation {
  let mut next_x_groups = x_groups
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  let next_x_cluster_keys = x_cluster_keys
  let existing_names = build_existing_node_names_map_for_positions(prep.nodes)
  add_vnode_names_to_existing_names_for_positions(
    existing_names,
    ordering.vnode_info.vnode_ranks,
  )
  if use_vnodes_for_xpos {
    let (
      updated_groups,
      label_nodes,
      label_edge_vnodes,
      extra_edges,
    ) = add_flat_label_vnodes(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.ranks,
      ordering.ordered_groups,
      rank_heights.nodesep_pt,
      prep.rankdir,
      x_base_sizes,
      ordering.edge_cluster_keys,
      cluster_meta.cluster_parents,
      existing_names,
      ordering.vnode_info,
      next_x_groups,
    )
    next_x_groups = updated_groups
    flat_label_edges = extra_edges
    flat_label_nodes = label_nodes
    flat_label_edge_vnodes = label_edge_vnodes
    for name, key in ordering.vnode_info.vnode_clusters {
      next_x_cluster_keys[name] = key
    }
  }
  {
    x_groups: next_x_groups,
    x_cluster_keys: next_x_cluster_keys,
    flat_label_edges,
    flat_label_nodes,
    flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: clustered xpos reorder seed skeleton injection appends
/// per-rank cluster skeleton vnodes before rank-order/index materialization.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_nodes_for_xpos_reorder_seed(
  order_groups : Map[Int, Array[String]],
  order_sizes : Map[String, NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
) -> Unit {
  // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
  let skeleton_size = vnode_size_from_widths(1.0, 1.0)
  for cluster, min_rank in cluster_meta.cluster_min_rank {
    let max_rank = match cluster_meta.cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    for rank in min_rank..=max_rank {
      let name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      order_cluster_keys[name] = cluster
      order_cluster_skeleton[name] = true
      order_sizes[name] = skeleton_size
      match order_groups.get(rank) {
        Some(list) => list.push(name)
        None => order_groups[rank] = [name]
      }
    }
  }
}

///|
/// Graphviz parity: clustered xpos reorder seed expands grouped rank buckets
/// into rank-ordered node arrays without filtering/reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_order_nodes_for_clustered_xpos_reorder_seed(
  order_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
) -> Array[String] {
  let order_nodes : Array[String] = []
  for rank in order_rank_keys {
    let names = match order_groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      order_nodes.push(name)
    }
  }
  order_nodes
}

///|
/// Graphviz parity: clustered xpos reorder seed setup clones x-order groups,
/// injects cluster skeleton nodes, and materializes rank/order maps.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reorder_seed_data(
  x_groups : Map[Int, Array[String]],
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  node_order : Map[String, Int],
) -> XposClusteredReorderSeedData {
  let order_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in x_groups {
    order_groups[rank] = names.copy()
  }
  let order_sizes : Map[String, NodeSize] = Map::new()
  for name, size in x_order_sizes {
    order_sizes[name] = size
  }
  let order_cluster_keys : Map[String, String] = Map::new()
  for name, key in x_cluster_keys {
    order_cluster_keys[name] = key
  }
  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  append_cluster_skeleton_nodes_for_xpos_reorder_seed(
    order_groups,
    order_sizes,
    order_cluster_keys,
    order_cluster_skeleton,
    cluster_meta,
  )
  let order_node_order : Map[String, Int] = Map::new()
  for name, value in node_order {
    order_node_order[name] = value
  }
  let order_index = build_order_index(order_groups)
  for name, idx in order_index {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_rank_keys = collect_rank_keys(order_groups)
  let order_ranks = build_node_ranks(order_groups)
  let order_nodes = build_order_nodes_for_clustered_xpos_reorder_seed(
    order_groups,
    order_rank_keys,
  )
  {
    order_groups,
    order_sizes,
    order_cluster_keys,
    order_cluster_skeleton,
    order_node_order,
    order_rank_keys,
    order_ranks,
    order_nodes,
  }
}

///|
/// Graphviz parity: clustered xpos reorder vnode chain direction follows
/// rank order (forward/reverse) before segment emission.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reorder_edge_chain_with_vnodes(
  ranks : Map[String, Int],
  tail : String,
  head : String,
  vnodes : Array[String],
) -> Array[String] {
  let tail_rank = match ranks.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_rank = match ranks.get(head) {
    Some(value) => value
    None => 0
  }
  let chain : Array[String] = []
  chain.push(tail)
  if tail_rank <= head_rank {
    for vnode in vnodes {
      chain.push(vnode)
    }
  } else {
    let mut i = vnodes.length()
    while i > 0 {
      i = i - 1
      chain.push(vnodes[i])
    }
  }
  chain.push(head)
  chain
}

///|
/// Graphviz parity: clustered xpos reorder emits chain segments with
/// endpoint port hints and midpoint-neutral port-order values.
/// Do not change behavior without updating fixtures/tests.
fn append_clustered_xpos_reorder_edge_chain_segments(
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  chain : Array[String],
  tail : String,
  head : String,
  penalty : Int,
  constraint : Bool,
  tail_port_x : Double,
  head_port_x : Double,
  tail_port_order : Double,
  head_port_order : Double,
) -> Unit {
  let mut idx = 0
  while idx + 1 < chain.length() {
    let seg_tail_port =
      if chain[idx] == tail { tail_port_x } else { 0.0 }
    let seg_head_port =
      if chain[idx + 1] == head { head_port_x } else { 0.0 }
    // Graphviz parity: split edge segments keep neutral midpoint
    // port-order (0.5) unless endpoint matches real tail/head.
    let seg_tail_order =
      if chain[idx] == tail { tail_port_order } else { 0.5 }
    let seg_head_order =
      if chain[idx + 1] == head { head_port_order } else { 0.5 }
    add_order_edge(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      chain[idx],
      chain[idx + 1],
      penalty,
      constraint,
      seg_tail_port,
      seg_head_port,
      seg_tail_order,
      seg_head_order,
    )
    idx = idx + 1
  }
}

///|
/// Graphviz parity: clustered xpos reorder expands vnode edge chains
/// into order-graph segments while preserving endpoint port hints.
/// Do not change behavior without updating fixtures/tests.
fn append_clustered_xpos_reorder_edge_with_vnodes(
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  tail : String,
  head : String,
  penalty : Int,
  constraint : Bool,
  tail_port_x : Double,
  head_port_x : Double,
  tail_port_order : Double,
  head_port_order : Double,
  vnodes : Array[String],
) -> Unit {
  if vnodes.length() == 0 {
    add_order_edge(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      tail,
      head,
      penalty,
      constraint,
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    )
  } else {
    let chain = build_clustered_xpos_reorder_edge_chain_with_vnodes(
      ranks,
      tail,
      head,
      vnodes,
    )
    append_clustered_xpos_reorder_edge_chain_segments(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      chain,
      tail,
      head,
      penalty,
      constraint,
      tail_port_x,
      head_port_x,
      tail_port_order,
      head_port_order,
    )
  }
}

///|
/// Graphviz parity: clustered xpos reorder appends cluster skeleton chain
/// edges between consecutive cluster ranks with CL_CROSS penalty.
/// Do not change behavior without updating fixtures/tests.
fn append_cluster_skeleton_edges_for_xpos_reorder(
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Unit {
  for cluster, min_rank in cluster_min_rank {
    let max_rank = match cluster_max_rank.get(cluster) {
      Some(value) => value
      None => min_rank
    }
    let mut rank = min_rank
    while rank < max_rank {
      let tail_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
      let head_name = "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank + 1}"
      add_order_edge(
        order_graph,
        order_node_map,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_edge_tail_port_x,
        order_edge_head_port_x,
        order_edge_tail_port_order,
        order_edge_head_port_order,
        tail_name,
        head_name,
        CL_CROSS,
        true,
        0.0,
        0.0,
        0.5,
        0.5,
      )
      rank = rank + 1
    }
  }
}

///|
/// Graphviz parity: clustered xpos edge-input extraction keeps fallback
/// defaults and vnode lookup ordering unchanged per Graphviz edge iteration.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reorder_input_edge_data(
  edge : @cgraph.Edge,
  edge_idx : Int,
  rank_data : RankData,
  ordering : OrderingResult,
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
) -> XposClusteredInputEdgeData {
  let tail =
    if edge_idx < rank_data.edge_tail.length() { rank_data.edge_tail[edge_idx] } else {
      edge.tail().name()
    }
  let head =
    if edge_idx < rank_data.edge_head.length() { rank_data.edge_head[edge_idx] } else {
      edge.head().name()
    }
  let penalty = edge_xpenalty(edge)
  let constraint = edge_is_constraint(edge)
  let tail_port_x =
    if edge_idx < x_edge_tail_port_x.length() { x_edge_tail_port_x[edge_idx] } else {
      0.0
    }
  let head_port_x =
    if edge_idx < x_edge_head_port_x.length() { x_edge_head_port_x[edge_idx] } else {
      0.0
    }
  let tail_port_order =
    if edge_idx < x_edge_tail_port_order.length() { x_edge_tail_port_order[edge_idx] } else {
      0.5
    }
  let head_port_order =
    if edge_idx < x_edge_head_port_order.length() { x_edge_head_port_order[edge_idx] } else {
      0.5
    }
  let vnodes = match ordering.vnode_info.edge_vnodes.get(edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  {
    tail,
    head,
    penalty,
    constraint,
    tail_port_x,
    head_port_x,
    tail_port_order,
    head_port_order,
    vnodes,
  }
}

///|
/// Graphviz parity: clustered xpos reorder first materializes input
/// edges in Graphviz iteration order before appending cluster skeleton edges.
/// Do not change behavior without updating fixtures/tests.
fn append_clustered_xpos_reorder_input_edges(
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
) -> Unit {
  let mut edge_idx = 0
  for edge in prep.edges {
    let edge_data =
      build_clustered_xpos_reorder_input_edge_data(
        edge,
        edge_idx,
        rank_data,
        ordering,
        x_edge_tail_port_x,
        x_edge_head_port_x,
        x_edge_tail_port_order,
        x_edge_head_port_order,
      )
    append_clustered_xpos_reorder_edge_with_vnodes(
      order_graph,
      order_node_map,
      order_edges_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      order_edge_tail_port_order,
      order_edge_head_port_order,
      rank_data.ranks,
      edge_data.tail,
      edge_data.head,
      edge_data.penalty,
      edge_data.constraint,
      edge_data.tail_port_x,
      edge_data.head_port_x,
      edge_data.tail_port_order,
      edge_data.head_port_order,
      edge_data.vnodes,
    )
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: clustered xpos reorder edge materialization preserves
/// vnode chain splitting and cluster skeleton linking before reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reorder_edges(
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  cluster_meta : ClusterMetadata,
  order_nodes : Array[String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
) -> XposClusteredReorderEdgesData {
  let order_graph =
    @cgraph.Graph::new(@cgraph.GraphKind::Directed, name="xpos_order", strict=false)
  let order_node_map : Map[String, @cgraph.Node] = Map::new()
  for name in order_nodes {
    order_node_map[name] = order_graph.node(name)
  }
  let order_edges_out : Array[@cgraph.Edge] = []
  let order_edge_tail_out : Array[String] = []
  let order_edge_head_out : Array[String] = []
  let order_edge_tail_port_x : Array[Double] = []
  let order_edge_head_port_x : Array[Double] = []
  let order_edge_tail_port_order : Array[Double] = []
  let order_edge_head_port_order : Array[Double] = []
  append_clustered_xpos_reorder_input_edges(
    prep,
    rank_data,
    ordering,
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
  )
  append_cluster_skeleton_edges_for_xpos_reorder(
    order_graph,
    order_node_map,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    cluster_meta.cluster_min_rank,
    cluster_meta.cluster_max_rank,
  )
  {
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: clustered xpos reorder consumes order-graph parents/children
/// plus edge-order hints exactly once before reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn apply_clustered_xpos_reorder_rank_groups_for_positions(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_nodes : Array[String],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  order_cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let (parents, children) = build_edge_index_for_order_names(
    order_nodes,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
  )
  let edge_order = collect_edge_order(order_edges_out)
  // Graphviz parity: xpos reorder uses the same edge-segment port-order hints
  // computed for the order graph (mincross median tie-breaking path).
  reorder_rank_groups(
    order_rank_keys,
    order_groups,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    parents,
    children,
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    edge_order,
    order_node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    Map::new(),
    Map::new(),
    Map::new(),
    order_cluster_skeleton,
    flat_constraints,
    graphviz_flip=graphviz_flip,
  )
}

///|
/// Graphviz parity: clustered reorder apply step wires seed/edge bundles into
/// reorder_rank_groups without changing Graphviz-aligned argument flow.
/// Do not change behavior without updating fixtures/tests.
fn apply_clustered_xpos_reorder_from_seed_and_edges_for_positions(
  reorder_seed_data : XposClusteredReorderSeedData,
  reorder_edges_data : XposClusteredReorderEdgesData,
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_heights : RankHeights,
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  apply_clustered_xpos_reorder_rank_groups_for_positions(
    reorder_seed_data.order_rank_keys,
    reorder_seed_data.order_groups,
    reorder_edges_data.order_edges_out,
    reorder_edges_data.order_edge_tail_out,
    reorder_edges_data.order_edge_head_out,
    reorder_edges_data.order_edge_tail_port_x,
    reorder_edges_data.order_edge_head_port_x,
    reorder_edges_data.order_edge_tail_port_order,
    reorder_edges_data.order_edge_head_port_order,
    reorder_seed_data.order_nodes,
    reorder_seed_data.order_ranks,
    reorder_seed_data.order_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    reorder_seed_data.order_node_order,
    reorder_seed_data.order_sizes,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    reorder_seed_data.order_cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_flip,
  )
}

///|
/// Graphviz parity: clustered xpos reorder branch keeps the same seed build,
/// edge materialization, and reorder_rank_groups invocation sequence as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_xpos_reordered_groups(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_groups : Map[Int, Array[String]],
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let reorder_seed_data =
    build_clustered_xpos_reorder_seed_data(
      x_groups,
      x_order_sizes,
      x_cluster_keys,
      cluster_meta,
      prep.node_order,
    )
  let reorder_edges_data =
    build_clustered_xpos_reorder_edges(
      prep,
      rank_data,
      ordering,
      cluster_meta,
      reorder_seed_data.order_nodes,
      x_edge_tail_port_x,
      x_edge_head_port_x,
      x_edge_tail_port_order,
      x_edge_head_port_order,
    )
  apply_clustered_xpos_reorder_from_seed_and_edges_for_positions(
    reorder_seed_data,
    reorder_edges_data,
    cluster_meta,
    prep,
    rank_heights,
    graphviz_flip,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder uses both geometric port x and
/// compass/record port-order hints for mincross tie-breaking, same as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reorder_port_hints_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double], Array[Double], Array[Double]) {
  let (order_edge_tail_port_x, order_edge_head_port_x) =
    compute_edge_port_positions(
      nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      x_order_sizes,
    )
  let (order_edge_tail_port_order, order_edge_head_port_order) =
    compute_edge_port_orders(
      nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      x_order_sizes,
    )
  (
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder reads vnode edge-index parents/
/// children and current rank keys before calling reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reorder_graph_inputs_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> (Map[String, Array[String]], Map[String, Array[String]], Array[Int]) {
  let (parents, children) = build_edge_index_for_order_with_vnodes(
    nodes,
    ordering.order_edges,
    ordering.order_edge_tail,
    ordering.order_edge_head,
    ranks,
    ordering.vnode_info.edge_vnodes,
    ordering.vnode_info.vnode_ranks,
  )
  let tmp_rank_keys = collect_rank_keys(x_groups)
  (parents, children, tmp_rank_keys)
}

///|
/// Graphviz parity: non-cluster reorder input assembly keeps vnode edge-index
/// and port-hint derivation in Graphviz-aligned order before reorder apply.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reorder_inputs_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
) -> NonclusterXposReorderInputs {
  let (parents, children, tmp_rank_keys) =
    build_noncluster_xpos_reorder_graph_inputs_for_positions(
      prep.nodes,
      ordering,
      rank_data.ranks,
      x_groups,
    )
  // Graphviz parity: even non-cluster xpos reorder uses compass/record
  // port-order fractions when mincross scoring ties are evaluated.
  let (
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  ) = build_noncluster_xpos_reorder_port_hints_for_positions(
    prep.nodes,
    ordering,
    x_order_sizes,
  )
  {
    parents,
    children,
    tmp_rank_keys,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: non-cluster reorder_rank_groups consumes the same port-hint,
/// parent/child, and cluster/order maps as Graphviz branch wiring.
/// Do not change behavior without updating fixtures/tests.
fn apply_noncluster_xpos_reorder_rank_groups_for_positions(
  tmp_rank_keys : Array[Int],
  x_groups : Map[Int, Array[String]],
  ordering : OrderingResult,
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  x_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  x_order_sizes : Map[String, NodeSize],
  rank_heights : RankHeights,
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    tmp_rank_keys,
    x_groups,
    ordering.order_edges,
    ordering.order_edge_tail,
    ordering.order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    parents,
    children,
    x_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    ordering.edge_order,
    prep.node_order,
    x_order_sizes,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    prep.port_order_positions,
    prep.port_order_contrib,
    Map::new(),
    cluster_meta.cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_flip=graphviz_flip,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder build path keeps vnode-edge input,
/// port-hint derivation, and reorder apply wiring identical to Graphviz flow.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reordered_groups_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let noncluster_reorder_inputs =
    build_noncluster_xpos_reorder_inputs_for_positions(
      prep,
      rank_data,
      ordering,
      x_order_sizes,
      x_groups,
    )
  apply_noncluster_xpos_reorder_rank_groups_for_positions(
    noncluster_reorder_inputs.tmp_rank_keys,
    x_groups,
    ordering,
    noncluster_reorder_inputs.order_edge_tail_port_x,
    noncluster_reorder_inputs.order_edge_head_port_x,
    noncluster_reorder_inputs.order_edge_tail_port_order,
    noncluster_reorder_inputs.order_edge_head_port_order,
    noncluster_reorder_inputs.parents,
    noncluster_reorder_inputs.children,
    x_cluster_keys,
    cluster_meta,
    prep,
    x_order_sizes,
    rank_heights,
    graphviz_flip,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder gate matches Graphviz branch
/// predicate (non-cluster path only, no vnode-order fallback path).
/// Do not change behavior without updating fixtures/tests.
fn should_apply_noncluster_xpos_reorder_for_positions(
  xpos_reorder_enabled : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
) -> Bool {
  xpos_reorder_enabled && allow_xpos_reorder && !cluster_meta.ordering_set &&
  !has_vnode_order && !cluster_meta.has_clusters
}

///|
/// Graphviz parity: non-cluster xpos reorder fallback runs only when clustered
/// vnode reorder path is not taken, matching Graphviz branch structure.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_noncluster_xpos_reorder_fallback(
  xpos_reorder_enabled : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if should_apply_noncluster_xpos_reorder_for_positions(
    xpos_reorder_enabled,
    allow_xpos_reorder,
    has_vnode_order,
    cluster_meta,
  ) {
    build_noncluster_xpos_reordered_groups_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_order_sizes,
      x_cluster_keys,
      graphviz_flip,
      x_groups,
    )
  } else {
    x_groups
  }
}

///|
/// Graphviz parity: vnode xpos-reorder gate is shared across reorder branch
/// selection and transpose cleanup eligibility.
/// Do not change behavior without updating fixtures/tests.
fn should_apply_vnode_xpos_reorder_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  cluster_meta : ClusterMetadata,
) -> Bool {
  xpos_reorder_enabled && use_vnodes_for_xpos && allow_xpos_reorder &&
  !cluster_meta.ordering_set
}

///|
/// Graphviz parity: xpos reorder branch resolver keeps clustered vs non-cluster
/// routing unchanged before transpose-cleanup stage.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_reordered_groups_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if should_apply_vnode_xpos_reorder_for_positions(
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    cluster_meta,
  ) {
    build_clustered_xpos_reordered_groups(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_groups,
      x_order_sizes,
      x_cluster_keys,
      x_edge_tail_port_x,
      x_edge_head_port_x,
      x_edge_tail_port_order,
      x_edge_head_port_order,
      graphviz_flip,
    )
  } else {
    maybe_apply_noncluster_xpos_reorder_fallback(
      xpos_reorder_enabled,
      allow_xpos_reorder,
      has_vnode_order,
      cluster_meta,
      prep,
      rank_data,
      rank_heights,
      ordering,
      x_order_sizes,
      x_cluster_keys,
      graphviz_flip,
      x_groups,
    )
  }
}

///|
/// Graphviz parity: xpos reorder control-flow must match Graphviz clustered/non-cluster
/// branch selection before transpose cleanup.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_xpos_reorder_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  build_xpos_reordered_groups_for_positions(
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    has_vnode_order,
    cluster_meta,
    prep,
    rank_data,
    rank_heights,
    ordering,
    x_order_sizes,
    x_cluster_keys,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
    graphviz_flip,
    x_groups,
  )
}

///|
/// Graphviz parity: transpose cleanup performs two limited passes in fixed
/// order (forward then reverse), matching Graphviz fixture behavior.
/// Do not change behavior without updating fixtures/tests.
fn apply_xpos_transpose_cleanup_passes(
  tmp_rank_keys : Array[Int],
  x_groups : Map[Int, Array[String]],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  tmp_ranks : Map[String, Int],
) -> Unit {
  let _ = transpose_rank_groups_limited(
    tmp_rank_keys,
    x_groups,
    parents,
    children,
    tmp_ranks,
    false,
    4,
  )
  let _ = transpose_rank_groups_limited(
    tmp_rank_keys,
    x_groups,
    parents,
    children,
    tmp_ranks,
    true,
    4,
  )
}

///|
/// Graphviz parity: transpose cleanup input derivation uses vnode edge index
/// plus current x_groups rank snapshot before limited transpose passes.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_transpose_cleanup_inputs_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> XposTransposeCleanupInputs {
  let (parents, children) = build_edge_index_for_order_with_vnodes(
    nodes,
    ordering.order_edges,
    ordering.order_edge_tail,
    ordering.order_edge_head,
    ranks,
    ordering.vnode_info.edge_vnodes,
    ordering.vnode_info.vnode_ranks,
  )
  let tmp_rank_keys = collect_rank_keys(x_groups)
  let tmp_ranks = build_node_ranks(x_groups)
  { parents, children, tmp_rank_keys, tmp_ranks }
}

///|
/// Graphviz parity: transpose cleanup apply step preserves input derivation
/// and fixed two-pass execution order used by Graphviz-aligned fixtures.
/// Do not change behavior without updating fixtures/tests.
fn apply_xpos_transpose_cleanup_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> Unit {
  let transpose_cleanup_inputs =
    build_xpos_transpose_cleanup_inputs_for_positions(
      nodes,
      ordering,
      ranks,
      x_groups,
    )
  apply_xpos_transpose_cleanup_passes(
    transpose_cleanup_inputs.tmp_rank_keys,
    x_groups,
    transpose_cleanup_inputs.parents,
    transpose_cleanup_inputs.children,
    transpose_cleanup_inputs.tmp_ranks,
  )
}

///|
/// Graphviz parity: optional transpose cleanup runs only in vnode xpos-reorder
/// mode after reorder_rank_groups, and mutates x_groups in-place.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_xpos_transpose_cleanup(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  cluster_meta : ClusterMetadata,
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> Unit {
  if should_apply_vnode_xpos_reorder_for_positions(
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    cluster_meta,
  ) {
    apply_xpos_transpose_cleanup_for_positions(
      nodes,
      ordering,
      ranks,
      x_groups,
    )
  }
}

///|
/// Graphviz parity: final projection precompute call uses x-stage projection
/// inputs unchanged before result-object assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_data_for_projection_result_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  virtual_slack_edges : Array[ConstraintEdge],
  flat_label_edges : Array[ConstraintEdge],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> PositionProjectionData {
  build_position_projection_data_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    use_vnodes_for_xpos,
    x_base_sizes,
    x_groups,
    x_cluster_keys,
    virtual_slack_edges,
    flat_label_edges,
    flat_label_nodes,
  )
}

///|
/// Graphviz parity: projection-data to position-result handoff keeps x-groups,
/// flat-label vnode maps, and rank-height maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_output_for_positions(
  x_groups : Map[Int, Array[String]],
  position_projection_data : PositionProjectionData,
  flat_label_edge_vnodes : Map[String, String],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  build_position_result_from_projection_data_for_positions(
    x_groups,
    position_projection_data,
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
  )
}

///|
/// Graphviz parity: final projection stage in compute_positions keeps y/x solve
/// projection and result assembly sequencing identical to Graphviz-aligned flow.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  virtual_slack_edges : Array[ConstraintEdge],
  flat_label_edges : Array[ConstraintEdge],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  flat_label_edge_vnodes : Map[String, String],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  let position_projection_data =
    build_projection_data_for_projection_result_for_positions(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      use_vnodes_for_xpos,
      x_base_sizes,
      x_groups,
      x_cluster_keys,
      virtual_slack_edges,
      flat_label_edges,
      flat_label_nodes,
    )
  build_projection_result_output_for_positions(
    x_groups,
    position_projection_data,
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
  )
}


///|
/// Graphviz parity: projection-data to result-object mapping keeps rank_y,
/// output-map, and cluster height wiring unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_result_from_projection_data_for_positions(
  x_groups : Map[Int, Array[String]],
  position_projection_data : PositionProjectionData,
  flat_label_edge_vnodes : Map[String, String],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  build_position_result_for_positions(
    x_groups,
    position_projection_data.rank_y,
    position_projection_data.position_output_maps,
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
    position_projection_data.cluster_bbox_heights,
  )
}

///|
/// Graphviz parity: position-result output object maps prepared position/rank
/// fields directly without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_position_result_output_for_positions(
  x_groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  flat_label_edge_vnodes : Map[String, String],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  cluster_bbox_heights : Map[String, (Double, Double)],
) -> PositionResult {
  {
    x_groups,
    rank_y,
    positions,
    vnode_positions,
    cluster_ln_x,
    cluster_rn_x,
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
    cluster_bbox_heights,
  }
}

///|
/// Graphviz parity: final position result object is assembled from already-
/// computed maps without extra transforms or normalization.
/// Do not change behavior without updating fixtures/tests.
fn build_position_result_for_positions(
  x_groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
  position_output_maps : PositionOutputMaps,
  flat_label_edge_vnodes : Map[String, String],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  cluster_bbox_heights : Map[String, (Double, Double)],
) -> PositionResult {
  build_position_result_output_for_positions(
    x_groups,
    rank_y,
    position_output_maps.positions,
    position_output_maps.vnode_positions,
    position_output_maps.cluster_ln_x,
    position_output_maps.cluster_rn_x,
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
    cluster_bbox_heights,
  )
}

///|
/// Graphviz parity: vnode xpos mode gate follows Graphviz edge-label/port-edge
/// requirements with vnode-count fallback threshold.
/// Do not change behavior without updating fixtures/tests.
fn should_use_vnodes_for_xpos_in_positions(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> Bool {
  prep.has_edge_labels || prep.has_port_edges || ordering.vnode_count <= MAX_XPOS_VNODES
}

///|
/// Graphviz parity: xpos reorder allowance follows Graphviz vnode-count gating
/// once vnode usage mode is decided.
/// Do not change behavior without updating fixtures/tests.
fn should_allow_xpos_reorder_in_positions(
  use_vnodes_for_xpos : Bool,
  ordering : OrderingResult,
) -> Bool {
  !use_vnodes_for_xpos || ordering.vnode_count <= MAX_XPOS_REORDER_VNODES
}

///|
/// Graphviz parity: rankdir flip gate for xpos follows Graphviz LR/RL handling.
/// Do not change behavior without updating fixtures/tests.
fn is_graphviz_rankdir_flip_for_positions(prep : LayoutPrep) -> Bool {
  prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL
}


///|
/// Graphviz parity: position-mode gate values are derived once from prep and
/// ordering before final mode-flag output assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_gate_values_for_positions(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> PositionModeGateValues {
  let use_vnodes_for_xpos = should_use_vnodes_for_xpos_in_positions(prep, ordering)
  let allow_xpos_reorder =
    should_allow_xpos_reorder_in_positions(use_vnodes_for_xpos, ordering)
  let graphviz_flip = is_graphviz_rankdir_flip_for_positions(prep)
  { use_vnodes_for_xpos, allow_xpos_reorder, graphviz_flip }
}

///|
/// Graphviz parity: position-mode output object maps computed gate values and
/// preserves fixed xpos_reorder_enabled=false behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_flags_output_for_positions(
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  graphviz_flip : Bool,
) -> PositionModeFlags {
  // Graphviz parity: xpos constraints must preserve mincross ordering; do not reorder here.
  let xpos_reorder_enabled = false
  {
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    graphviz_flip,
    xpos_reorder_enabled,
  }
}

///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once from prep+ordering and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_flags(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> PositionModeFlags {
  let mode_gate_values =
    build_position_mode_gate_values_for_positions(prep, ordering)
  build_position_mode_flags_output_for_positions(
    mode_gate_values.use_vnodes_for_xpos,
    mode_gate_values.allow_xpos_reorder,
    mode_gate_values.graphviz_flip,
  )
}

///|
/// Graphviz parity: x-stage mode/slack output object maps gate flags and
/// synthesized virtual-slack edges without extra normalization.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_virtual_slack_output_for_positions(
  mode_flags : PositionModeFlags,
  virtual_slack_edges : Array[ConstraintEdge],
) -> XStageModeAndSlackData {
  {
    use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
    allow_xpos_reorder: mode_flags.allow_xpos_reorder,
    graphviz_flip: mode_flags.graphviz_flip,
    xpos_reorder_enabled: mode_flags.xpos_reorder_enabled,
    virtual_slack_edges,
  }
}


///|
/// Graphviz parity: virtual-slack synthesis consumes mode flags after vnode
/// trace emission and preserves vnode-xpos gating semantics.
/// Do not change behavior without updating fixtures/tests.
fn build_virtual_slack_edges_from_mode_flags_for_positions(
  mode_flags : PositionModeFlags,
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> Array[ConstraintEdge] {
  dot_trace("layout_dot: vnodes built count=\{ordering.vnode_count}")
  build_virtual_slack_edges_for_positions(
    mode_flags.use_vnodes_for_xpos,
    prep,
    rank_data,
    ordering,
    cluster_meta,
  )
}

///|
/// Graphviz parity: x-stage mode/virtual-slack setup keeps gate derivation,
/// vnode trace emission, and virtual-slack synthesis ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_virtual_slack_data_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XStageModeAndSlackData {
  let mode_flags = build_position_mode_flags(prep, ordering)
  let virtual_slack_edges =
    build_virtual_slack_edges_from_mode_flags_for_positions(
      mode_flags,
      prep,
      rank_data,
      cluster_meta,
      ordering,
    )
  build_x_stage_mode_and_virtual_slack_output_for_positions(
    mode_flags,
    virtual_slack_edges,
  )
}

///|
/// Graphviz parity: x-stage seed generation consumes vnode-mode flag from
/// mode/slack stage before flat-label augmentation.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_seed_from_mode_slack_data_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  mode_slack_data : XStageModeAndSlackData,
) -> XPositionStageSeedData {
  build_x_position_stage_seed_data_for_positions(
    mode_slack_data.use_vnodes_for_xpos,
    prep,
    rank_data,
    cluster_meta,
    ordering,
  )
}

///|
/// Graphviz parity: flat-label augmentation from x-stage seed consumes mode
/// flags unchanged before vnode/slot augmentation.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_augmentation_from_x_stage_seed_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  mode_slack_data : XStageModeAndSlackData,
  x_stage_seed : XPositionStageSeedData,
) -> XposFlatLabelAugmentation {
  build_x_stage_with_flat_label_augmentation_for_positions(
    mode_slack_data.xpos_reorder_enabled,
    mode_slack_data.use_vnodes_for_xpos,
    mode_slack_data.allow_xpos_reorder,
    mode_slack_data.graphviz_flip,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    x_stage_seed,
  )
}


///|
/// Graphviz parity: x-stage seed+flat-label output object maps seed base sizes
/// with flat-label augmentation data without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_seed_and_flat_label_output_for_positions(
  x_stage_seed : XPositionStageSeedData,
  flat_label_augmentation : XposFlatLabelAugmentation,
) -> XStageSeedAndFlatLabelData {
  let x_base_sizes = x_stage_seed.x_base_sizes
  { x_base_sizes, flat_label_augmentation }
}

///|
/// Graphviz parity: x-stage seed build and flat-label augmentation preserve the
/// same mode-gated reorder/transpose inputs and call order as Graphviz fixtures.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_seed_and_flat_label_data_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  mode_slack_data : XStageModeAndSlackData,
) -> XStageSeedAndFlatLabelData {
  let x_stage_seed =
    build_x_stage_seed_from_mode_slack_data_for_positions(
      prep,
      rank_data,
      cluster_meta,
      ordering,
      mode_slack_data,
    )
  let flat_label_augmentation =
    build_flat_label_augmentation_from_x_stage_seed_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      mode_slack_data,
      x_stage_seed,
    )
  build_x_stage_seed_and_flat_label_output_for_positions(
    x_stage_seed,
    flat_label_augmentation,
  )
}

///|
/// Graphviz parity: x-stage final bundle preserves mode/slack and flat-label
/// augmentation field mapping without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_output_from_mode_and_seed_data_for_positions(
  mode_slack_data : XStageModeAndSlackData,
  seed_flat_label_data : XStageSeedAndFlatLabelData,
) -> XStageWithFlatLabelData {
  let flat_label_augmentation = seed_flat_label_data.flat_label_augmentation
  {
    use_vnodes_for_xpos: mode_slack_data.use_vnodes_for_xpos,
    virtual_slack_edges: mode_slack_data.virtual_slack_edges,
    x_base_sizes: seed_flat_label_data.x_base_sizes,
    x_groups: flat_label_augmentation.x_groups,
    x_cluster_keys: flat_label_augmentation.x_cluster_keys,
    flat_label_edges: flat_label_augmentation.flat_label_edges,
    flat_label_nodes: flat_label_augmentation.flat_label_nodes,
    flat_label_edge_vnodes: flat_label_augmentation.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: x-stage mode/seed output object maps stage-local data
/// bundles without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_seed_output_for_positions(
  mode_slack_data : XStageModeAndSlackData,
  seed_flat_label_data : XStageSeedAndFlatLabelData,
) -> XStageModeAndSeedData {
  { mode_slack_data, seed_flat_label_data }
}

///|
/// Graphviz parity: x-stage mode/slack and seed/flat-label stages are executed
/// in fixed order before final x-stage output assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_seed_data_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XStageModeAndSeedData {
  let mode_slack_data =
    build_x_stage_mode_and_virtual_slack_data_for_positions(
      prep,
      rank_data,
      cluster_meta,
      ordering,
    )
  let seed_flat_label_data =
    build_x_stage_seed_and_flat_label_data_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      mode_slack_data,
    )
  build_x_stage_mode_and_seed_output_for_positions(
    mode_slack_data,
    seed_flat_label_data,
  )
}

///|
/// Graphviz parity: x-stage precompute in compute_positions keeps mode flags,
/// virtual-slack generation, reorder/transpose, and flat-label augmentation in
/// Graphviz-aligned order and wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_with_flat_labels_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XStageWithFlatLabelData {
  let x_stage_mode_and_seed_data =
    build_x_stage_mode_and_seed_data_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
    )
  build_x_stage_output_from_mode_and_seed_data_for_positions(
    x_stage_mode_and_seed_data.mode_slack_data,
    x_stage_mode_and_seed_data.seed_flat_label_data,
  )
}


///|
/// Graphviz parity: x-stage to projection handoff copies each computed field
/// unchanged before projection call wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_from_x_stage_data_for_positions(
  x_stage_data : XStageWithFlatLabelData,
) -> ProjectionFromXStageData {
  {
    use_vnodes_for_xpos: x_stage_data.use_vnodes_for_xpos,
    x_base_sizes: x_stage_data.x_base_sizes,
    x_groups: x_stage_data.x_groups,
    x_cluster_keys: x_stage_data.x_cluster_keys,
    virtual_slack_edges: x_stage_data.virtual_slack_edges,
    flat_label_edges: x_stage_data.flat_label_edges,
    flat_label_nodes: x_stage_data.flat_label_nodes,
    flat_label_edge_vnodes: x_stage_data.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: projection stage call consumes x-stage handoff fields and
/// rank-height maps directly, without extra remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_from_handoff_with_rank_maps_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  projection_from_x_stage_data : ProjectionFromXStageData,
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  build_projection_result_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    projection_from_x_stage_data.use_vnodes_for_xpos,
    projection_from_x_stage_data.x_base_sizes,
    projection_from_x_stage_data.x_groups,
    projection_from_x_stage_data.x_cluster_keys,
    projection_from_x_stage_data.virtual_slack_edges,
    projection_from_x_stage_data.flat_label_edges,
    projection_from_x_stage_data.flat_label_nodes,
    projection_from_x_stage_data.flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
  )
}

///|
/// Graphviz parity: projection handoff consumes x-stage bundle fields and rank
/// height maps without changing Graphviz-aligned parameter wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_from_x_stage_data_with_rank_maps_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_stage_data : XStageWithFlatLabelData,
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  let projection_from_x_stage_data =
    build_projection_from_x_stage_data_for_positions(x_stage_data)
  build_projection_result_from_handoff_with_rank_maps_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    projection_from_x_stage_data,
    rank_ht1,
    rank_ht2,
  )
}

///|
/// Graphviz parity: projection handoff rank-height maps are sourced directly
/// from rank_heights and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_rank_height_maps_for_projection_for_positions(
  rank_heights : RankHeights,
) -> PositionRankHeightMaps {
  { rank_ht1: rank_heights.rank_ht1, rank_ht2: rank_heights.rank_ht2 }
}

///|
/// Graphviz parity: projection handoff from x-stage bundle keeps field-to-parameter
/// wiring and rank-height map sourcing unchanged before final projection stage.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_from_x_stage_data_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_stage_data : XStageWithFlatLabelData,
) -> PositionResult {
  let projection_rank_height_maps =
    build_position_rank_height_maps_for_projection_for_positions(rank_heights)
  build_projection_result_from_x_stage_data_with_rank_maps_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    x_stage_data,
    projection_rank_height_maps.rank_ht1,
    projection_rank_height_maps.rank_ht2,
  )
}

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c + dotgen/cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> PositionResult {
  let x_stage_data =
    build_x_stage_with_flat_labels_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
    )
  build_projection_result_from_x_stage_data_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    x_stage_data,
  )
}
