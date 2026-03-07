type NodeSize = @shared.NodeSize

///|
pub struct XposPortSamples {
  tail_port_x : Array[Double]
  head_port_x : Array[Double]
  tail_port_order : Array[Double]
  head_port_order : Array[Double]
}

///|
/// Graphviz parity: non-cluster xpos reorder build input keeps order-edge
/// snapshots, vnode expansion metadata, and reorder constraints grouped before
/// order-edge port hint sampling.
pub struct NonclusteredXposGroupBuildInput {
  nodes : Array[@cgraph.Node]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  x_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_order : Map[String, Int]
  node_order : Map[String, Int]
  x_order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_skeleton : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: non-cluster xpos reorder inputs keep vnode-expanded edge
/// index data, precomputed port hints, and rank-order metadata together for a
/// single reorder_rank_groups call.
priv struct NonclusteredXposReorderInput {
  nodes : Array[@cgraph.Node]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  ranks : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  x_cluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_order : Map[String, Int]
  node_order : Map[String, Int]
  x_order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_skeleton : Map[String, Bool]
  flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: non-cluster xpos reorder keeps vnode-edge input,
/// port-hint derivation, and reorder apply wiring identical to Graphviz flow.
/// Do not change behavior without updating fixtures/tests.
fn reorder_nonclustered_x_groups(
  input : NonclusteredXposReorderInput,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let edge_index_data = @ordering.build_edge_index_with_vnodes(
    input.nodes,
    input.order_edges,
    input.order_edge_tail,
    input.order_edge_head,
    input.ranks,
    input.edge_vnodes,
    input.vnode_ranks,
  )
  let parents = edge_index_data.parents
  let children = edge_index_data.children
  let tmp_rank_keys = @ordering.collect_rank_keys(x_groups)
  @ordering.reorder_rank_groups(
    tmp_rank_keys,
    x_groups,
    input.order_edges,
    input.order_edge_tail,
    input.order_edge_head,
    input.order_edge_tail_port_x,
    input.order_edge_head_port_x,
    input.order_edge_tail_port_order,
    input.order_edge_head_port_order,
    parents,
    children,
    input.x_cluster_keys,
    input.rank_same_groups,
    input.rank_same_order,
    input.edge_order,
    input.node_order,
    input.x_order_sizes,
    input.nodesep_pt,
    input.has_edge_labels,
    input.port_order_positions,
    input.port_order_contrib,
    Map::new(),
    input.cluster_skeleton,
    input.flat_constraints,
    graphviz_flip=input.graphviz_flip,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder build path keeps port-hint
/// derivation and reorder apply wiring in the same sequence as Graphviz flow.
/// Do not change behavior without updating fixtures/tests.
pub fn build_nonclustered_xpos_groups(
  input : NonclusteredXposGroupBuildInput,
  x_groups : Map[Int, Array[String]],
  port_samples : XposPortSamples,
) -> Map[Int, Array[String]] {
  reorder_nonclustered_x_groups(
    {
      nodes: input.nodes,
      order_edges: input.order_edges,
      order_edge_tail: input.order_edge_tail,
      order_edge_head: input.order_edge_head,
      ranks: input.ranks,
      edge_vnodes: input.edge_vnodes,
      vnode_ranks: input.vnode_ranks,
      order_edge_tail_port_x: port_samples.tail_port_x,
      order_edge_head_port_x: port_samples.head_port_x,
      order_edge_tail_port_order: port_samples.tail_port_order,
      order_edge_head_port_order: port_samples.head_port_order,
      x_cluster_keys: input.x_cluster_keys,
      rank_same_groups: input.rank_same_groups,
      rank_same_order: input.rank_same_order,
      edge_order: input.edge_order,
      node_order: input.node_order,
      x_order_sizes: input.x_order_sizes,
      nodesep_pt: input.nodesep_pt,
      has_edge_labels: input.has_edge_labels,
      port_order_positions: input.port_order_positions,
      port_order_contrib: input.port_order_contrib,
      cluster_skeleton: input.cluster_skeleton,
      flat_constraints: input.flat_constraints,
      graphviz_flip: input.graphviz_flip,
    },
    x_groups,
  )
}
