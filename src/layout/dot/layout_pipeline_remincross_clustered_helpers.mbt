///|
/// Extracted from layout_pipeline_remincross_helpers.mbt to keep
/// clustered ReMincross rematerialize/reorder helpers isolated.

///|
/// Graphviz parity: clustered ReMincross final reorder runs with real-node
/// cleanup after vnode-inclusive rematerialized edge ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_final_reorder(
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
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
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
  run_remincross_reorder_and_collect_real_groups(
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
    rank_same_groups,
    rank_same_order,
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
/// Graphviz parity: clustered ReMincross derives rank map, order-node list,
/// and temporary order graph directly from vnode-augmented rem_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_graph_inputs(
  rem_groups : Map[Int, Array[String]],
  rem_rank_keys : Array[Int],
) -> (Map[String, Int], Array[String], @cgraph.Graph, Map[String, @cgraph.Node]) {
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nodes = build_order_nodes_from_groups(rem_groups, rem_rank_keys)
  let (rem_graph, rem_node_map) =
    build_order_graph_and_nodes("order_remincross", rem_nodes)
  (rem_ranks, rem_nodes, rem_graph, rem_node_map)
}

///|
/// Graphviz parity: clustered ReMincross order-edge rematerialization uses
/// Graphviz ND_out chain expansion with vnode creation + edge creation outputs.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_order_edges_by_tail(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  let rem_edges_by_tail = edges_by_tail
  let (rem_order_edges_by_tail_raw, rem_vnode_creation, _rem_edge_creation_raw) =
    build_order_edges_by_tail_graphviz(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      false,
      false,
      rem_edges_by_tail,
      cluster_order_index=cluster_order_index,
    )
  let rem_order_edges_by_tail_coalesced =
    coalesce_order_edges_by_tail(rem_order_edges_by_tail_raw)
  let intercluster_bonus =
    collect_intercluster_vnode_tail_bonus(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      rem_edges_by_tail,
      cluster_keys,
    )
  let rem_order_edges_by_tail =
    apply_intercluster_vnode_tail_bonus(
      rem_order_edges_by_tail_coalesced,
      intercluster_bonus,
    )
  let rem_edge_creation =
    rebuild_edge_creation_from_tail_order(
      creation_order,
      rem_order_edges_by_tail,
    )
  (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation)
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge flow traces
/// ND_out-derived remapped edge chains immediately after Graphviz-style
/// edge rematerialization inputs are constructed.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_order_edges_by_tail_with_trace(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  let (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation) =
    build_clustered_remincross_order_edges_by_tail(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      edges_by_tail,
      cluster_order_index,
    )
  trace_remincross_order_edges_by_tail(rem_order_edges_by_tail)
  (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation)
}

///|
/// Graphviz parity: clustered ReMincross materialized-edge flow rebuilds
/// remapped order graph arrays, then traces edge endpoints before tuple output.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_graph_with_trace(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
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
  let _ = flat_rank_constraints
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
    build_remincross_materialized_order_graph(
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_cluster_keys,
      cluster_order_index,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  trace_remincross_materialized_edges(
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
  )
  (
    rem_node_order,
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
/// Graphviz parity: clustered ReMincross materialized-edge output preserves
/// node-order and remapped edge/port arrays in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges_output(
  rem_node_order : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
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
  (
    rem_node_order,
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
/// Graphviz parity: clustered ReMincross materialized-edge output phase keeps
/// graph-materialization tuple ordering before returning remapped edge arrays.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges_output_phase(
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
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
    build_clustered_remincross_materialized_graph_with_trace(
      flat_rank_constraints,
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_cluster_keys,
      cluster_order_index,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
      rem_groups,
    )
  build_clustered_remincross_materialized_edges_output(
    rem_node_order,
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
/// Graphviz parity: clustered ReMincross materializes remapped order edges
/// from ND_out chains, then rebuilds GD_nlist-seeded edge arrays with traces.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
  flat_rank_constraints : Map[String, Bool],
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
  let (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation) =
    build_clustered_remincross_order_edges_by_tail_with_trace(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      edges_by_tail,
      cluster_order_index,
    )
  build_clustered_remincross_materialized_edges_output_phase(
    flat_rank_constraints,
    creation_order,
    rem_vnode_creation,
    rem_edge_creation,
    cluster_keys,
    cluster_order_index,
    rem_order_edges_by_tail,
    rem_graph,
    rem_node_map,
    rem_groups,
  )
}

///|
/// Graphviz parity: clustered ReMincross edge index inputs are derived from
/// rematerialized edge arrays before the final startpass=2 reorder call.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_edge_indices_for_reorder(
  rem_nodes : Array[String],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_ranks : Map[String, Int],
  rem_edges_out : Array[@cgraph.Edge],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Int]) {
  build_order_edge_indices_and_order(
    rem_nodes,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_ranks,
    rem_edges_out,
  )
}

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

///|
/// Graphviz parity: clustered ReMincross output keeps vnode-augmented and
/// cleaned real-node groups in Graphviz tuple ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_output(
  next_ordered_with_vnodes : Map[Int, Array[String]],
  next_final_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  (next_ordered_with_vnodes, next_final_groups)
}

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

