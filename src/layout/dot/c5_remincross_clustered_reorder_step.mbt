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

