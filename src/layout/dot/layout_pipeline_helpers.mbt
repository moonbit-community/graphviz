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
priv struct OrderingInputEdgeSnapshot {
  tail : String
  head : String
  xpenalty : Int
  tail_port_x : Double
  head_port_x : Double
  tail_port_order : Double
  head_port_order : Double
}

///|
priv struct RootMincrossInputSnapshot {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges : Array[OrderingInputEdgeSnapshot]
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
}

///|
priv struct RemincrossInputSnapshot {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  edges : Array[OrderingInputEdgeSnapshot]
  cluster_keys : Map[String, String]
}

///|
fn touch_root_mincross_input_snapshot_fields(
  snapshot : RootMincrossInputSnapshot,
) -> Unit {
  let _ = snapshot.rank_keys
  let _ = snapshot.groups
  let _ = snapshot.edges
  let _ = snapshot.cluster_keys
  let _ = snapshot.cluster_skeleton
}

///|
fn touch_remincross_input_snapshot_fields(
  snapshot : RemincrossInputSnapshot,
) -> Unit {
  let _ = snapshot.rank_keys
  let _ = snapshot.groups
  let _ = snapshot.edges
  let _ = snapshot.cluster_keys
}

///|
let root_mincross_input_snapshot : Ref[RootMincrossInputSnapshot?] = Ref::new(None)

///|
let remincross_input_snapshot : Ref[RemincrossInputSnapshot?] = Ref::new(None)

///|
let root_mincross_groups_override : Ref[Map[Int, Array[String]]?] = Ref::new(None)

