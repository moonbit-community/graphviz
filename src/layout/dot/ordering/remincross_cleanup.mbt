///|
/// Ordering domain: clustered ReMincross cleanup-reorder helpers used by
/// Stage C final startpass=2 pass orchestration.

///|
/// Graphviz parity: ReMincross cleanup capture payload records the same
/// rematerialized edge snapshot passed into clustered startpass=2 reorder.
pub(all) struct ReMincrossCleanupCaptureInputs {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_cluster_keys : Map[String, String]
}

///|
/// Graphviz parity: ReMincross cleanup reorder payload keeps edge-index maps
/// and clustered reorder inputs built from one rematerialized snapshot.
pub(all) struct ReMincrossCleanupReorderInputs {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_parents : Map[String, Array[String]]
  rem_children : Map[String, Array[String]]
  rem_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  rem_edge_order : Map[String, Int]
  rem_node_order : Map[String, Int]
  rem_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  rem_flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: clustered ReMincross cleanup inputs keep rematerialized
/// arrays, rank=same maps, and layout knobs unchanged before startpass=2 call.
pub(all) struct ReMincrossCleanupInputs {
  rem_rank_keys : Array[Int]
  rem_groups : Map[Int, Array[String]]
  materialized_inputs : ReMincrossCleanupMaterializedInputs
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: ReMincross clustered cleanup reorder captures rematerialized
/// inputs, builds edge index maps, then executes startpass=2 reorder.
/// Do not change behavior without updating fixtures/tests.
pub fn run_remincross_cleanup(
  inputs : ReMincrossCleanupInputs,
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let materialized_inputs = inputs.materialized_inputs
  let rem_edge_indices =
    build_edge_indices_and_order(
      materialized_inputs.rem_nodes,
      materialized_inputs.rem_edge_tail_out,
      materialized_inputs.rem_edge_head_out,
      materialized_inputs.rem_ranks,
      materialized_inputs.rem_edges_out,
    )
  // Graphviz parity: ReMincross clustered reorder executes startpass=2 on the
  // same rematerialized edge snapshot captured for fixture/debug parity.
  capture_call(
    {
      rem_rank_keys: inputs.rem_rank_keys,
      rem_groups: inputs.rem_groups,
      rem_edges_out: materialized_inputs.rem_edges_out,
      rem_edge_tail_out: materialized_inputs.rem_edge_tail_out,
      rem_edge_head_out: materialized_inputs.rem_edge_head_out,
      rem_edge_tail_port_x: materialized_inputs.rem_edge_tail_port_x,
      rem_edge_head_port_x: materialized_inputs.rem_edge_head_port_x,
      rem_edge_tail_port_order: materialized_inputs.rem_edge_tail_port_order,
      rem_edge_head_port_order: materialized_inputs.rem_edge_head_port_order,
      rem_cluster_keys: materialized_inputs.rem_cluster_keys,
    },
  )
  reorder_call(
    {
      rem_rank_keys: inputs.rem_rank_keys,
      rem_groups: inputs.rem_groups,
      rem_edges_out: materialized_inputs.rem_edges_out,
      rem_edge_tail_out: materialized_inputs.rem_edge_tail_out,
      rem_edge_head_out: materialized_inputs.rem_edge_head_out,
      rem_edge_tail_port_x: materialized_inputs.rem_edge_tail_port_x,
      rem_edge_head_port_x: materialized_inputs.rem_edge_head_port_x,
      rem_edge_tail_port_order: materialized_inputs.rem_edge_tail_port_order,
      rem_edge_head_port_order: materialized_inputs.rem_edge_head_port_order,
      rem_parents: rem_edge_indices.parents,
      rem_children: rem_edge_indices.children,
      rem_cluster_keys: materialized_inputs.rem_cluster_keys,
      rank_same_groups: inputs.rank_same_groups,
      rank_same_order: inputs.rank_same_order,
      rem_edge_order: rem_edge_indices.edge_order,
      rem_node_order: materialized_inputs.rem_node_order,
      rem_sizes: materialized_inputs.rem_sizes,
      nodesep_pt: inputs.nodesep_pt,
      has_edge_labels: inputs.has_edge_labels,
      port_order_positions: inputs.port_order_positions,
      port_order_contrib: inputs.port_order_contrib,
      rem_flat_constraints: materialized_inputs.rem_flat_constraints,
      graphviz_flip: inputs.graphviz_flip,
    },
  )
}
