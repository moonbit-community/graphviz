///|
/// Stage-focused split to keep cluster-rank
/// finalize/remincross stage helpers isolated and maintainable.

///|
/// Graphviz parity: clustered finalize stage output keeps final rank groups and
/// vnode-augmented groups in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_and_finalize_stage_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (next_ordered_with_vnodes, final_groups)
}

///|
/// Graphviz parity: clustered finalize stage builds root-cluster rank-order
/// mappings from root-only reorder before clustered ReMincross cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_rank_order_for_finalize_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_for_cluster_reorder(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: clustered finalize stage applies cluster-rank-order maps
/// before the final clustered ReMincross cleanup pass.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_remincross_finalize_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let dispatch_context =
    build_finalize_order_groups_dispatch_context(
      order_with_clusters,
      order_with_vnodes,
      cluster_rank_order,
      cluster_meta,
      local_cluster_order,
      ordered_with_vnodes,
      graph,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      flat_rank_constraints,
      creation_order,
      edges_by_tail,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      real_nodes,
      graphviz_flip,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
    )
  finalize_order_groups_with_cluster_remincross(
    dispatch_context,
    order_rank_keys,
    ordered,
  )
}

///|
/// Graphviz parity: finalize-stage ReMincross consumes cluster-rank-order
/// output without argument reshuffling before clustered cleanup execution.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_remincross_from_cluster_rank_order(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_remincross_finalize_stage(
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: finalize-stage cluster-rank-order phase consumes
/// root-cluster reorder inputs before clustered ReMincross forwarding.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  build_cluster_rank_order_for_finalize_stage(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage ReMincross phase forwards derived
/// cluster-rank-order maps into clustered cleanup without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_remincross_from_cluster_rank_order(
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}

///|
/// Graphviz parity: finalize-stage ReMincross dispatch reads derived
/// cluster-rank-order output then forwards payload without reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase_from_cluster_rank_order_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase(
    order_with_clusters,
    order_with_vnodes,
    cluster_rank_order_output,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage cluster-rank-order dispatch reads
/// root finalize inputs and forwards them in Graphviz phase-call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_rank_keys : Array[Int],
  order_groups_for_mincross : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[Int, Map[String, Int]] {
  run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage cluster-rank-order output dispatch forwards
/// typed stage payload fields in Graphviz phase-call ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_stage_inputs(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  stage_inputs : ClusterFinalizeStageInputs,
) -> Map[Int, Map[String, Int]] {
  run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output(
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    nlist_order,
    ranks,
    stage_inputs.order_rank_keys,
    stage_inputs.order_groups_for_mincross,
    stage_inputs.order_cluster_keys,
    stage_inputs.order_cluster_skeleton,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    stage_inputs.order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  )
}


///|
/// Graphviz parity: finalize-stage ReMincross phase dispatch reads
/// cluster-rank-order output and forwards payload in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  order_rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase_from_cluster_rank_order_output(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    local_cluster_order,
    order_rank_keys,
    ordered,
    real_nodes,
    ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: finalize-stage ReMincross output dispatch forwards typed
/// stage payload fields with cluster-rank-order output unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_remincross_phase_output_from_stage_inputs(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
  edges_by_tail : Map[String, Array[Int]],
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  stage_inputs : ClusterFinalizeStageInputs,
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase_output(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    local_cluster_order,
    stage_inputs.order_rank_keys,
    stage_inputs.ordered,
    real_nodes,
    stage_inputs.ordered_with_vnodes,
    graph,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    ranks,
    flat_rank_constraints,
    stage_inputs.creation_order,
    edges_by_tail,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: finalize-pass cluster-rank-order context dispatch reads
/// typed finalize runtime payloads and preserves Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_context(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> Map[Int, Map[String, Int]] {
  run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_stage_inputs(
    dispatch_context.order_with_clusters,
    dispatch_context.order_with_vnodes,
    dispatch_context.graphviz_flip,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.nlist_order,
    dispatch_context.ranks,
    dispatch_context.order_edges_by_tail_root,
    dispatch_context.skeleton_edge_creation,
    dispatch_context.root_edge_creation,
    dispatch_context.flat_rank_constraints,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.vnode_order_keys_for_ordering,
    dispatch_context.real_nodes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    stage_inputs,
  )
}


///|
/// Graphviz parity: finalize-pass output dispatch reads cluster-rank-order
/// output plus typed runtime payload and forwards ReMincross unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass_output_phase_from_cluster_rank_order_output(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
  cluster_rank_order_output : Map[Int, Map[String, Int]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass_remincross_phase_output_from_stage_inputs(
    dispatch_context.order_with_clusters,
    dispatch_context.order_with_vnodes,
    dispatch_context.cluster_meta,
    dispatch_context.local_cluster_order,
    dispatch_context.real_nodes,
    dispatch_context.graph,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_reversed,
    dispatch_context.edge_tail_port_x,
    dispatch_context.edge_head_port_x,
    dispatch_context.edge_tail_port_order,
    dispatch_context.edge_head_port_order,
    dispatch_context.ranks,
    dispatch_context.flat_rank_constraints,
    dispatch_context.edges_by_tail,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    dispatch_context.graphviz_flip,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    stage_inputs,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: finalize-stage cluster rank order is derived first, then
/// consumed by final clustered ReMincross without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_ordered_finalize_pass(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let cluster_rank_order_output =
    run_cluster_rank_ordered_finalize_pass_cluster_rank_order_phase_output_from_context(
      dispatch_context,
      stage_inputs,
    )
  run_cluster_rank_ordered_finalize_pass_output_phase_from_cluster_rank_order_output(
    dispatch_context,
    stage_inputs,
    cluster_rank_order_output,
  )
}


///|
/// Graphviz parity: clustered cleanup finalize-pass dispatch reads typed
/// context+stage inputs and forwards clustered ReMincross unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_finalize_pass(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_cluster_rank_ordered_finalize_pass(
    dispatch_context,
    stage_inputs,
  )
}


///|
/// Graphviz parity: clustered finalize stage output dispatch reads finalize
/// pass tuple and preserves Graphviz output tuple ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_output_phase_from_finalize_pass_output(
  finalize_pass_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let (next_ordered_with_vnodes, final_groups) = finalize_pass_output
  build_cluster_rank_order_and_finalize_stage_output(
    next_ordered_with_vnodes,
    final_groups,
  )
}


///|
/// Graphviz parity: clustered cleanup applies root cluster-rank ordering,
/// then runs final clustered ReMincross via typed dispatch context.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage(
  dispatch_context : ClusterFinalizePassDispatchContext,
  stage_inputs : ClusterFinalizeStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let finalize_pass_output =
    run_cluster_rank_order_and_finalize_stage_finalize_pass(
      dispatch_context,
      stage_inputs,
    )
  run_cluster_rank_order_and_finalize_stage_output_phase_from_finalize_pass_output(
    finalize_pass_output,
  )
}

