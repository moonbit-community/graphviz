///|
/// Stage C Phase C5 split: remincross clustered multi rank dispatch
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross multi-rank branch materializes
/// remapped edges and executes clustered cleanup reorder in startpass=2 flow.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank(
  dispatch_context : ClusteredReMincrossMultiRankDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let input_context : ClusteredReMincrossMultiRankReorderInputsContext = {
    creation_order: dispatch_context.creation_order,
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    edge_tail_port_x: dispatch_context.edge_tail_port_x,
    edge_head_port_x: dispatch_context.edge_head_port_x,
    edge_tail_port_order: dispatch_context.edge_tail_port_order,
    edge_head_port_order: dispatch_context.edge_head_port_order,
    ranks: dispatch_context.ranks,
    order_with_vnodes: dispatch_context.order_with_vnodes,
    order_with_clusters: dispatch_context.order_with_clusters,
    flat_rank_constraints: dispatch_context.flat_rank_constraints,
    edges_by_tail: dispatch_context.edges_by_tail,
    cluster_meta: dispatch_context.cluster_meta,
    vnode_info: dispatch_context.vnode_info,
  }
  let (
    rem_node_order,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_clustered_remincross_multi_rank_reorder_inputs(
      input_context,
      dispatch_context.rem_groups,
      dispatch_context.rem_rank_keys,
    )
  let reorder_step_context : ClusteredReMincrossReorderStepContext = {
    graph: dispatch_context.graph,
    edges: dispatch_context.edges,
    edge_tail: dispatch_context.edge_tail,
    edge_head: dispatch_context.edge_head,
    order_with_vnodes: dispatch_context.order_with_vnodes,
    order_with_clusters: dispatch_context.order_with_clusters,
    ranks: dispatch_context.ranks,
    cluster_meta: dispatch_context.cluster_meta,
    vnode_info: dispatch_context.vnode_info,
    order_sizes: dispatch_context.order_sizes,
    rank_same_constraints: dispatch_context.rank_same_constraints,
    rem_rank_keys: dispatch_context.rem_rank_keys,
    rem_groups: dispatch_context.rem_groups,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_node_order,
    real_nodes: dispatch_context.real_nodes,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    graphviz_flip: dispatch_context.graphviz_flip,
  }
  run_clustered_remincross_reorder_step(reorder_step_context)
}

///|
/// Graphviz parity: clustered ReMincross multi-rank reorder inputs are built
/// from vnode-augmented rem_groups via temporary order graph + rematerialized
/// edge arrays seeded from GD_nlist order.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_reorder_inputs(
  input_context : ClusteredReMincrossMultiRankReorderInputsContext,
  rem_groups : Map[Int, Array[String]],
  rem_rank_keys : Array[Int],
) -> (
  Map[String, Int],
  Array[String],
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (rem_ranks, rem_nodes, rem_graph, rem_node_map) =
    build_clustered_remincross_graph_inputs(rem_groups, rem_rank_keys)
  // Graphviz parity: ReMincross uses real intercluster edges
  // (no cluster skeleton mapping).
  let cluster_order_index =
    build_cluster_index_for_local_reorder(input_context.cluster_meta.cluster_order)
  let (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    build_clustered_remincross_materialized_edges(
      input_context.creation_order,
      input_context.edges,
      input_context.edge_tail,
      input_context.edge_head,
      input_context.edge_tail_port_x,
      input_context.edge_head_port_x,
      input_context.edge_tail_port_order,
      input_context.edge_head_port_order,
      input_context.ranks,
      input_context.vnode_info.edge_vnodes,
      input_context.order_with_vnodes,
      input_context.cluster_meta.intercluster_keys,
      input_context.order_with_clusters,
      input_context.edges_by_tail,
      cluster_order_index,
      input_context.flat_rank_constraints,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  (
    rem_node_order,
    rem_nodes,
    rem_ranks,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Stage C Phase C5 split: clustered reorder-step
/// finalize-phase execution helpers.

///|
/// Graphviz parity: clustered ReMincross computes edge indices, prepares
/// cluster-aware reorder inputs, then runs final real-node cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step(
  context : ClusteredReMincrossReorderStepContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  ) =
    build_clustered_remincross_reorder_step_inputs(
      context.graph,
      context.edges,
      context.edge_tail,
      context.edge_head,
      context.order_with_vnodes,
      context.order_with_clusters,
      context.ranks,
      context.cluster_meta,
      context.vnode_info,
      context.order_sizes,
      context.rank_same_constraints,
      context.rem_groups,
      context.real_nodes,
      context.rem_nodes,
      context.rem_edge_tail_out,
      context.rem_edge_head_out,
      context.rem_ranks,
      context.rem_edges_out,
    )
  run_remincross_reorder_and_collect_real_groups(
    context.rem_rank_keys,
    context.rem_groups,
    context.rem_edges_out,
    context.rem_edge_tail_out,
    context.rem_edge_head_out,
    context.rem_edge_tail_port_x,
    context.rem_edge_head_port_x,
    context.rem_edge_tail_port_order,
    context.rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    context.cluster_meta.rank_same_groups,
    context.cluster_meta.rank_same_order,
    rem_edge_order,
    context.rem_node_order,
    rem_sizes,
    context.nodesep_pt,
    context.has_edge_labels,
    context.port_order_positions,
    context.port_order_contrib,
    rem_flat_constraints,
    context.graphviz_flip,
    context.real_nodes,
  )
}

///|
/// Graphviz parity: clustered ReMincross reorder-step input payload keeps
/// edge-index and cluster-aware metadata tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
type ClusteredReMincrossReorderStepInputsOutput = (
  Map[String, Array[String]],
  Map[String, Array[String]],
  Map[String, Int],
  Map[String, String],
  Map[String, NodeSize],
  Map[String, Bool],
)

///|
/// Graphviz parity: clustered ReMincross reorder-step input phase derives edge
/// indices plus cluster-aware reorder maps before final cleanup forwarding.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> ClusteredReMincrossReorderStepInputsOutput {
  let (rem_parents, rem_children, rem_edge_order) =
    build_clustered_remincross_edge_indices_for_reorder(
      rem_nodes,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_ranks,
      rem_edges_out,
    )
  let (rem_cluster_keys, rem_sizes, rem_flat_constraints) =
    build_remincross_reorder_inputs(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      order_with_clusters,
      ranks,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      rem_groups,
      real_nodes,
    )
  (
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  )
}


///|
/// Stage C Phase C5 split: remincross stage types
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross multi-rank reorder-input context keeps
/// materialization flags, edge arrays, and metadata payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossMultiRankReorderInputsContext {
  creation_order : Array[String]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  flat_rank_constraints : Map[String, Bool]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
}

///|
/// Graphviz parity: clustered ReMincross multi-rank dispatch context keeps
/// rematerialize + finalize payload ordering unchanged across phase helpers.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossMultiRankDispatchContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  flat_rank_constraints : Map[String, Bool]
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross pass dispatch context keeps
/// rematerialize+cleanup payload ordering unchanged before rank-count branch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossPassDispatchContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  flat_rank_constraints : Map[String, Bool]
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  base_groups : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross reorder-step context keeps remapped
/// edge arrays plus cleanup metadata in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredReMincrossReorderStepContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  ranks : Map[String, Int]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  rem_nodes : Array[String]
  rem_ranks : Map[String, Int]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
}
