///|
/// Stage D Phase D4 split: non-cluster x-constraint solve
/// helpers used by the shared reorder branch flow.

///|
/// Graphviz parity: non-cluster xpos reorder build path keeps vnode-edge input,
/// port-hint derivation, and reorder apply wiring identical to Graphviz flow.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reordered_groups_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let (parents, children) = build_edge_index_for_order_with_vnodes(
    prep.nodes,
    ordering.order_edges,
    ordering.order_edge_tail,
    ordering.order_edge_head,
    rank_data.ranks,
    ordering.vnode_info.edge_vnodes,
    ordering.vnode_info.vnode_ranks,
  )
  let tmp_rank_keys = collect_rank_keys(x_groups)
  // Graphviz parity: even non-cluster xpos reorder uses compass/record
  // port-order fractions when mincross scoring ties are evaluated.
  let (order_edge_tail_port_x, order_edge_head_port_x) =
    compute_edge_port_positions(
      prep.nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      x_order_sizes,
    )
  let (order_edge_tail_port_order, order_edge_head_port_order) =
    compute_edge_port_orders(
      prep.nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      x_order_sizes,
    )
  reorder_rank_groups(
    tmp_rank_keys,
    x_groups,
    ordering.order_edges,
    ordering.order_edge_tail,
    ordering.order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    parents,
    children,
    x_cluster_keys,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    ordering.edge_order,
    prep.node_order,
    x_order_sizes,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    prep.port_order_positions,
    prep.port_order_contrib,
    Map::new(),
    cluster_meta.cluster_skeleton,
    cluster_meta.flat_constraints,
    graphviz_flip=graphviz_flip,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder fallback runs only when clustered
/// vnode reorder path is not taken, matching Graphviz branch structure.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_noncluster_xpos_reorder_fallback(
  xpos_reorder_enabled : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if xpos_reorder_enabled && allow_xpos_reorder && !cluster_meta.ordering_set &&
    !has_vnode_order && !cluster_meta.has_clusters {
    build_noncluster_xpos_reordered_groups_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_order_sizes,
      x_cluster_keys,
      graphviz_flip,
      x_groups,
    )
  } else {
    x_groups
  }
}
