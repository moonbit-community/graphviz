///|
/// Stage C Phase C0 split: ordering-stage clustered
/// and non-cluster dispatch helpers.

///|
/// Graphviz parity: ordering dispatch inputs keep clustered/non-clustered
/// branch payload unchanged before Stage C0 dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingDispatchInputs {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  dispatch_setup : OrderingDispatchSetup
}

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch(
  inputs : OrderingDispatchInputs,
) -> OrderingDispatchOutput {
  let reorder_setup = inputs.dispatch_setup.reorder_setup
  if reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters {
    let dispatch_context =
      build_clustered_dispatch_context(inputs)
    run_clustered(dispatch_context)
  } else {
    run_noncluster_ordering_dispatch(inputs)
  }
}

///|
/// Graphviz parity: clustered ordering dispatch context preserves payload field
/// ordering before clustered stage execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_dispatch_context(
  inputs : OrderingDispatchInputs,
) -> ClusteredDispatchContext {
  let dispatch_setup = inputs.dispatch_setup
  let reorder_setup = dispatch_setup.reorder_setup
  {
    graph: inputs.graph,
    nodes: inputs.nodes,
    edges: inputs.edges,
    edge_tail: inputs.edge_tail,
    edge_head: inputs.edge_head,
    edge_reversed: inputs.edge_reversed,
    ranks: inputs.ranks,
    node_order: inputs.node_order,
    order_sizes: inputs.order_sizes,
    nodesep_pt: inputs.nodesep_pt,
    has_edge_labels: inputs.has_edge_labels,
    cluster_meta: inputs.cluster_meta,
    port_order_positions: inputs.port_order_positions,
    port_order_contrib: inputs.port_order_contrib,
    runtime_context: inputs.runtime_context,
    edge_port_data: dispatch_setup.edge_port_data,
    reorder_setup,
    class2_data: reorder_setup.class2_data,
  }
}

///|
/// Graphviz parity: non-clustered ordering path still runs a single mincross
/// pass directly (matching Graphviz control flow).
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_ordering_dispatch(
  inputs : OrderingDispatchInputs,
) -> OrderingDispatchOutput {
  let dispatch_setup = inputs.dispatch_setup
  let edge_port_data = dispatch_setup.edge_port_data
  let reorder_setup = dispatch_setup.reorder_setup
  let ordered_groups =
    run_noncluster_reorder_pass(
      inputs.nodes,
      inputs.edges,
      inputs.edge_head,
      inputs.edge_out_order,
      inputs.ranks,
      inputs.rank_keys,
      inputs.groups,
      reorder_setup.class2_data.nlist_order,
      inputs.node_order,
      edge_port_data.order_edges,
      edge_port_data.order_edge_tail,
      edge_port_data.order_edge_head,
      edge_port_data.order_edge_tail_port_x,
      edge_port_data.order_edge_head_port_x,
      edge_port_data.order_edge_tail_port_order,
      edge_port_data.order_edge_head_port_order,
      inputs.cluster_meta,
      edge_port_data.edge_order,
      inputs.order_sizes,
      inputs.nodesep_pt,
      inputs.has_edge_labels,
      inputs.port_order_positions,
      inputs.port_order_contrib,
      reorder_setup.graphviz_flip,
    )
  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  {
    ordered_groups,
    ordered_with_vnodes,
  }
}
