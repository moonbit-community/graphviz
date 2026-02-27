///|
/// Stage D Phase D4 split: non-cluster x-constraint solve
/// helpers used by the shared reorder branch flow.

///|
/// Graphviz parity: non-cluster xpos reorder uses both geometric port x and
/// compass/record port-order hints for mincross tie-breaking, same as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reorder_port_hints_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
) -> (Array[Double], Array[Double], Array[Double], Array[Double]) {
  let (order_edge_tail_port_x, order_edge_head_port_x) =
    compute_edge_port_positions(
      nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      x_order_sizes,
    )
  let (order_edge_tail_port_order, order_edge_head_port_order) =
    compute_edge_port_orders(
      nodes,
      ordering.order_edges,
      ordering.order_edge_tail,
      ordering.order_edge_head,
      x_order_sizes,
    )
  (
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder reads vnode edge-index parents/
/// children and current rank keys before calling reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reorder_graph_inputs_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> (Map[String, Array[String]], Map[String, Array[String]], Array[Int]) {
  let (parents, children) = build_edge_index_for_order_with_vnodes(
    nodes,
    ordering.order_edges,
    ordering.order_edge_tail,
    ordering.order_edge_head,
    ranks,
    ordering.vnode_info.edge_vnodes,
    ordering.vnode_info.vnode_ranks,
  )
  let tmp_rank_keys = collect_rank_keys(x_groups)
  (parents, children, tmp_rank_keys)
}

///|
/// Graphviz parity: non-cluster reorder input assembly keeps vnode edge-index
/// and port-hint derivation in Graphviz-aligned order before reorder apply.
/// Do not change behavior without updating fixtures/tests.
fn build_noncluster_xpos_reorder_inputs_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
) -> NonclusterXposReorderInputs {
  let (parents, children, tmp_rank_keys) =
    build_noncluster_xpos_reorder_graph_inputs_for_positions(
      prep.nodes,
      ordering,
      rank_data.ranks,
      x_groups,
    )
  // Graphviz parity: even non-cluster xpos reorder uses compass/record
  // port-order fractions when mincross scoring ties are evaluated.
  let (
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  ) = build_noncluster_xpos_reorder_port_hints_for_positions(
    prep.nodes,
    ordering,
    x_order_sizes,
  )
  {
    parents,
    children,
    tmp_rank_keys,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: non-cluster reorder_rank_groups consumes the same port-hint,
/// parent/child, and cluster/order maps as Graphviz branch wiring.
/// Do not change behavior without updating fixtures/tests.
fn apply_noncluster_xpos_reorder_rank_groups_for_positions(
  tmp_rank_keys : Array[Int],
  x_groups : Map[Int, Array[String]],
  ordering : OrderingResult,
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  x_cluster_keys : Map[String, String],
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  x_order_sizes : Map[String, NodeSize],
  rank_heights : RankHeights,
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
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
  let noncluster_reorder_inputs =
    build_noncluster_xpos_reorder_inputs_for_positions(
      prep,
      rank_data,
      ordering,
      x_order_sizes,
      x_groups,
    )
  apply_noncluster_xpos_reorder_rank_groups_for_positions(
    noncluster_reorder_inputs.tmp_rank_keys,
    x_groups,
    ordering,
    noncluster_reorder_inputs.order_edge_tail_port_x,
    noncluster_reorder_inputs.order_edge_head_port_x,
    noncluster_reorder_inputs.order_edge_tail_port_order,
    noncluster_reorder_inputs.order_edge_head_port_order,
    noncluster_reorder_inputs.parents,
    noncluster_reorder_inputs.children,
    x_cluster_keys,
    cluster_meta,
    prep,
    x_order_sizes,
    rank_heights,
    graphviz_flip,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder gate matches Graphviz branch
/// predicate (non-cluster path only, no vnode-order fallback path).
/// Do not change behavior without updating fixtures/tests.
fn should_apply_noncluster_xpos_reorder_for_positions(
  xpos_reorder_enabled : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
) -> Bool {
  xpos_reorder_enabled && allow_xpos_reorder && !cluster_meta.ordering_set &&
  !has_vnode_order && !cluster_meta.has_clusters
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
  if should_apply_noncluster_xpos_reorder_for_positions(
    xpos_reorder_enabled,
    allow_xpos_reorder,
    has_vnode_order,
    cluster_meta,
  ) {
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
