///|
/// Extracted from layout_pipeline_stage_c_phase_c5_remincross_reorder_execute_helpers.mbt
/// to keep Stage C clustered ReMincross rematerialize/reorder helpers isolated.

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
