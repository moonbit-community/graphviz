///|
/// Stage C Phase C8 split: ordering dispatch-context and result assembly helpers.

///|
/// Graphviz parity: ordering dispatch context captures stage-C clustered/non-
/// clustered inputs without reordering fields before dispatch execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_dispatch_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  pipeline_context : OrderingPipelineContext,
) -> ClusteredDispatchContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    rank_keys,
    groups,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
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
