///|
/// Stage C Phase C0 split: ordering-stage clustered
/// and non-cluster dispatch helpers.

///|
/// Graphviz parity: non-cluster rank reorder pass dispatches exactly one
/// reorder_rank_groups call using the precomputed non-cluster call payload.
fn run_noncluster_rank_reorder(
  call_inputs : @ordering.NonclusterRankReorderInputs,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    call_inputs.rank_keys,
    call_inputs.groups,
    call_inputs.order_edges,
    call_inputs.order_edge_tail,
    call_inputs.order_edge_head,
    call_inputs.order_edge_tail_port_x,
    call_inputs.order_edge_head_port_x,
    call_inputs.order_edge_tail_port_order,
    call_inputs.order_edge_head_port_order,
    call_inputs.parents,
    call_inputs.children,
    call_inputs.cluster_keys,
    call_inputs.rank_same_groups,
    call_inputs.rank_same_order,
    call_inputs.edge_order,
    call_inputs.order_node_order,
    call_inputs.order_sizes,
    call_inputs.nodesep_pt,
    call_inputs.has_edge_labels,
    call_inputs.port_order_positions,
    call_inputs.port_order_contrib,
    Map::new(),
    call_inputs.cluster_skeleton,
    call_inputs.flat_constraints,
    graphviz_out_neighbors=call_inputs.graphviz_out_neighbors,
    graphviz_in_neighbors=call_inputs.graphviz_in_neighbors,
    graphviz_flip=call_inputs.graphviz_flip,
  )
}

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
      @ordering.run_noncluster_reorder_pass(
        {
          nodes: dispatch_context.nodes,
          edges: dispatch_context.edges,
          edge_head: dispatch_context.edge_head,
          edge_out_order,
          ranks: dispatch_context.ranks,
          rank_keys,
          groups,
          nlist_order: reorder_setup.class2_data.nlist_order,
          node_order: dispatch_context.node_order,
          order_edges: dispatch_context.edge_port_data.order_edges,
          order_edge_tail: dispatch_context.edge_port_data.order_edge_tail,
          order_edge_head: dispatch_context.edge_port_data.order_edge_head,
          order_edge_tail_port_x:
            dispatch_context.edge_port_data.order_edge_tail_port_x,
          order_edge_head_port_x:
            dispatch_context.edge_port_data.order_edge_head_port_x,
          order_edge_tail_port_order:
            dispatch_context.edge_port_data.order_edge_tail_port_order,
          order_edge_head_port_order:
            dispatch_context.edge_port_data.order_edge_head_port_order,
          cluster_keys: dispatch_context.cluster_meta.cluster_keys,
          cluster_skeleton: dispatch_context.cluster_meta.cluster_skeleton,
          rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
          rank_same_order: dispatch_context.cluster_meta.rank_same_order,
          edge_order: dispatch_context.edge_port_data.edge_order,
          order_sizes: dispatch_context.order_sizes,
          nodesep_pt: dispatch_context.nodesep_pt,
          has_edge_labels: dispatch_context.has_edge_labels,
          port_order_positions: dispatch_context.port_order_positions,
          port_order_contrib: dispatch_context.port_order_contrib,
          flat_constraints: dispatch_context.cluster_meta.flat_constraints,
          graphviz_flip: reorder_setup.graphviz_flip,
        },
        run_noncluster_rank_reorder,
      )
    {
      ordered_groups,
      ordered_with_vnodes: Map::new(),
    }
  }
}
