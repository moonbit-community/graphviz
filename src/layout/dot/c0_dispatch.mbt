///|
/// Stage C Phase C0 split: ordering-stage clustered
/// and non-cluster dispatch helpers.

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingDispatchOutput {
  let edge_port_data = dispatch_setup.edge_port_data
  let reorder_setup = dispatch_setup.reorder_setup
  if reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters {
    let dispatch_context =
      build_clustered_dispatch_context(
        graph,
        nodes,
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        node_order,
        order_sizes,
        nodesep_pt,
        has_edge_labels,
        cluster_meta,
        port_order_positions,
        port_order_contrib,
        runtime_context,
        edge_port_data,
        reorder_setup,
      )
    run_clustered(dispatch_context)
  } else {
    run_noncluster_ordering_dispatch(
      nodes,
      edges,
      edge_head,
      edge_out_order,
      ranks,
      rank_keys,
      groups,
      node_order,
      cluster_meta,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      edge_port_data,
      reorder_setup,
    )
  }
}

///|
/// Graphviz parity: clustered ordering dispatch context preserves payload field
/// ordering before clustered stage execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_dispatch_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  edge_port_data : OrderingEdgePortData,
  reorder_setup : OrderingReorderSetup,
) -> ClusteredDispatchContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    edge_port_data,
    reorder_setup,
    class2_data: reorder_setup.class2_data,
  }
}

///|
/// Graphviz parity: non-clustered ordering path still runs a single mincross
/// pass directly (matching Graphviz control flow).
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_ordering_dispatch(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  cluster_meta : ClusterMetadata,
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  edge_port_data : OrderingEdgePortData,
  reorder_setup : OrderingReorderSetup,
) -> OrderingDispatchOutput {
  let ordered_groups =
    run_noncluster_reorder_pass(
      nodes,
      edges,
      edge_head,
      edge_out_order,
      ranks,
      rank_keys,
      groups,
      reorder_setup.class2_data.nlist_order,
      node_order,
      edge_port_data.order_edges,
      edge_port_data.order_edge_tail,
      edge_port_data.order_edge_head,
      edge_port_data.order_edge_tail_port_x,
      edge_port_data.order_edge_head_port_x,
      edge_port_data.order_edge_tail_port_order,
      edge_port_data.order_edge_head_port_order,
      cluster_meta,
      edge_port_data.edge_order,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      reorder_setup.graphviz_flip,
    )
  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  {
    ordered_groups,
    ordered_with_vnodes,
  }
}
