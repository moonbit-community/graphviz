///|
/// Extracted from layout_pipeline_stage_c_remincross_clustered_multi_rank_dispatch_helpers.mbt
/// to isolate Stage C clustered ReMincross multi-rank reorder-input helpers.

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
  let cluster_order_index =
    build_cluster_index_for_local_reorder(cluster_meta.cluster_order)
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
    cluster_meta.intercluster_keys,
    order_with_clusters,
    edges_by_tail,
    cluster_order_index,
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
