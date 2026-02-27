///|
/// Stage C Phase C5 split: remincross clustered multi rank dispatch
/// helpers for focused ReMincross responsibilities.

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
  let input_context : ClusteredReMincrossMultiRankReorderInputsContext = {
    creation_order: dispatch_context.creation_order,
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    edge_tail_port_x: dispatch_context.edge_tail_port_x,
    edge_head_port_x: dispatch_context.edge_head_port_x,
    edge_tail_port_order: dispatch_context.edge_tail_port_order,
    edge_head_port_order: dispatch_context.edge_head_port_order,
    ranks: dispatch_context.ranks,
    order_with_vnodes: dispatch_context.order_with_vnodes,
    order_with_clusters: dispatch_context.order_with_clusters,
    flat_rank_constraints: dispatch_context.flat_rank_constraints,
    edges_by_tail: dispatch_context.edges_by_tail,
    cluster_meta: dispatch_context.cluster_meta,
    vnode_info: dispatch_context.vnode_info,
  }
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
  ) =
    build_clustered_remincross_multi_rank_reorder_inputs(
      input_context,
      dispatch_context.rem_groups,
      dispatch_context.rem_rank_keys,
    )
  let reorder_step_context : ClusteredReMincrossReorderStepContext = {
    graph: dispatch_context.graph,
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    order_with_vnodes: dispatch_context.order_with_vnodes,
    order_with_clusters: dispatch_context.order_with_clusters,
    ranks: dispatch_context.ranks,
    cluster_meta: dispatch_context.cluster_meta,
    vnode_info: dispatch_context.vnode_info,
    order_sizes: dispatch_context.order_sizes,
    rank_same_constraints: dispatch_context.rank_same_constraints,
    rem_rank_keys: dispatch_context.rem_rank_keys,
    rem_groups: dispatch_context.rem_groups,
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
    real_nodes: dispatch_context.real_nodes,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    graphviz_flip: dispatch_context.graphviz_flip,
  }
  run_clustered_remincross_reorder_step(reorder_step_context)
}
