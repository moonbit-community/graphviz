///|
/// Extracted from layout_pipeline_stage_c_remincross_clustered_pass_execute_helpers.mbt
/// to keep Stage C clustered ReMincross reorder-step orchestration isolated.

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

///|
/// Graphviz parity: clustered ReMincross reorder-step execution forwards
/// prepared indices/cluster maps into startpass=2 cleanup reorder call.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_reorder_phase(
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
  run_clustered_remincross_reorder_step_from_reorder_inputs(
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
    cluster_meta,
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
/// Graphviz parity: clustered ReMincross reorder-step finalize phase forwards
/// prepared index/cluster maps into final cleanup reorder execution.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_finalize_phase(
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
  run_clustered_remincross_reorder_step_reorder_phase(
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
    cluster_meta,
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
/// Graphviz parity: clustered ReMincross reorder-step input phase prepares
/// edge-index maps and cluster-aware reorder metadata before cleanup phase.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_input_phase(
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
  build_clustered_remincross_reorder_step_inputs(
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
    rem_nodes,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_ranks,
    rem_edges_out,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step finalize dispatch context
/// preserves cleanup reorder arguments in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_finalize_dispatch_context(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  cluster_meta : ClusterMetadata,
  rem_node_order : Map[String, Int],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> ClusteredReMincrossReorderStepFinalizeDispatchContext {
  {
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    cluster_meta,
    rem_node_order,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    real_nodes,
  }
}


///|
/// Graphviz parity: clustered ReMincross reorder-step finalize dispatch reads
/// input-phase tuple and forwards values in Graphviz finalize-call order.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step_finalize_phase_from_input_phase_output(
  dispatch_context : ClusteredReMincrossReorderStepFinalizeDispatchContext,
  input_phase_output : ClusteredReMincrossReorderStepInputsOutput,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (
    rem_parents,
    rem_children,
    rem_edge_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
  ) = input_phase_output
  run_clustered_remincross_reorder_step_finalize_phase(
    dispatch_context.rem_rank_keys,
    dispatch_context.rem_groups,
    dispatch_context.rem_edges_out,
    dispatch_context.rem_edge_tail_out,
    dispatch_context.rem_edge_head_out,
    dispatch_context.rem_edge_tail_port_x,
    dispatch_context.rem_edge_head_port_x,
    dispatch_context.rem_edge_tail_port_order,
    dispatch_context.rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    dispatch_context.cluster_meta,
    rem_edge_order,
    dispatch_context.rem_node_order,
    rem_sizes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    rem_flat_constraints,
    dispatch_context.graphviz_flip,
    dispatch_context.real_nodes,
  )
}


///|
/// Graphviz parity: clustered ReMincross reorder-step context builder keeps
/// rematerialized arrays and cleanup metadata argument ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_reorder_step_context(
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
) -> ClusteredReMincrossReorderStepContext {
  {
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
  }
}


///|
/// Graphviz parity: clustered ReMincross computes edge indices, prepares
/// cluster-aware reorder inputs, then runs final real-node cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_reorder_step(
  context : ClusteredReMincrossReorderStepContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let input_phase_output =
    run_clustered_remincross_reorder_step_input_phase(
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
  let dispatch_context =
    build_clustered_remincross_reorder_step_finalize_dispatch_context(
      context.rem_rank_keys,
      context.rem_groups,
      context.rem_edges_out,
      context.rem_edge_tail_out,
      context.rem_edge_head_out,
      context.rem_edge_tail_port_x,
      context.rem_edge_head_port_x,
      context.rem_edge_tail_port_order,
      context.rem_edge_head_port_order,
      context.cluster_meta,
      context.rem_node_order,
      context.nodesep_pt,
      context.has_edge_labels,
      context.port_order_positions,
      context.port_order_contrib,
      context.graphviz_flip,
      context.real_nodes,
    )
  run_clustered_remincross_reorder_step_finalize_phase_from_input_phase_output(
    dispatch_context,
    input_phase_output,
  )
}
