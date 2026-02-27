///|
/// Extracted from layout_pipeline_remincross_clustered_helpers.mbt to keep
/// clustered ReMincross multi-rank rematerialize/reorder helpers isolated.

///|
/// Graphviz parity: clustered ReMincross multi-rank input tuple preserves
/// node-order, rank map, and rematerialized edge/port arrays ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_reorder_inputs_output(
  rem_node_order : Map[String, Int],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
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
  build_clustered_remincross_multi_rank_reorder_inputs_output(
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
/// Graphviz parity: clustered ReMincross multi-rank forwarding keeps
/// rematerialized arrays and reorder metadata in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_from_reorder_inputs(
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
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_step_context =
    build_clustered_remincross_reorder_step_context(
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
      rem_rank_keys,
      rem_groups,
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
      real_nodes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      graphviz_flip,
    )
  run_clustered_remincross_reorder_step(reorder_step_context)
}


///|
/// Graphviz parity: clustered ReMincross multi-rank input phase keeps
/// rematerialized reorder arrays in Graphviz tuple ordering before cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_multi_rank_reorder_inputs_phase(
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
  let input_context : ClusteredReMincrossMultiRankReorderInputsContext = {
    creation_order,
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
    edges_by_tail,
    cluster_meta,
    vnode_info,
  }
  build_clustered_remincross_multi_rank_reorder_inputs(
    input_context,
    rem_groups,
    rem_rank_keys,
  )
}

///|
/// Graphviz parity: clustered ReMincross multi-rank reorder phase forwards
/// rematerialized arrays into startpass=2 cleanup without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_reorder_phase(
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
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_multi_rank_from_reorder_inputs(
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
    rem_rank_keys,
    rem_groups,
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
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: clustered ReMincross multi-rank finalize phase runs
/// startpass=2 cleanup reorder using rematerialized reorder payload tuple.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_finalize_phase(
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
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_nodes : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_clustered_remincross_multi_rank_reorder_phase(
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
    rem_rank_keys,
    rem_groups,
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
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: clustered ReMincross finalize output dispatch unpacks
/// rematerialized reorder tuple and forwards typed payload unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output_with_context(
  finalize_context : ClusteredReMincrossMultiRankFinalizeContext,
  reorder_inputs_output : (
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
  ),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
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
  ) = reorder_inputs_output
  run_clustered_remincross_multi_rank_finalize_phase(
    finalize_context.graph,
    finalize_context.edges,
    finalize_context.edge_tail,
    finalize_context.edge_head,
    finalize_context.order_with_vnodes,
    finalize_context.order_with_clusters,
    finalize_context.ranks,
    finalize_context.cluster_meta,
    finalize_context.vnode_info,
    finalize_context.order_sizes,
    finalize_context.rank_same_constraints,
    finalize_context.rem_rank_keys,
    finalize_context.rem_groups,
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
    finalize_context.real_nodes,
    finalize_context.nodesep_pt,
    finalize_context.has_edge_labels,
    finalize_context.port_order_positions,
    finalize_context.port_order_contrib,
    finalize_context.graphviz_flip,
  )
}


///|
/// Graphviz parity: clustered ReMincross multi-rank finalize dispatch reads
/// rematerialized reorder tuple then forwards values in Graphviz call order.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output(
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
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  reorder_inputs_output : (
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
  ),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let finalize_context : ClusteredReMincrossMultiRankFinalizeContext = {
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
    rem_rank_keys,
    rem_groups,
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
  }
  run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output_with_context(
    finalize_context,
    reorder_inputs_output,
  )
}


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
  let reorder_inputs_output =
    build_clustered_remincross_multi_rank_reorder_inputs_phase(
      dispatch_context.creation_order,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_tail_port_x,
      dispatch_context.edge_head_port_x,
      dispatch_context.edge_tail_port_order,
      dispatch_context.edge_head_port_order,
      dispatch_context.ranks,
      dispatch_context.order_with_vnodes,
      dispatch_context.order_with_clusters,
      dispatch_context.flat_rank_constraints,
      dispatch_context.edges_by_tail,
      dispatch_context.cluster_meta,
      dispatch_context.vnode_info,
      dispatch_context.rem_groups,
      dispatch_context.rem_rank_keys,
    )
  run_clustered_remincross_multi_rank_finalize_phase_from_reorder_inputs_output(
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.order_with_vnodes,
    dispatch_context.order_with_clusters,
    dispatch_context.ranks,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    dispatch_context.rem_rank_keys,
    dispatch_context.rem_groups,
    dispatch_context.real_nodes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    dispatch_context.graphviz_flip,
    reorder_inputs_output,
  )
}
