///|
/// Graphviz parity: clustered xpos reorder apply inputs keep order-graph edge
/// snapshots, rank metadata, and cluster constraints grouped for one
/// reorder_rank_groups invocation.
pub struct ClusteredXposReorderApplyInput {
  order_rank_keys : Array[Int]
  order_groups : Map[Int, Array[String]]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_nodes : Array[String]
  order_ranks : Map[String, Int]
  order_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  order_node_order : Map[String, Int]
  order_sizes : Map[String, @shared.NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  order_cluster_skeleton : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
pub fn build_clustered_xpos_reorder_apply_input(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_nodes : Array[String],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  order_node_order : Map[String, Int],
  order_sizes : Map[String, @shared.NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  order_cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> ClusteredXposReorderApplyInput {
  {
    order_rank_keys,
    order_groups,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_nodes,
    order_ranks,
    order_cluster_keys,
    rank_same_groups,
    rank_same_order,
    order_node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    order_cluster_skeleton,
    flat_constraints,
    graphviz_flip,
  }
}

///|
/// Graphviz parity: clustered xpos reorder consumes order-graph
/// parents/children plus edge-order hints exactly once before
/// reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_clustered_xpos_reorder(
  input : ClusteredXposReorderApplyInput,
) -> Map[Int, Array[String]] {
  let edge_index_data = @ordering.build_edge_index_for_names(
    input.order_nodes,
    input.order_edge_tail_out,
    input.order_edge_head_out,
    input.order_ranks,
  )
  let parents = edge_index_data.parents
  let children = edge_index_data.children
  let edge_order = @ordering.collect_edge_order(input.order_edges_out)
  @ordering.reorder_rank_groups(
    input.order_rank_keys,
    input.order_groups,
    input.order_edges_out,
    input.order_edge_tail_out,
    input.order_edge_head_out,
    input.order_edge_tail_port_x,
    input.order_edge_head_port_x,
    input.order_edge_tail_port_order,
    input.order_edge_head_port_order,
    parents,
    children,
    input.order_cluster_keys,
    input.rank_same_groups,
    input.rank_same_order,
    edge_order,
    input.order_node_order,
    input.order_sizes,
    input.nodesep_pt,
    input.has_edge_labels,
    Map::new(),
    Map::new(),
    Map::new(),
    input.order_cluster_skeleton,
    input.flat_constraints,
    graphviz_flip=input.graphviz_flip,
  )
}
