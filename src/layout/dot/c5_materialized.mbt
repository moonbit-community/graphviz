///|
/// Stage C Phase C5 split: clustered materialized-edge
/// reorder/input orchestration helpers.

///|
/// Graphviz parity: clustered ReMincross rematerialized-order-edge payload
/// keeps bonus-adjusted tail buckets, vnode creation, and edge creation replay.
priv struct ReMincrossMaterializedOrderEdges {
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  vnode_creation : Map[String, Array[String]]
  edge_creation : Array[(String, String)]
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge payload keeps node
/// order plus rematerialized edge arrays for cleanup reorder input.
priv struct ReMincrossMaterializedEdgeArrays {
  node_order : Map[String, Int]
  edges_out : Array[@cgraph.Edge]
  edge_tail_out : Array[String]
  edge_head_out : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: clustered ReMincross order-edge rematerialization applies
/// ND_out expansion, coalescing, intercluster bonus, then tail-order replay.
fn build_materialized_edges(
  dispatch_context : ReMincrossDispatchContext,
  cluster_order_index : Map[String, Int],
) -> ReMincrossMaterializedOrderEdges {
  let rem_order_edges_output =
    @ordering.build_order_edges_by_tail(
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
      false,
      false,
      dispatch_context.edges_by_tail,
      cluster_order_index=cluster_order_index,
    )
  let rem_order_edges_by_tail_raw = rem_order_edges_output.order_edges_by_tail
  let rem_vnode_creation = rem_order_edges_output.vnode_creation_by_tail
  let rem_order_edges_by_tail_coalesced =
    @ordering.coalesce_order_edges_by_tail(rem_order_edges_by_tail_raw)
  let intercluster_bonus =
    @ordering.collect_intercluster_bonus(
      dispatch_context.creation_order,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_tail_port_order,
      dispatch_context.edge_head_port_order,
      dispatch_context.ranks,
      dispatch_context.vnode_info.edge_vnodes,
      dispatch_context.order_with_vnodes,
      dispatch_context.order_with_clusters,
      dispatch_context.edges_by_tail,
      dispatch_context.cluster_meta.intercluster_keys,
    )
  let rem_order_edges_by_tail =
    @ordering.apply_intercluster_bonus(
      rem_order_edges_by_tail_coalesced,
      intercluster_bonus,
    )
  // Graphviz parity: rematerialized ReMincross edge-creation replay walks
  // each tail bucket in creation-order sequence and preserves ND_out order.
  let rem_edge_creation : Array[(String, String)] = []
  for tail_name in dispatch_context.creation_order {
    let entries = rem_order_edges_by_tail.get(tail_name).unwrap_or_default()
    for entry in entries {
      let (tail, head, _, _, _, _, _, _) = entry
      rem_edge_creation.push((tail, head))
    }
  }
  {
    order_edges_by_tail: rem_order_edges_by_tail,
    vnode_creation: rem_vnode_creation,
    edge_creation: rem_edge_creation,
  }
}

///|
/// Graphviz parity: ReMincross order-graph materialization rebuilds GD_nlist,
/// seeds node order, then materializes edge arrays in nlist tail order.
fn build_materialized_arrays(
  dispatch_context : ReMincrossDispatchContext,
  rem_groups : Map[Int, Array[String]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  cluster_order_index : Map[String, Int],
  materialized_edges : ReMincrossMaterializedOrderEdges,
) -> ReMincrossMaterializedEdgeArrays {
  let rem_ranks = @ordering.build_node_ranks(rem_groups)
  let rem_nlist_order =
    @ordering.build_remincross_nlist_order(
      dispatch_context.creation_order,
      materialized_edges.vnode_creation,
      materialized_edges.edge_creation,
      rem_ranks,
      dispatch_context.cluster_meta.intercluster_keys,
      cluster_order_index,
      remincross_root_tail_order_override_snapshot.val,
    )
  let rem_node_order = @ordering.build_order_index(rem_groups)
  let rem_materialized =
    @ordering.collect_order_edges_for_tails(
      rem_nlist_order,
      materialized_edges.order_edges_by_tail,
      rem_graph,
      rem_node_map,
    )
  {
    node_order: rem_node_order,
    edges_out: rem_materialized.order_edges_out,
    edge_tail_out: rem_materialized.order_edge_tail_out,
    edge_head_out: rem_materialized.order_edge_head_out,
    edge_tail_port_x: rem_materialized.order_edge_tail_port_x,
    edge_head_port_x: rem_materialized.order_edge_head_port_x,
    edge_tail_port_order: rem_materialized.order_edge_tail_port_order,
    edge_head_port_order: rem_materialized.order_edge_head_port_order,
  }
}
