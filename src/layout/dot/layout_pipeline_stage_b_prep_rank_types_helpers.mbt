///|
/// Stage-focused split to keep layout prep/rank
/// data-model type definitions isolated and maintainable.

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
