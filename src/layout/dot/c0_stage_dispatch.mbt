///|
/// Stage C Phase C0 split: ordering-stage clustered
/// and non-cluster dispatch helpers.

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_stage_dispatch(
  dispatch_context : OrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let dispatch_setup = dispatch_context.dispatch_setup
  let edge_port_data = dispatch_setup.edge_port_data
  let reorder_setup = dispatch_setup.reorder_setup
  let class2_data = reorder_setup.class2_data
  if reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters {
    let clustered_dispatch_context : ClusteredOrderingStageDispatchContext = {
      graph: dispatch_context.graph,
      nodes: dispatch_context.nodes,
      edges: dispatch_context.edges,
      edge_tail: dispatch_context.edge_tail,
      edge_head: dispatch_context.edge_head,
      edge_reversed: dispatch_context.edge_reversed,
      ranks: dispatch_context.ranks,
      node_order: dispatch_context.node_order,
      order_sizes: dispatch_context.order_sizes,
      nodesep_pt: dispatch_context.nodesep_pt,
      has_edge_labels: dispatch_context.has_edge_labels,
      cluster_meta: dispatch_context.cluster_meta,
      port_order_positions: dispatch_context.port_order_positions,
      port_order_contrib: dispatch_context.port_order_contrib,
      runtime_context: dispatch_context.runtime_context,
      edge_port_data,
      reorder_setup,
      class2_data,
    }
    run_clustered_ordering_stage(clustered_dispatch_context)
  } else {
    // Graphviz parity: non-clustered ordering path still runs a single
    // mincross pass directly (matching Graphviz control flow).
    let ordered_groups =
      run_noncluster_reorder_pass(
        dispatch_context.nodes,
        dispatch_context.edges,
        dispatch_context.edge_head,
        dispatch_context.edge_out_order,
        dispatch_context.ranks,
        dispatch_context.rank_keys,
        dispatch_context.groups,
        class2_data.nlist_order,
        dispatch_context.node_order,
        edge_port_data.order_edges,
        edge_port_data.order_edge_tail,
        edge_port_data.order_edge_head,
        edge_port_data.order_edge_tail_port_x,
        edge_port_data.order_edge_head_port_x,
        edge_port_data.order_edge_tail_port_order,
        edge_port_data.order_edge_head_port_order,
        dispatch_context.cluster_meta,
        edge_port_data.edge_order,
        dispatch_context.order_sizes,
        dispatch_context.nodesep_pt,
        dispatch_context.has_edge_labels,
        dispatch_context.port_order_positions,
        dispatch_context.port_order_contrib,
        reorder_setup.graphviz_flip,
      )
    let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
    (ordered_groups, ordered_with_vnodes)
  }
}
