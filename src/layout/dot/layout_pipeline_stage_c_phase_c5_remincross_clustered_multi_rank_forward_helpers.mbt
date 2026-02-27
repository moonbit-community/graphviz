///|
/// Stage C Phase C5 split: clustered multi-rank forward
/// helpers for cleanup reorder dispatch.

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

