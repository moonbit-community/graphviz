///|
/// Stage C Phase C5 split: remincross clustered multi rank dispatch
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross multi-rank branch materializes
/// remapped edges and executes clustered cleanup reorder in startpass=2 flow.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (rem_ranks, rem_nodes, rem_graph, rem_node_map) =
    build_clustered_remincross_graph_inputs(
      rem_groups,
      rem_rank_keys,
    )
  // Graphviz parity: ReMincross uses real intercluster edges
  // (no cluster skeleton mapping).
  let cluster_order_index =
    build_cluster_index_for_local_reorder(dispatch_context.cluster_meta.cluster_order)
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
    build_clustered_remincross_materialized_edges(
      dispatch_context.creation_order,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_tail_port_x,
      dispatch_context.edge_head_port_x,
      dispatch_context.edge_tail_port_order,
      dispatch_context.edge_head_port_order,
      dispatch_context.ranks,
      dispatch_context.vnode_info.edge_vnodes,
      dispatch_context.order_with_vnodes,
      dispatch_context.cluster_meta.intercluster_keys,
      dispatch_context.order_with_clusters,
      dispatch_context.edges_by_tail,
      cluster_order_index,
      dispatch_context.flat_rank_constraints,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  let (
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  ) =
    build_remincross_reorder_inputs(
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
      rem_groups,
      dispatch_context.real_nodes,
    )
  let (rem_parents, rem_children, rem_edge_order) =
    build_clustered_remincross_edge_indices_for_reorder(
      rem_nodes,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_ranks,
      rem_edges_out,
    )
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
    dispatch_context.cluster_meta.rank_same_groups,
    dispatch_context.cluster_meta.rank_same_order,
    rem_edge_order,
    rem_node_order,
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
/// Stage C Phase C5 split: clustered reorder-step
/// finalize-phase execution helpers.

///|
/// Stage C Phase C5 split: remincross stage types
/// helpers for focused ReMincross responsibilities.

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