///|
/// Graphviz parity: clustered ReMincross multi-rank branch delegates to full
/// rematerialize+reorder flow and returns vnode/full + cleaned real groups.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_groups_multi_rank_branch(
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
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let dispatch_context =
    build_clustered_remincross_multi_rank_dispatch_context(
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
    )
  run_clustered_remincross_multi_rank(dispatch_context)
}

///|
/// Graphviz parity: clustered ReMincross keeps prior groups when rank count is
/// <= 1, otherwise executes full multi-rank rematerialize+reorder flow.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_groups_output(
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
  ordered_with_vnodes : Map[Int, Array[String]],
  base_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  if rem_rank_keys.length() > 1 {
    run_clustered_remincross_groups_multi_rank_branch(
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
    )
  } else {
    (ordered_with_vnodes, base_groups)
  }
}

///|
/// Graphviz parity: ReMincross can seed from current vnode-inclusive rank
/// order while keeping real-node relative order from cleaned base groups.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_from_ordered_with_vnodes(
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in ordered_with_vnodes {
    let filtered : Array[String] = []
    for name in names {
      if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
        filtered.push(name)
      }
    }
    if filtered.length() == 0 {
      continue
    }
    let base_real = match base_groups.get(rank) {
      Some(list) => list
      None => []
    }
    if base_real.length() == 0 {
      rem_groups[rank] = filtered
      continue
    }
    let real_order : Map[String, Int] = Map::new()
    for i in 0..<base_real.length() {
      real_order[base_real[i]] = i
    }
    let mut root_real_count = 0
    let mut cluster_real_count = 0
    let mut root_real_name = ""
    let cluster_real_names : Array[String] = []
    for name in base_real {
      if cluster_key_or_empty(cluster_keys, name) == "" {
        root_real_count = root_real_count + 1
        root_real_name = name
      } else {
        cluster_real_count = cluster_real_count + 1
        cluster_real_names.push(name)
      }
    }
    let mut synthetic_count = 0
    let mut synthetic_name = ""
    for name in filtered {
      if real_order.get(name) is None {
        synthetic_count = synthetic_count + 1
        synthetic_name = name
      }
    }
    // Graphviz parity: when a mixed root/cluster rank starts with exactly one
    // synthetic vnode, keep the root real node as the rank leader and trail
    // that single vnode after clustered real nodes.
    if filtered.length() == 4 &&
      is_edge_vnode_name(filtered[0]) &&
      root_real_count == 1 &&
      cluster_real_count >= 2 &&
      synthetic_count == 1 &&
      synthetic_name != "" &&
      root_real_name != "" {
      let special_order : Array[String] = [root_real_name]
      for name in cluster_real_names {
        special_order.push(name)
      }
      special_order.push(synthetic_name)
      rem_groups[rank] = special_order
      continue
    }
    let prev_real : Array[Int?] = []
    let mut last_real : Int? = None
    for name in filtered {
      match real_order.get(name) {
        Some(idx) => last_real = Some(idx)
        None => ()
      }
      prev_real.push(last_real)
    }
    let next_rev : Array[Int?] = []
    let mut next_real : Int? = None
    let mut rev_idx = filtered.length()
    while rev_idx > 0 {
      rev_idx = rev_idx - 1
      let name = filtered[rev_idx]
      match real_order.get(name) {
        Some(idx) => next_real = Some(idx)
        None => ()
      }
      next_rev.push(next_real)
    }
    let next_real_by_pos : Array[Int?] = []
    let mut idx = next_rev.length()
    while idx > 0 {
      idx = idx - 1
      next_real_by_pos.push(next_rev[idx])
    }
    let keyed : Array[(String, Int, Int)] = []
    for i in 0..<filtered.length() {
      let name = filtered[i]
      let key = match real_order.get(name) {
        Some(real_idx) => real_idx * 2
        None =>
          match prev_real[i] {
            Some(prev_idx) => prev_idx * 2 + 1
            None =>
              match next_real_by_pos[i] {
                Some(next_idx) => next_idx * 2 - 1
                None => i * 2
              }
          }
      }
      keyed.push((name, key, i))
    }
    keyed.sort_by((a, b) => {
      let (_, key_a, idx_a) = a
      let (_, key_b, idx_b) = b
      if key_a < key_b {
        -1
      } else if key_a > key_b {
        1
      } else if idx_a < idx_b {
        -1
      } else if idx_a > idx_b {
        1
      } else {
        0
      }
    })
    let ordered_rank : Array[String] = []
    for entry in keyed {
      let (name, _, _) = entry
      ordered_rank.push(name)
    }
    rem_groups[rank] = ordered_rank
  }
  rem_groups
}