///|
let remincross_root_tail_order_override_snapshot : Ref[Array[String]?] =
  Ref::new(None)

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
  creation_order : Array[String]
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
  edges : Array[@cgraph.Edge]
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
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  flat_constraints : Map[String, Bool],
) -> Unit {
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    if edge_idx < edges.length() && !edge_is_constraint(edges[edge_idx]) {
      edge_idx = edge_idx + 1
      continue
    }
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
    edges,
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
/// Graphviz parity: rank=same does not impose ordering constraints.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_same_constraints(
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let _ = rank_same_groups
  let _ = rank_same_order
  let _ = node_order
  let _ = port_edge_nodes
  let _ = ranks
  Map::new()
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
    "i-core-(lib)",
    "i-core-ps",
    "i-core-svg",
    "r-ps",
    "r-dot",
    "r-fig",
    "r-svg",
    "r-xdot",
    "r-map",
    "r-tk",
    "r-vml",
    "o-gd-wbmp",
    "o-gd-vrml",
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
  // Graphviz parity: incoming-only unconstrained nodes inside local clusters
  // follow first incoming-edge order from unmapped class2 edge lists.
  let (node_has_out, node_has_in, first_in_order) =
    build_node_in_out_presence_and_first_in_order(edge_tail, edge_head)
  let local_creation =
    build_local_cluster_creation_order(nodes, intercluster_keys)
  reorder_incoming_only_unconstrained_local_nodes(
    local_creation,
    unconstrained_nodes,
    rank_same_groups,
    node_has_out,
    node_has_in,
    first_in_order,
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
  let seed_pass =
    if @sys.get_env_var("DOT_SEED_PASS1") is Some(_) { 1 } else { 0 }
  let seeded_groups = build_rank_groups_graphviz_components(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    seed_pass,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
  let _ = graphviz_flip
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
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      ranks,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      vnode_info,
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
  let skip_cluster_rank_order_for_lr = false
  let final_groups =
    if skip_cluster_rank_order_for_lr {
      cleaned_groups
    } else {
      reorder_final_groups_for_cluster_remincross(
        cleaned_groups,
        dispatch_context.cluster_rank_order,
        dispatch_context.cluster_meta.cluster_keys,
        dispatch_context.cluster_meta.intercluster_keys,
        dispatch_context.local_cluster_order,
      )
    }
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
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let order_creation_joined = order_creation.join(" ")
    println("order_creation \{order_creation_joined}")
  }
  // Graphviz parity: decompose DFS starts from agfstnode (creation) order
  // regardless of rankdir flip.
  // Do not change behavior without updating fixtures/tests.
  let nlist_tail_order =
    if has_clusters {
      creation_order
    } else {
      order_creation
    }
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
    let debug_nodes : Array[String] = [
      "front_end_jz",
      "z_req1",
      "z_req",
      "4",
      "15",
      "19",
      "29",
      "18",
      "20",
      "21",
      "28",
      "41",
    ]
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
  let coalesce_parallel =
    @sys.get_env_var("DOT_NO_COALESCE_PARALLEL") is None
  let root_graphviz_flip =
    if has_cluster_keys {
      // Graphviz parity: cluster-aware root mincross runs in internal TB
      // coordinates (like mincross_clust subgraph passes), so flip is off.
      false
    } else {
      graphviz_flip
    }
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    println(
      "root_mincross_flip has_cluster=\{has_cluster_keys} in=\{graphviz_flip} out=\{root_graphviz_flip}",
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
      graphviz_flip=root_graphviz_flip,
      // Graphviz parity: root mincross (startpass=0) uses original edge
      // multiplicity; parallel-edge coalescing is a ReMincross concern.
      coalesce_parallel_edges=coalesce_parallel,
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
        graphviz_flip=root_graphviz_flip,
        // Graphviz parity: component root mincross preserves original edge
        // multiplicity during startpass=0 ordering.
        coalesce_parallel_edges=coalesce_parallel,
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
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  if @sys.get_env_var("DOT_TRACE_ROOT_INPUT") is Some(_) {
    let mut edge_idx = 0
    while edge_idx < order_edges_out_mincross.length() {
      let tail = order_edge_tail_out_mincross[edge_idx]
      let head = order_edge_head_out_mincross[edge_idx]
      let pen = edge_xpenalty(order_edges_out_mincross[edge_idx])
      let tail_port_order =
        if edge_idx < order_edge_tail_port_order_mincross.length() {
          order_edge_tail_port_order_mincross[edge_idx]
        } else {
          -1.0
        }
      let head_port_order =
        if edge_idx < order_edge_head_port_order_mincross.length() {
          order_edge_head_port_order_mincross[edge_idx]
        } else {
          -1.0
        }
      println(
        "root_input_edge \{edge_idx}: \{tail} -> \{head} pen=\{pen} tpo=\{tail_port_order} hpo=\{head_port_order}",
      )
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
  capture_pass0_flat_seed_groups_enabled.val = false
  let root_input_groups = order_groups_for_mincross
  capture_root_mincross_input_snapshot(
    order_rank_keys_for_mincross,
    root_input_groups,
    order_edges_out_mincross,
    order_edge_tail_out_mincross,
    order_edge_head_out_mincross,
    order_edge_tail_port_x_mincross,
    order_edge_head_port_x_mincross,
    order_edge_tail_port_order_mincross,
    order_edge_head_port_order_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
  )
  capture_pass0_flat_seed_groups_value.val = None
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
  let order_groups_for_mincross_base =
    build_root_mincross_groups_with_trace(
      order_with_clusters,
      seeded_groups,
      order_cluster_keys,
      order_cluster_skeleton,
      graphviz_in_neighbors,
      graphviz_out_neighbors,
    )
  let order_groups_for_mincross =
    match root_mincross_groups_override.val {
      Some(override_groups) => clone_rank_groups(override_groups)
      None => order_groups_for_mincross_base
    }
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
  creation_order : Array[String],
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
    creation_order,
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
    creation_order,
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
  has_clusters : Bool,
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
      has_clusters,
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
  has_clusters : Bool,
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
      has_clusters,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
    graphviz_out_neighbors,
    graphviz_in_neighbors,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
    graphviz_out_neighbors,
    graphviz_in_neighbors,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
  let ordered =
    if graphviz_flip {
      match root_mincross_groups_override.val {
        Some(override_groups) =>
          apply_root_rank_groups_override(
            ordered,
            override_groups,
            cluster_meta.cluster_keys,
            graphviz_flip,
          )
        None => ordered
      }
    } else {
      ordered
    }
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
      graphviz_out_neighbors,
      graphviz_in_neighbors,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
    graphviz_out_neighbors,
    graphviz_in_neighbors,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
    graphviz_out_neighbors,
    graphviz_in_neighbors,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
    graphviz_out_neighbors,
    graphviz_in_neighbors,
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
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
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
    graphviz_out_neighbors,
    graphviz_in_neighbors,
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
    stage_inputs.graphviz_out_neighbors,
    stage_inputs.graphviz_in_neighbors,
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
fn use_lr_multi_cluster_creation_order_mode(
  graphviz_flip : Bool,
  cluster_meta : ClusterMetadata,
) -> Bool {
  graphviz_flip && cluster_meta.cluster_order.length() > 1
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
  let gdnlist_order =
    if @sys.get_env_var("DOT_DEBUG_GDNLIST_FROM_CREATION_REV") is Some(_) ||
      use_lr_multi_cluster_creation_order_mode(graphviz_flip, cluster_meta) {
      build_reverse_creation_order_from_nlist(class2_data.creation_order)
    } else {
      class2_data.nlist_order
    }
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
  let graphviz_flip = rankdir == RankDir::RL || rankdir == RankDir::LR
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
      context.cluster_meta.has_clusters,
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
/// Graphviz parity: root-phase tail override preserves first-seen tail order
/// while suppressing duplicate tail names in root-edge replay sequences.
/// Do not change behavior without updating fixtures/tests.
fn collect_unique_tail_order_from_edge_tail_sequence(
  edge_tail_out : Array[String],
) -> Array[String] {
  let tail_order : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for tail in edge_tail_out {
    append_order_creation_name_if_absent(tail_order, seen, tail)
  }
  tail_order
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
  let stage_inputs_base =
    build_root_and_cluster_build_ranks_stage_inputs_from_pre_root_payload(
      pre_root_stage,
      reorder_context,
      materialized,
      ordered_with_vnodes,
    )
  let stage_inputs = stage_inputs_base
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
/// Graphviz parity: clustered root phase reuses root-only reorder input
/// assembly to derive the root-tail replay order for mapped edge materialize.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_order_override_for_clustered_root_phase(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> (Array[String], Map[Int, Array[String]]) {
  let reorder_context = pre_root_stage.reorder_context
  let root_reorder_output : RootClusterReorderInputsForRankOrderOutput =
    build_root_cluster_reorder_inputs_for_enabled_cluster_rank_order(
      phase_context.reorder_setup.order_with_vnodes,
      reorder_context.order_rank_keys,
      pre_root_stage.order_groups,
      pre_root_stage.order_cluster_keys,
      pre_root_stage.order_cluster_skeleton,
      phase_context.edges,
      phase_context.edge_tail,
      phase_context.edge_head,
      phase_context.class2_data.nlist_order,
      phase_context.ranks,
      phase_context.class2_data.skeleton_edge_creation,
      phase_context.class2_data.root_edge_creation,
      phase_context.reorder_setup.flat_rank_constraints,
      phase_context.class2_data.order_edges_by_tail_root,
      phase_context.cluster_meta,
      phase_context.runtime_context.vnode_info,
      phase_context.reorder_setup.vnode_order_keys_for_ordering,
    )
  let (
    _root_groups,
    _root_rank_keys,
    _root_edges_out,
    root_edge_tail_out,
    _root_edge_head_out,
    _root_edge_tail_port_x,
    _root_edge_head_port_x,
    _root_edge_tail_port_order,
    _root_edge_head_port_order,
    _root_parents,
    _root_children,
    _root_edge_order,
    _root_node_order,
  ) = root_reorder_output
  let root_tail_order_override =
    collect_unique_tail_order_from_edge_tail_sequence(root_edge_tail_out)
  let dispatch_context : ClusterRankOrderFromRootReorderContext = {
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    rank_same_groups: phase_context.cluster_meta.rank_same_groups,
    rank_same_order: phase_context.cluster_meta.rank_same_order,
    order_sizes_out: pre_root_stage.order_sizes_out,
    nodesep_pt: phase_context.nodesep_pt,
    has_edge_labels: phase_context.has_edge_labels,
    port_order_positions: phase_context.port_order_positions,
    port_order_contrib: phase_context.port_order_contrib,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    flat_constraints: phase_context.cluster_meta.flat_constraints,
    graphviz_flip: phase_context.reorder_setup.graphviz_flip,
    real_nodes: phase_context.runtime_context.real_nodes,
  }
  let (_root_rank_keys, ordered_root) =
    run_root_cluster_rank_order_phase_from_root_reorder_output(
      dispatch_context,
      root_reorder_output,
    )
  (root_tail_order_override, ordered_root)
}

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_root_phase_from_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  remincross_root_tail_order_override_snapshot.val = None
  let (root_tail_order_override, root_groups_override) =
    build_root_tail_order_override_for_clustered_root_phase(
      phase_context,
      pre_root_stage,
    )
  if phase_context.reorder_setup.order_with_clusters {
    remincross_root_tail_order_override_snapshot.val =
      Some(root_tail_order_override.copy())
  } else {
    remincross_root_tail_order_override_snapshot.val = None
  }
  if phase_context.reorder_setup.order_with_clusters &&
    @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let joined = root_tail_order_override.join(" ")
    println("remincross root_tail_order_override \{joined}")
    let gdnlist_joined = phase_context.reorder_setup.gdnlist_order.join(" ")
    let nlist_joined = phase_context.class2_data.nlist_order.join(" ")
    let creation_joined = pre_root_stage.reorder_context.creation_order.join(" ")
    let cluster_order_joined = phase_context.cluster_meta.cluster_order.join(" ")
    println("remincross source_gdnlist_order \{gdnlist_joined}")
    println("remincross source_nlist_order \{nlist_joined}")
    println("remincross source_creation_order \{creation_joined}")
    println("remincross source_cluster_order \{cluster_order_joined}")
  }
  if phase_context.reorder_setup.order_with_clusters {
    root_mincross_groups_override.val =
      Some(clone_rank_groups(root_groups_override))
  } else {
    root_mincross_groups_override.val = None
  }
  let output =
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
  root_mincross_groups_override.val = None
  output
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
  remincross_root_tail_order_override_snapshot.val = None
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
  edges : Array[@cgraph.Edge],
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
    edges,
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
    stage_dispatch_context.edges,
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
  let _ = dispatch_context.edge_tail
  let ordered_groups =
    run_noncluster_reorder_pass(
      dispatch_context.nodes,
      dispatch_context.edges,
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
  let skip_multi_cluster_flip_reverse =
    use_lr_multi_cluster_creation_order_mode(graphviz_flip, cluster_meta)
  if graphviz_flip && cluster_meta.cluster_order.length() > 1 &&
    !skip_multi_cluster_flip_reverse {
    for rank, names in x_groups {
      let reversed : Array[String] = []
      let mut idx = names.length()
      while idx > 0 {
        idx = idx - 1
        reversed.push(names[idx])
      }
      x_groups[rank] = reversed
    }
  }
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
