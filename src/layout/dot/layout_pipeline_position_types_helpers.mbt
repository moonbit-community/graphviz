///|
/// Extracted from layout_pipeline_helpers.mbt to keep position/xpos
/// stage type definitions isolated and easier to maintain.

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

