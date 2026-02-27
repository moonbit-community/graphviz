///|
/// Stage C Phase C5 split: remincross clustered groups
/// helpers for focused ReMincross responsibilities.

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
  } else {
    (ordered_with_vnodes, base_groups)
  }
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
  prefer_seeded_from_ordered_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> Map[Int, Array[String]] {
  if order_with_vnodes &&
    (cluster_meta.cluster_order.length() == 1 || prefer_seeded_from_ordered_with_vnodes) {
    let seeded =
      build_remincross_groups_from_ordered_with_vnodes(
        base_groups,
        ordered_with_vnodes,
        cluster_meta.cluster_keys,
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
