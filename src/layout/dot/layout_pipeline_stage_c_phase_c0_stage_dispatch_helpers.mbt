///|
/// Stage C Phase C0 split: ordering-stage clustered
/// and non-cluster dispatch helpers.

///|
/// Graphviz parity: clustered ordering stage returns finalized groups and
/// vnode-augmented groups with Graphviz tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (final_groups, next_ordered_with_vnodes)
}

///|
/// Graphviz parity: non-clustered ordering stage returns mincross groups plus
/// an empty vnode map (matching Graphviz no-vnode ordering path).
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_ordering_stage_output(
  ordered_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  (ordered_groups, ordered_with_vnodes)
}

///|
/// Graphviz parity: non-clustered ordering path still runs the single mincross
/// pass directly (matching Graphviz control flow).
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_ordering_stage_dispatch_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  nlist_order : Array[String],
  node_order : Map[String, Int],
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  cluster_meta : ClusterMetadata,
  edge_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> NonclusterOrderingStageDispatchContext {
  {
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    rank_keys,
    groups,
    nlist_order,
    node_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    cluster_meta,
    edge_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  }
}

///|
/// Graphviz parity: non-clustered ordering path still runs the single mincross
/// pass directly (matching Graphviz control flow).
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_ordering_stage(
  dispatch_context : NonclusterOrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let _ = dispatch_context.edge_tail
  let ordered_groups =
    run_noncluster_reorder_pass(
      dispatch_context.nodes,
      dispatch_context.edges,
      dispatch_context.edge_head,
      dispatch_context.edge_out_order,
      dispatch_context.ranks,
      dispatch_context.rank_keys,
      dispatch_context.groups,
      dispatch_context.nlist_order,
      dispatch_context.node_order,
      dispatch_context.order_edges,
      dispatch_context.order_edge_tail,
      dispatch_context.order_edge_head,
      dispatch_context.order_edge_tail_port_x,
      dispatch_context.order_edge_head_port_x,
      dispatch_context.order_edge_tail_port_order,
      dispatch_context.order_edge_head_port_order,
      dispatch_context.cluster_meta,
      dispatch_context.edge_order,
      dispatch_context.order_sizes,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      dispatch_context.graphviz_flip,
    )
  build_noncluster_ordering_stage_output(ordered_groups)
}

///|
/// Graphviz parity: dispatch setup fields are unpacked once and forwarded with
/// unchanged ordering into clustered/non-clustered stage dispatch helpers.
/// Do not change behavior without updating fixtures/tests.
fn unpack_ordering_dispatch_setup(
  dispatch_setup : OrderingDispatchSetup,
) -> (OrderingEdgePortData, OrderingReorderSetup, OrderingClass2Data) {
  let edge_port_data = dispatch_setup.edge_port_data
  let reorder_setup = dispatch_setup.reorder_setup
  let class2_data = reorder_setup.class2_data
  (edge_port_data, reorder_setup, class2_data)
}


///|
/// Graphviz parity: clustered dispatch path reads ordering inputs from a
/// shared stage-dispatch context and forwards them without reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage_from_context(
  dispatch_context : OrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (edge_port_data, reorder_setup, class2_data) =
    unpack_ordering_dispatch_setup(dispatch_context.dispatch_setup)
  let clustered_dispatch_context =
    build_clustered_ordering_stage_dispatch_context(
      dispatch_context.graph,
      dispatch_context.nodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_reversed,
      dispatch_context.ranks,
      dispatch_context.node_order,
      dispatch_context.order_sizes,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.cluster_meta,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      dispatch_context.runtime_context,
      edge_port_data,
      reorder_setup,
      class2_data,
    )
  run_clustered_ordering_stage(clustered_dispatch_context)
}

///|
/// Graphviz parity: non-clustered dispatch path continues to run a single
/// mincross pass using the same stage-dispatch context payloads.
/// Do not change behavior without updating fixtures/tests.
fn run_noncluster_ordering_stage_from_context(
  dispatch_context : OrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (edge_port_data, reorder_setup, class2_data) =
    unpack_ordering_dispatch_setup(dispatch_context.dispatch_setup)
  let noncluster_dispatch_context =
    build_noncluster_ordering_stage_dispatch_context(
      dispatch_context.nodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
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
  run_noncluster_ordering_stage(noncluster_dispatch_context)
}

///|
/// Graphviz parity: dispatch clustered ordering when vnode/cluster mode is
/// active, matching Graphviz mincross control gating.
/// Do not change behavior without updating fixtures/tests.
fn should_run_clustered_ordering_stage(
  reorder_setup : OrderingReorderSetup,
) -> Bool {
  reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters
}

///|
/// Graphviz parity: ordering-stage dispatch context builder preserves
/// clustered/non-clustered branch payload ordering before dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_stage_dispatch_context(
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
) -> OrderingStageDispatchContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    rank_keys,
    groups,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    dispatch_setup,
  }
}

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_stage_dispatch(
  dispatch_context : OrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_setup = dispatch_context.dispatch_setup.reorder_setup
  if should_run_clustered_ordering_stage(reorder_setup) {
    run_clustered_ordering_stage_from_context(dispatch_context)
  } else {
    run_noncluster_ordering_stage_from_context(dispatch_context)
  }
}