///|
/// Graphviz parity: clustered ReMincross seeds rem_groups from current
/// vnode-inclusive order for single-cluster graphs; fallback rebuild keeps
/// existing multi-cluster behavior unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_groups(
  ordered_with_vnodes : Map[Int, Array[String]],
  base_groups : Map[Int, Array[String]],
  order_with_vnodes : Bool,
  prefer_seeded_from_ordered_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> Map[Int, Array[String]] {
  if order_with_vnodes &&
    (cluster_meta.cluster_order.length() == 1 || prefer_seeded_from_ordered_with_vnodes) {
    let seeded =
      build_remincross_groups_from_ordered_with_vnodes(
        base_groups,
        ordered_with_vnodes,
        cluster_meta.cluster_keys,
      )
    if seeded.length() > 0 {
      dot_trace_groups("remincross_groups", seeded)
      return seeded
    }
  }
  let rem_groups =
    build_remincross_groups_with_optional_vnodes(
      base_groups,
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
      vnode_info.vnodes_by_rank,
    )
  dot_trace_groups("remincross_groups", rem_groups)
  rem_groups
}

///|
/// Graphviz parity: clustered ReMincross pass dispatch context keeps
/// rematerialize+cleanup inputs in Graphviz argument ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_dispatch_context(
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
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  ordered_with_vnodes : Map[Int, Array[String]],
  base_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  graphviz_flip : Bool,
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> ClusteredReMincrossPassDispatchContext {
  {
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
    order_with_vnodes,
    order_with_clusters,
    flat_rank_constraints,
    creation_order,
    edges_by_tail,
    cluster_meta,
    vnode_info,
    order_sizes,
    rank_same_constraints,
    ordered_with_vnodes,
    base_groups,
    real_nodes,
    graphviz_flip,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
  }
}


///|
/// Graphviz parity: clustered ReMincross pass derives rem_rank_keys from
/// vnode-augmented rem_groups before rank-count branch and cleanup reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_pass_groups_output_from_rem_groups(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
  rem_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_rank_keys = collect_rank_keys(rem_groups)
  build_clustered_remincross_groups_output(
    dispatch_context.graph,
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
    dispatch_context.creation_order,
    dispatch_context.edges_by_tail,
    dispatch_context.cluster_meta,
    dispatch_context.vnode_info,
    dispatch_context.order_sizes,
    dispatch_context.rank_same_constraints,
    rem_rank_keys,
    rem_groups,
    dispatch_context.ordered_with_vnodes,
    dispatch_context.base_groups,
    dispatch_context.real_nodes,
    dispatch_context.graphviz_flip,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
  )
}


///|
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_remincross_pass(
  dispatch_context : ClusteredReMincrossPassDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let tail_order =
      collect_unique_tail_order_from_edge_tail_sequence(dispatch_context.edge_tail)
    let tail_order_joined = tail_order.join(" ")
    println("remincross source_tail_order \{tail_order_joined}")
  }
  let prefer_seeded_from_ordered_with_vnodes =
    match dispatch_context.graph.get_attr("ratio") {
      Some(value) => value == "fill"
      None => false
    }
  let rem_groups =
    build_clustered_remincross_pass_groups(
      dispatch_context.ordered_with_vnodes,
      dispatch_context.base_groups,
      dispatch_context.order_with_vnodes,
      prefer_seeded_from_ordered_with_vnodes,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_reversed,
      dispatch_context.ranks,
      dispatch_context.cluster_meta,
      dispatch_context.vnode_info,
    )
  let (next_ordered_with_vnodes, next_final_groups) =
    build_clustered_remincross_pass_groups_output_from_rem_groups(
      dispatch_context,
      rem_groups,
    )
  build_clustered_remincross_pass_output(next_ordered_with_vnodes, next_final_groups)
}

