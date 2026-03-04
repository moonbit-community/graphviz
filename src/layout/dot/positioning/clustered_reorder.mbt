///|
///|
/// Graphviz parity: clustered xpos reorder pipeline input keeps seed material,
/// order-graph edge materialization data, and reorder constraints grouped for a
/// single clustered xpos pass.
pub struct ClusteredXposReorderInput {
  x_groups : Map[Int, Array[String]]
  x_order_sizes : Map[String, @shared.NodeSize]
  x_cluster_keys : Map[String, String]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  node_order : Map[String, Int]
  cluster_skeleton_prefix : String
  cluster_skeleton_size : @shared.NodeSize
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  cluster_skeleton_penalty : Int
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  nodesep_pt : Double
  has_edge_labels : Bool
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
pub fn build_clustered_xpos_reorder_input(
  x_groups : Map[Int, Array[String]],
  x_order_sizes : Map[String, @shared.NodeSize],
  x_cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  node_order : Map[String, Int],
  cluster_skeleton_prefix : String,
  cluster_skeleton_size : @shared.NodeSize,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  cluster_skeleton_penalty : Int,
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> ClusteredXposReorderInput {
  {
    x_groups,
    x_order_sizes,
    x_cluster_keys,
    cluster_min_rank,
    cluster_max_rank,
    node_order,
    cluster_skeleton_prefix,
    cluster_skeleton_size,
    edges,
    edge_tail,
    edge_head,
    ranks,
    edge_vnodes,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    cluster_skeleton_penalty,
    rank_same_groups,
    rank_same_order,
    nodesep_pt,
    has_edge_labels,
    flat_constraints,
    graphviz_flip,
  }
}

///|
/// Graphviz parity: clustered xpos reorder runs seed build, order-edge
/// materialization, and reorder_rank_groups in Graphviz-equivalent sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_xpos_groups(
  input : ClusteredXposReorderInput,
) -> Map[Int, Array[String]] {
  let reorder_seed_data =
    build_clustered_xpos_seed(
      build_clustered_xpos_seed_input(
        input.x_groups,
        input.x_order_sizes,
        input.x_cluster_keys,
        input.cluster_min_rank,
        input.cluster_max_rank,
        input.node_order,
        input.cluster_skeleton_prefix,
        input.cluster_skeleton_size,
      ),
    )
  let reorder_edges_data =
    build_clustered_xpos_edges(
      build_clustered_xpos_edge_materialization_input(
        input.edges,
        input.edge_tail,
        input.edge_head,
        input.ranks,
        input.edge_vnodes,
        reorder_seed_data.order_nodes,
        input.edge_tail_port_x,
        input.edge_head_port_x,
        input.edge_tail_port_order,
        input.edge_head_port_order,
        input.cluster_min_rank,
        input.cluster_max_rank,
        input.cluster_skeleton_prefix,
        input.cluster_skeleton_penalty,
      ),
    )
  apply_clustered_xpos_reorder(
    build_clustered_xpos_reorder_apply_input(
      reorder_seed_data.order_rank_keys,
      reorder_seed_data.order_groups,
      reorder_edges_data.order_edges_out,
      reorder_edges_data.order_edge_tail_out,
      reorder_edges_data.order_edge_head_out,
      reorder_edges_data.order_edge_tail_port_x,
      reorder_edges_data.order_edge_head_port_x,
      reorder_edges_data.order_edge_tail_port_order,
      reorder_edges_data.order_edge_head_port_order,
      reorder_seed_data.order_nodes,
      reorder_seed_data.order_ranks,
      reorder_seed_data.order_cluster_keys,
      input.rank_same_groups,
      input.rank_same_order,
      reorder_seed_data.order_node_order,
      reorder_seed_data.order_sizes,
      input.nodesep_pt,
      input.has_edge_labels,
      reorder_seed_data.order_cluster_skeleton,
      input.flat_constraints,
      input.graphviz_flip,
    ),
  )
}

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
