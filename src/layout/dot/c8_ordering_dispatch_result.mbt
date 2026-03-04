///|
/// Stage C Phase C8 split: ordering dispatch-context and result assembly helpers.

///|
/// Graphviz parity: ordering dispatch context captures stage-C clustered/non-
/// clustered inputs without reordering fields before dispatch execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_dispatch_context(
  input : OrderingStageInput,
  pipeline_context : OrderingPipelineContext,
) -> ClusteredDispatchContext {
  {
    graph: input.graph,
    nodes: input.nodes,
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_reversed: input.edge_reversed,
    edge_out_order: input.edge_out_order,
    rank_keys: input.rank_keys,
    groups: input.groups,
    ranks: input.ranks,
    node_order: input.node_order,
    order_sizes: input.order_sizes,
    nodesep_pt: input.nodesep_pt,
    has_edge_labels: input.has_edge_labels,
    cluster_meta: input.cluster_meta,
    port_order_positions: input.port_order_positions,
    port_order_contrib: input.port_order_contrib,
    runtime_context: pipeline_context.runtime_context,
    edge_port_data: pipeline_context.edge_port_data,
    reorder_setup: pipeline_context.reorder_setup,
  }
}

///|
/// Graphviz parity: ordering result assembly forwards dispatch and pipeline
/// snapshots in Graphviz-aligned field composition order.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result(
  pipeline_context : OrderingPipelineContext,
  dispatch_output : OrderingDispatchOutput,
) -> OrderingResult {
  {
    ordered_groups: dispatch_output.ordered_groups,
    ordered_groups_with_vnodes: dispatch_output.ordered_with_vnodes,
    vnode_info: pipeline_context.runtime_context.vnode_info,
    vnode_count: pipeline_context.runtime_context.vnode_info.vnode_ranks.length(),
    order_edges: pipeline_context.edge_port_data.order_edges,
    order_edge_tail: pipeline_context.edge_port_data.order_edge_tail,
    order_edge_head: pipeline_context.edge_port_data.order_edge_head,
    edge_order: pipeline_context.edge_port_data.edge_order,
    edge_cluster_keys: pipeline_context.runtime_context.edge_cluster_keys,
    nlist_order: pipeline_context.reorder_setup.class2_data.nlist_order,
    gdnlist_order: pipeline_context.reorder_setup.gdnlist_order,
    vnode_creation_order:
      pipeline_context.reorder_setup.class2_data.vnode_creation_order,
  }
}
