///|
/// Extracted from layout_pipeline_stage_types_helpers.mbt to keep
/// ordering input-payload type definitions isolated.

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
