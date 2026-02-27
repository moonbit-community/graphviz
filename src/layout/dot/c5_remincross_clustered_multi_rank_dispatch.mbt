///|
/// Stage C Phase C5 split: remincross clustered multi rank dispatch
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross multi-rank dispatch context builder
/// preserves rematerialize/finalize argument ordering before phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_dispatch_context(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> ClusteredReMincrossMultiRankDispatchContext {
  {
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    order_with_vnodes,
    order_with_clusters,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    real_nodes,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  }
}


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
/// Graphviz parity: clustered ReMincross multi-rank edge materialization keeps
/// cluster-key and vnode maps sourced from stage metadata before forwarding.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_materialized_edges(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let cluster_order_index =
    build_cluster_index_for_local_reorder(cluster_meta.cluster_order)
  build_clustered_remincross_materialized_edges(
    creation_order,
    edges,
    edge_tail,
    edge_head,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    vnode_info.edge_vnodes,
    order_with_vnodes,
    cluster_meta.intercluster_keys,
    order_with_clusters,
    edges_by_tail,
    cluster_order_index,
    flat_rank_constraints,
    rem_graph,
    rem_node_map,
    rem_groups,
  )
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
    build_clustered_remincross_multi_rank_materialized_edges(
      input_context.creation_order,
      input_context.edges,
      input_context.edge_tail,
      input_context.edge_head,
      input_context.edge_tail_port_x,
      input_context.edge_head_port_x,
      input_context.edge_tail_port_order,
      input_context.edge_head_port_order,
      input_context.ranks,
      input_context.order_with_vnodes,
      input_context.order_with_clusters,
      input_context.flat_rank_constraints,
      input_context.edges_by_tail,
      input_context.cluster_meta,
      input_context.vnode_info,
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
/// Graphviz parity: clustered ReMincross reorder step forwards rematerialized
/// edge/reorder inputs with cluster metadata into final cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_from_reorder_inputs(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_final_reorder(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    rem_flat_constraints,
    graphviz_flip,
    real_nodes,
  )
}


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
  run_clustered_remincross_reorder_step_from_reorder_inputs(
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
    context.cluster_meta,
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
/// Graphviz parity: clustered ReMincross reorder-step edge-index phase builds
/// parent/child maps plus edge-order indices from rematerialized edge arrays.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs_edge_indices_phase(
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  build_clustered_remincross_edge_indices_for_reorder(
    rem_nodes,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_ranks,
    rem_edges_out,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step metadata phase derives
/// cluster keys, sizes, and flat constraints from current rem_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs_metadata_phase(
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
) -> (Map[String, String], Map[String, NodeSize], Map[String, Bool]) {
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
/// Graphviz parity: clustered ReMincross reorder-step input output preserves
/// edge-index maps and cluster-aware metadata tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_inputs_output(
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_edge_order : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_sizes : Map[String, NodeSize],
  rem_flat_constraints : Map[String, Bool],
) -> ClusteredReMincrossReorderStepInputsOutput {
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
    build_clustered_remincross_reorder_step_inputs_edge_indices_phase(
      rem_nodes,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_ranks,
      rem_edges_out,
    )
  let (rem_cluster_keys, rem_sizes, rem_flat_constraints) =
    build_clustered_remincross_reorder_step_inputs_metadata_phase(
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
  build_clustered_remincross_reorder_step_inputs_output(
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  )
}

