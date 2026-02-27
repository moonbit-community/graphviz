///|
/// Stage D Phase D3 split: optional reorder/transpose-cleanup
/// helpers for x-stage rank-group refinement.

///|
/// Graphviz parity: vnode xpos-reorder gate is shared across reorder branch
/// selection and transpose cleanup eligibility.
/// Do not change behavior without updating fixtures/tests.
fn should_apply_vnode_xpos_reorder_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  cluster_meta : ClusterMetadata,
) -> Bool {
  xpos_reorder_enabled && use_vnodes_for_xpos && allow_xpos_reorder &&
  !cluster_meta.ordering_set
}

///|
/// Graphviz parity: xpos reorder branch resolver keeps clustered vs non-cluster
/// routing unchanged before transpose-cleanup stage.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_reordered_groups_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if should_apply_vnode_xpos_reorder_for_positions(
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    cluster_meta,
  ) {
    build_clustered_xpos_reordered_groups(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_groups,
      x_order_sizes,
      x_cluster_keys,
      x_edge_tail_port_x,
      x_edge_head_port_x,
      x_edge_tail_port_order,
      x_edge_head_port_order,
      graphviz_flip,
    )
  } else {
    maybe_apply_noncluster_xpos_reorder_fallback(
      xpos_reorder_enabled,
      allow_xpos_reorder,
      has_vnode_order,
      cluster_meta,
      prep,
      rank_data,
      rank_heights,
      ordering,
      x_order_sizes,
      x_cluster_keys,
      graphviz_flip,
      x_groups,
    )
  }
}

///|
/// Graphviz parity: xpos reorder control-flow must match Graphviz clustered/non-cluster
/// branch selection before transpose cleanup.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_xpos_reorder_for_positions(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  has_vnode_order : Bool,
  cluster_meta : ClusterMetadata,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  x_order_sizes : Map[String, NodeSize],
  x_cluster_keys : Map[String, String],
  x_edge_tail_port_x : Array[Double],
  x_edge_head_port_x : Array[Double],
  x_edge_tail_port_order : Array[Double],
  x_edge_head_port_order : Array[Double],
  graphviz_flip : Bool,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  build_xpos_reordered_groups_for_positions(
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    has_vnode_order,
    cluster_meta,
    prep,
    rank_data,
    rank_heights,
    ordering,
    x_order_sizes,
    x_cluster_keys,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
    graphviz_flip,
    x_groups,
  )
}

///|
/// Graphviz parity: transpose cleanup performs two limited passes in fixed
/// order (forward then reverse), matching Graphviz fixture behavior.
/// Do not change behavior without updating fixtures/tests.
fn apply_xpos_transpose_cleanup_passes(
  tmp_rank_keys : Array[Int],
  x_groups : Map[Int, Array[String]],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  tmp_ranks : Map[String, Int],
) -> Unit {
  let _ = transpose_rank_groups_limited(
    tmp_rank_keys,
    x_groups,
    parents,
    children,
    tmp_ranks,
    false,
    4,
  )
  let _ = transpose_rank_groups_limited(
    tmp_rank_keys,
    x_groups,
    parents,
    children,
    tmp_ranks,
    true,
    4,
  )
}

///|
/// Graphviz parity: transpose cleanup input derivation uses vnode edge index
/// plus current x_groups rank snapshot before limited transpose passes.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_transpose_cleanup_inputs_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> XposTransposeCleanupInputs {
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
  let tmp_ranks = build_node_ranks(x_groups)
  { parents, children, tmp_rank_keys, tmp_ranks }
}

///|
/// Graphviz parity: transpose cleanup apply step preserves input derivation
/// and fixed two-pass execution order used by Graphviz-aligned fixtures.
/// Do not change behavior without updating fixtures/tests.
fn apply_xpos_transpose_cleanup_for_positions(
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> Unit {
  let transpose_cleanup_inputs =
    build_xpos_transpose_cleanup_inputs_for_positions(
      nodes,
      ordering,
      ranks,
      x_groups,
    )
  apply_xpos_transpose_cleanup_passes(
    transpose_cleanup_inputs.tmp_rank_keys,
    x_groups,
    transpose_cleanup_inputs.parents,
    transpose_cleanup_inputs.children,
    transpose_cleanup_inputs.tmp_ranks,
  )
}

///|
/// Graphviz parity: optional transpose cleanup runs only in vnode xpos-reorder
/// mode after reorder_rank_groups, and mutates x_groups in-place.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_xpos_transpose_cleanup(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  cluster_meta : ClusterMetadata,
  nodes : Array[@cgraph.Node],
  ordering : OrderingResult,
  ranks : Map[String, Int],
  x_groups : Map[Int, Array[String]],
) -> Unit {
  if should_apply_vnode_xpos_reorder_for_positions(
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    cluster_meta,
  ) {
    apply_xpos_transpose_cleanup_for_positions(
      nodes,
      ordering,
      ranks,
      x_groups,
    )
  }
}
