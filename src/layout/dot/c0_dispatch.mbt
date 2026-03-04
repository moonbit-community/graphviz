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
    let noncluster_inputs =
      @ordering.build_noncluster_reorder_inputs_from_sources(
        {
          nodes: dispatch_context.nodes,
          edges: dispatch_context.edges,
          edge_head: dispatch_context.edge_head,
          edge_out_order,
          ranks: dispatch_context.ranks,
          rank_keys,
          groups,
          node_order: dispatch_context.node_order,
          cluster_keys: dispatch_context.cluster_meta.cluster_keys,
          cluster_skeleton: dispatch_context.cluster_meta.cluster_skeleton,
          rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
          rank_same_order: dispatch_context.cluster_meta.rank_same_order,
          order_sizes: dispatch_context.order_sizes,
          nodesep_pt: dispatch_context.nodesep_pt,
          has_edge_labels: dispatch_context.has_edge_labels,
          port_order_positions: dispatch_context.port_order_positions,
          port_order_contrib: dispatch_context.port_order_contrib,
          flat_constraints: dispatch_context.cluster_meta.flat_constraints,
          reorder_setup: dispatch_context.reorder_setup,
          edge_port_data: dispatch_context.edge_port_data,
        },
      )
    let ordered_groups =
      @ordering.run_noncluster_reorder_pass(noncluster_inputs)
    {
      ordered_groups,
      ordered_with_vnodes: Map::new(),
    }
  }
}
