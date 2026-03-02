///|
/// Stage C Phase C0 split: ordering-stage clustered
/// and non-cluster dispatch helpers.

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch(
  dispatch_context : ClusteredDispatchContext,
  edge_out_order : Map[String, Array[Int]],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  if reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters {
    run_clustered(dispatch_context)
  } else {
    let ordered_groups =
      run_noncluster_reorder_pass(
        dispatch_context.nodes,
        dispatch_context.edges,
        dispatch_context.edge_head,
        edge_out_order,
        dispatch_context.ranks,
        rank_keys,
        groups,
        reorder_setup.class2_data.nlist_order,
        dispatch_context.node_order,
        dispatch_context.edge_port_data.order_edges,
        dispatch_context.edge_port_data.order_edge_tail,
        dispatch_context.edge_port_data.order_edge_head,
        dispatch_context.edge_port_data.order_edge_tail_port_x,
        dispatch_context.edge_port_data.order_edge_head_port_x,
        dispatch_context.edge_port_data.order_edge_tail_port_order,
        dispatch_context.edge_port_data.order_edge_head_port_order,
        dispatch_context.cluster_meta,
        dispatch_context.edge_port_data.edge_order,
        dispatch_context.order_sizes,
        dispatch_context.nodesep_pt,
        dispatch_context.has_edge_labels,
        dispatch_context.port_order_positions,
        dispatch_context.port_order_contrib,
        reorder_setup.graphviz_flip,
      )
    {
      ordered_groups,
      ordered_with_vnodes: Map::new(),
    }
  }
}
