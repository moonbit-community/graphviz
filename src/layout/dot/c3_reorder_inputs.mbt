///|
/// Stage C Phase C3 split: cluster-local reorder dispatch payload.

///|
/// Graphviz parity: cluster-local reorder dispatch context keeps shared
/// arrays/maps together so each cluster pass reuses one immutable payload.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderDispatchContext {
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  neighbor_sources : @ordering.ClusterLocalNeighborSources
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_meta : ClusterMetadata
  vnode_info : @routing.EdgeVnodeInfo
  fixed_ranks : Map[String, Int]
  order_with_vnodes : Bool
}
