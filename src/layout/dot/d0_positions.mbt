///|
/// Stage D Phase D0 split: position/xpos stage-local
/// type definitions shared across Stage D helper phases.

///|
priv struct PositionResult {
  x_groups : Map[Int, Array[String]]
  rank_y : Map[Int, Double]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
  flat_label_edge_vnodes : Map[String, String]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
}

///|
priv struct XposComputationInput {
  x_sizes : Map[String, NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[@ordering.ExtraConstraintNode]
  x_edge_vnodes : Map[String, Array[String]]
}

///|
priv struct XposVNodeOrderState {
  vnode_order_keys : Map[String, Double]
  has_vnode_order : Bool
}

///|
priv struct XposOrderEdgePortData {
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
}

///|
priv struct XPositionSeedData {
  has_vnode_order : Bool
  x_base_sizes : Map[String, NodeSize]
  x_order_sizes : Map[String, NodeSize]
  x_edge_tail_port_x : Array[Double]
  x_edge_head_port_x : Array[Double]
  x_edge_tail_port_order : Array[Double]
  x_edge_head_port_order : Array[Double]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
}

///|
priv struct XposFlatLabelAugmentation {
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
priv struct YPositionComputationData {
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
}

///|
priv struct PositionOutputMaps {
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
priv struct XWithFlatLabelData {
  use_vnodes_for_xpos : Bool
  x_base_sizes : Map[String, NodeSize]
  x_groups : Map[Int, Array[String]]
  x_cluster_keys : Map[String, String]
  flat_label_edges : Array[ConstraintEdge]
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
  flat_label_edge_vnodes : Map[String, String]
}

///|
priv struct PositionModeFlags {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
}

///|
/// Graphviz parity: xpos reorder control flags are evaluated once and then
/// reused by clustered/non-clustered branch and transpose cleanup gates.
priv struct XposReorderControl {
  xpos_reorder_enabled : Bool
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  has_vnode_order : Bool
}

///|
/// Graphviz parity: clustered/non-clustered xpos reorder branch gates are
/// derived once from reorder control+context and reused unchanged by reorder
/// and transpose cleanup routing.
priv struct XposReorderPathFlags {
  clustered_reorder_enabled : Bool
  nonclustered_reorder_enabled : Bool
}

///|
/// Graphviz parity: xpos reorder branch keeps shared graph/rank/ordering
/// inputs grouped together so clustered/non-clustered paths consume the same
/// payload without argument reordering.
priv struct XposReorderContext {
  prep : LayoutPrep
  rank_data : RankData
  rank_heights : RankHeights
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
  x_order_sizes : Map[String, NodeSize]
  x_cluster_keys : Map[String, String]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: clustered xpos reorder keeps edge-port x/order samples in
/// one payload for order-graph edge materialization.
priv struct XposReorderPortData {
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
}


///|
/// Stage D Phase D1/D2/D3/D5 split: xpos mode/seed/reorder-cleanup
/// helpers used by the Stage D position orchestrator.

///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once from prep+ordering and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_flags(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> PositionModeFlags {
  let use_vnodes_for_xpos =
    prep.has_edge_labels || prep.has_port_edges ||
    ordering.vnode_count <= MAX_XPOS_VNODES
  let allow_xpos_reorder =
    !use_vnodes_for_xpos || ordering.vnode_count <= MAX_XPOS_REORDER_VNODES
  let graphviz_flip = prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL
  {
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    graphviz_flip,
  }
}


///|
/// Graphviz parity: x-stage precompute in compute_positions keeps mode flags,
/// reorder/transpose, and flat-label augmentation in Graphviz-aligned order
/// and wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_x_with_flat_labels(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XWithFlatLabelData {
  let mode_flags = build_position_mode_flags(prep, ordering)
  let x_seed =
    build_x_seed_data(
      mode_flags.use_vnodes_for_xpos,
      prep,
      rank_data,
      cluster_meta,
      ordering,
    )
  let flat_label_augmentation =
    build_x_flat_labels(
      false,
      mode_flags.use_vnodes_for_xpos,
      mode_flags.allow_xpos_reorder,
      mode_flags.graphviz_flip,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_seed,
    )
  {
    use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
    x_base_sizes: x_seed.x_base_sizes,
    x_groups: flat_label_augmentation.x_groups,
    x_cluster_keys: flat_label_augmentation.x_cluster_keys,
    flat_label_edges: flat_label_augmentation.flat_label_edges,
    flat_label_nodes: flat_label_augmentation.flat_label_nodes,
    flat_label_edge_vnodes: flat_label_augmentation.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: vnode order-key derivation follows Graphviz: explicit
/// ordered_groups_with_vnodes means vnode order is present; otherwise build
/// keys from edge-vnode chains and mark presence by non-empty key map.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_state(
  use_vnodes_for_xpos : Bool,
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  prep : LayoutPrep,
  rank_data : RankData,
  order_index : Map[String, Int],
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XposVNodeOrderState {
  let mut vnode_order_keys : Map[String, Double] = Map::new()
  let mut has_vnode_order = false
  if use_vnodes_for_xpos && ordered_groups_with_vnodes.length() == 0 {
    vnode_order_keys = build_vnode_order_keys(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.edge_reversed,
      rank_data.ranks,
      order_index,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      ordering.vnode_info.edge_vnodes,
      ordering.vnode_info.vnode_ranks,
    )
    for _name, _ in vnode_order_keys {
      has_vnode_order = true
      break
    }
  }
  if use_vnodes_for_xpos && ordered_groups_with_vnodes.length() > 0 {
    has_vnode_order = true
  }
  { vnode_order_keys, has_vnode_order }
}

///|
/// Graphviz parity: x-order sizes and edge port position/order arrays are
/// derived from layout-coordinate sizes before any xpos reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_x_order_edge_port_data(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
) -> XposOrderEdgePortData {
  // Graphviz parity: x-positioning uses layout-coordinate node sizes,
  // so rankdir flip is handled via prep.sizes (not ordering-space widths).
  let x_base_sizes = apply_self_edge_right_space(
    prep.nodes,
    prep.edges,
    prep.sizes,
    prep.rankdir,
    prep.record_orientation,
  )
  let x_order_sizes =
    if use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let x_edge_port_x_samples =
    compute_edge_port_positions(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let x_edge_tail_port_x = x_edge_port_x_samples.tail_values
  let x_edge_head_port_x = x_edge_port_x_samples.head_values
  let x_edge_port_order_samples =
    compute_edge_port_orders(
      prep.nodes,
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      x_order_sizes,
    )
  let x_edge_tail_port_order = x_edge_port_order_samples.tail_values
  let x_edge_head_port_order = x_edge_port_order_samples.head_values
  {
    x_base_sizes,
    x_order_sizes,
    x_edge_tail_port_x,
    x_edge_head_port_x,
    x_edge_tail_port_order,
    x_edge_head_port_order,
  }
}


///|
/// Graphviz parity: flat-label vnode augmentation updates x-groups, injected
/// label edges, and vnode cluster-key overlay only on vnode-xpos path.
/// Do not change behavior without updating fixtures/tests.
fn build_flat_label_augmentation(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
) -> XposFlatLabelAugmentation {
  let mut next_x_groups = x_groups
  let mut flat_label_edges : Array[ConstraintEdge] = []
  let mut flat_label_nodes : Map[String, FlatLabelNodeInfo] = Map::new()
  let mut flat_label_edge_vnodes : Map[String, String] = Map::new()
  let next_x_cluster_keys = x_cluster_keys
  let existing_names : Map[String, Bool] = Map::new()
  for node in prep.nodes {
    existing_names[node.name()] = true
  }
  for vnode, _ in ordering.vnode_info.vnode_ranks {
    existing_names[vnode] = true
  }
  if use_vnodes_for_xpos {
    let flat_label_vnodes = add_flat_label_vnodes(
      prep.edges,
      rank_data.edge_tail,
      rank_data.edge_head,
      rank_data.ranks,
      ordering.ordered_groups,
      rank_heights.nodesep_pt,
      prep.rankdir,
      x_base_sizes,
      ordering.edge_cluster_keys,
      cluster_meta.cluster_parents,
      existing_names,
      ordering.vnode_info,
      next_x_groups,
    )
    next_x_groups = flat_label_vnodes.x_groups
    flat_label_edges = flat_label_vnodes.flat_label_edges
    flat_label_nodes = flat_label_vnodes.flat_label_nodes
    flat_label_edge_vnodes = flat_label_vnodes.flat_label_edge_vnodes
    for name, key in ordering.vnode_info.vnode_clusters {
      next_x_cluster_keys[name] = key
    }
  }
  {
    x_groups: next_x_groups,
    x_cluster_keys: next_x_cluster_keys,
    flat_label_edges,
    flat_label_nodes,
    flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: reorder branch gating is evaluated once so clustered and
/// non-clustered paths consume identical predicates as transpose cleanup.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_reorder_path_flags(
  reorder_control : XposReorderControl,
  reorder_context : XposReorderContext,
) -> XposReorderPathFlags {
  let base_reorder_enabled =
    reorder_control.xpos_reorder_enabled &&
    reorder_control.allow_xpos_reorder &&
    !reorder_context.cluster_meta.ordering_set
  {
    clustered_reorder_enabled:
      base_reorder_enabled && reorder_control.use_vnodes_for_xpos,
    nonclustered_reorder_enabled:
      base_reorder_enabled &&
      !reorder_control.has_vnode_order &&
      !reorder_context.cluster_meta.has_clusters,
  }
}

///|
/// Graphviz parity: non-cluster xpos reorder fallback runs only when clustered
/// vnode reorder path is not taken, matching Graphviz branch structure.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_nonclustered_xpos(
  path_flags : XposReorderPathFlags,
  reorder_context : XposReorderContext,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if path_flags.nonclustered_reorder_enabled {
    @positioning.build_nonclustered_xpos_groups(
      @positioning.build_nonclustered_xpos_group_build_input(
        reorder_context.prep.nodes,
        reorder_context.ordering.order_edges,
        reorder_context.ordering.order_edge_tail,
        reorder_context.ordering.order_edge_head,
        reorder_context.rank_data.ranks,
        reorder_context.ordering.vnode_info.edge_vnodes,
        reorder_context.ordering.vnode_info.vnode_ranks,
        reorder_context.x_cluster_keys,
        reorder_context.cluster_meta.rank_same_groups,
        reorder_context.cluster_meta.rank_same_order,
        reorder_context.ordering.edge_order,
        reorder_context.prep.node_order,
        reorder_context.x_order_sizes,
        reorder_context.rank_heights.nodesep_pt,
        reorder_context.prep.has_edge_labels,
        reorder_context.prep.port_order_positions,
        reorder_context.prep.port_order_contrib,
        reorder_context.cluster_meta.cluster_skeleton,
        reorder_context.cluster_meta.flat_constraints,
        reorder_context.graphviz_flip,
      ),
      x_groups,
      (nodes, edges, edge_tail, edge_head, sizes) => {
        // Graphviz parity: even non-cluster xpos reorder uses compass/record
        // port-order fractions when mincross scoring ties are evaluated.
        let samples =
          compute_edge_port_positions(nodes, edges, edge_tail, edge_head, sizes)
        (samples.tail_values, samples.head_values)
      },
      (nodes, edges, edge_tail, edge_head, sizes) => {
        let samples =
          compute_edge_port_orders(nodes, edges, edge_tail, edge_head, sizes)
        (samples.tail_values, samples.head_values)
      },
    )
  } else {
    x_groups
  }
}


///|
/// Graphviz parity: xpos reorder branch resolver keeps clustered vs non-cluster
/// routing unchanged before transpose-cleanup stage.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_reordered_groups(
  path_flags : XposReorderPathFlags,
  reorder_context : XposReorderContext,
  reorder_port_data : XposReorderPortData,
  x_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  if path_flags.clustered_reorder_enabled {
    @positioning.build_clustered_xpos_groups(
      @positioning.build_clustered_xpos_reorder_input(
        x_groups,
        reorder_context.x_order_sizes,
        reorder_context.x_cluster_keys,
        reorder_context.cluster_meta.cluster_min_rank,
        reorder_context.cluster_meta.cluster_max_rank,
        reorder_context.prep.node_order,
        CLUSTER_SKELETON_PREFIX,
        vnode_size_from_widths(1.0, 1.0),
        reorder_context.prep.edges,
        reorder_context.rank_data.edge_tail,
        reorder_context.rank_data.edge_head,
        reorder_context.rank_data.ranks,
        reorder_context.ordering.vnode_info.edge_vnodes,
        reorder_port_data.edge_tail_port_x,
        reorder_port_data.edge_head_port_x,
        reorder_port_data.edge_tail_port_order,
        reorder_port_data.edge_head_port_order,
        CL_CROSS,
        reorder_context.cluster_meta.rank_same_groups,
        reorder_context.cluster_meta.rank_same_order,
        reorder_context.rank_heights.nodesep_pt,
        reorder_context.prep.has_edge_labels,
        reorder_context.cluster_meta.flat_constraints,
        reorder_context.graphviz_flip,
      ),
    )
  } else {
    maybe_apply_nonclustered_xpos(
      path_flags,
      reorder_context,
      x_groups,
    )
  }
}

///|
/// Graphviz parity: optional transpose cleanup runs only in vnode xpos-reorder
/// mode after reorder_rank_groups, and mutates x_groups in-place.
/// Do not change behavior without updating fixtures/tests.
fn maybe_apply_xpos_transpose(
  path_flags : XposReorderPathFlags,
  reorder_context : XposReorderContext,
  x_groups : Map[Int, Array[String]],
) -> Unit {
  if path_flags.clustered_reorder_enabled {
    @positioning.apply_xpos_transpose_cleanup(
      x_groups,
      @positioning.build_xpos_transpose_cleanup_input(
        reorder_context.prep.nodes,
        reorder_context.ordering.order_edges,
        reorder_context.ordering.order_edge_tail,
        reorder_context.ordering.order_edge_head,
        reorder_context.rank_data.ranks,
        reorder_context.ordering.vnode_info.edge_vnodes,
        reorder_context.ordering.vnode_info.vnode_ranks,
      ),
      4,
    )
  }
}

///|
/// Stage D Phase D0 split: position orchestrator helpers
/// for x/y solve assembly and final result wiring.

///|
priv struct ClusterBoundaryXOutput {
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
/// Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_boundary_x(
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  x_positions : Map[String, Double],
) -> ClusterBoundaryXOutput {
  let cluster_ln_x : Map[String, Double] = Map::new()
  let cluster_rn_x : Map[String, Double] = Map::new()
  if cluster_meta.has_clusters {
    let cluster_names : Map[String, Bool] = Map::new()
    collect_cluster_names(graph, cluster_names)
    if cluster_names.length() > 0 {
      for name, pos_x in x_positions {
        if name.has_prefix(CLUSTER_LN_PREFIX) ||
          name.has_prefix(CLUSTER_RN_PREFIX) {
          match cluster_key_from_boundary(name, cluster_names) {
            Some(cluster_key) =>
              if name.has_prefix(CLUSTER_LN_PREFIX) {
                cluster_ln_x[cluster_key] = pos_x
              } else {
                cluster_rn_x[cluster_key] = pos_x
              }
            None => ()
          }
        }
      }
    }
  }
  { cluster_ln_x, cluster_rn_x }
}

///|
/// Graphviz parity: vnode output positions are either direct xpos/rank pairs
/// (when xpos consumed vnode graph) or endpoint-interpolated fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_positions(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  ordering : OrderingResult,
  x_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> Map[String, @geom.Point] {
  if use_vnodes_for_xpos {
    let positions : Map[String, @geom.Point] = Map::new()
    for name, rank in ordering.vnode_info.vnode_ranks {
      let pos_x = match x_positions.get(name) {
        Some(value) => value
        None => 0.0
      }
      let pos_y = match rank_y.get(rank) {
        Some(value) => value
        None => 0.0
      }
      positions[name] = { x: pos_x, y: pos_y }
    }
    positions
  } else {
    vnode_positions_from_edges(
      prep.edges,
      rank_data.ranks,
      ordering.vnode_info.vnode_ranks,
      ordering.vnode_info.edge_vnodes,
      x_positions,
      rank_y,
    )
  }
}

///|
/// Graphviz parity: initial x-groups must preserve vnode-aware ordering and
/// strip cluster skeleton placeholders before xpos constraints run.
/// Do not change behavior without updating fixtures/tests.
fn build_initial_x_groups(
  use_vnodes_for_xpos : Bool,
  ordered_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  order_index : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys : Map[String, Double],
  cluster_meta : ClusterMetadata,
) -> Map[Int, Array[String]] {
  let mut x_groups =
    if use_vnodes_for_xpos {
      if ordered_groups_with_vnodes.length() > 0 {
        @ordering.clone_rank_groups(ordered_groups_with_vnodes)
      } else {
        @ordering.build_x_groups_with_vnodes(
          ordered_groups,
          order_index,
          vnodes_by_rank,
          vnode_order_keys,
        )
      }
    } else {
      ordered_groups
    }
  if cluster_meta.has_clusters {
    let cleaned : Map[Int, Array[String]] = Map::new()
    for rank, names in x_groups {
      let filtered : Array[String] = []
      for name in names {
        if cluster_key_from_skeleton(name) is None {
          filtered.push(name)
        }
      }
      if filtered.length() > 0 {
        cleaned[rank] = filtered
      }
    }
    x_groups = cleaned
  }
  x_groups
}

///|
/// Graphviz parity: pre-reorder x-stage setup keeps order-index build, vnode
/// order probing, edge-port metadata, and initial group/cluster maps unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_seed_data(
  use_vnodes_for_xpos : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XPositionSeedData {
  let order_index = @ordering.build_order_index(ordering.ordered_groups)
  let vnode_order_state =
    build_vnode_order_state(
      use_vnodes_for_xpos,
      ordering.ordered_groups_with_vnodes,
      prep,
      rank_data,
      order_index,
      cluster_meta,
      ordering,
    )
  let has_vnode_order = vnode_order_state.has_vnode_order
  let x_order_edge_port_data =
    build_x_order_edge_port_data(
      use_vnodes_for_xpos,
      prep,
      rank_data,
      ordering,
    )
  let x_groups =
    build_initial_x_groups(
      use_vnodes_for_xpos,
      ordering.ordered_groups,
      ordering.ordered_groups_with_vnodes,
      order_index,
      ordering.vnode_info.vnodes_by_rank,
      vnode_order_state.vnode_order_keys,
      cluster_meta,
    )
  let x_cluster_keys : Map[String, String] = Map::new()
  for name, key in cluster_meta.cluster_keys {
    x_cluster_keys[name] = key
  }
  if use_vnodes_for_xpos {
    for name, key in ordering.vnode_info.vnode_clusters {
      x_cluster_keys[name] = key
    }
  }
  {
    has_vnode_order,
    x_base_sizes: x_order_edge_port_data.x_base_sizes,
    x_order_sizes: x_order_edge_port_data.x_order_sizes,
    x_edge_tail_port_x: x_order_edge_port_data.x_edge_tail_port_x,
    x_edge_head_port_x: x_order_edge_port_data.x_edge_head_port_x,
    x_edge_tail_port_order: x_order_edge_port_data.x_edge_tail_port_order,
    x_edge_head_port_order: x_order_edge_port_data.x_edge_head_port_order,
    x_groups,
    x_cluster_keys,
  }
}

///|
/// Graphviz parity: x-stage reorder and transpose-cleanup are applied in
/// fixed order before flat-label augmentation consumes updated x_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_x_groups_after_reorder(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  graphviz_flip : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_seed : XPositionSeedData,
) -> Map[Int, Array[String]] {
  let reorder_control : XposReorderControl = {
    xpos_reorder_enabled,
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    has_vnode_order: x_seed.has_vnode_order,
  }
  let reorder_context : XposReorderContext = {
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    x_order_sizes: x_seed.x_order_sizes,
    x_cluster_keys: x_seed.x_cluster_keys,
    graphviz_flip,
  }
  let reorder_port_data : XposReorderPortData = {
    edge_tail_port_x: x_seed.x_edge_tail_port_x,
    edge_head_port_x: x_seed.x_edge_head_port_x,
    edge_tail_port_order: x_seed.x_edge_tail_port_order,
    edge_head_port_order: x_seed.x_edge_head_port_order,
  }
  let path_flags = build_xpos_reorder_path_flags(reorder_control, reorder_context)
  let x_groups =
    build_xpos_reordered_groups(
      path_flags,
      reorder_context,
      reorder_port_data,
      x_seed.x_groups,
    )
  maybe_apply_xpos_transpose(
    path_flags,
    reorder_context,
    x_groups,
  )
  x_groups
}

///|
/// Graphviz parity: x-stage reorder + transpose cleanup + flat-label vnode
/// augmentation must run in the same order and with the same inputs as Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_x_flat_labels(
  xpos_reorder_enabled : Bool,
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  graphviz_flip : Bool,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_seed : XPositionSeedData,
) -> XposFlatLabelAugmentation {
  let x_groups =
    build_x_groups_after_reorder(
      xpos_reorder_enabled,
      use_vnodes_for_xpos,
      allow_xpos_reorder,
      graphviz_flip,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_seed,
    )
  build_flat_label_augmentation(
    use_vnodes_for_xpos,
    prep,
    rank_data,
    ordering,
    rank_heights,
    cluster_meta,
    x_seed.x_base_sizes,
    x_groups,
    x_seed.x_cluster_keys,
  )
}

///|
/// Graphviz parity: xpos solver inputs must preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_computation_input(
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  ordering : OrderingResult,
) -> XposComputationInput {
  let x_sizes =
    if use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(x_base_sizes, ordering.vnode_info.vnode_sizes)
    } else {
      x_base_sizes
    }
  let x_rank_keys = @ordering.collect_rank_keys(x_groups)
  let x_ranks = @ordering.build_node_ranks(x_groups)
  let vnode_extra_nodes =
    if use_vnodes_for_xpos {
      @ordering.build_vnode_extra_nodes(
        ordering.vnode_creation_order,
        ordering.vnode_info.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if use_vnodes_for_xpos {
      ordering.vnode_info.edge_vnodes
    } else {
      Map::new()
    }
  { x_sizes, x_rank_keys, x_ranks, x_extra_nodes, x_edge_vnodes }
}

///|
/// Graphviz parity: x-position stage must use identical xpos input assembly,
/// and solver invocation as Graphviz-aligned pipeline order.
/// Do not change behavior without updating fixtures/tests.
fn compute_layout_x_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  flat_label_edges : Array[ConstraintEdge],
) -> Map[String, Double] {
  let xpos_input =
    build_xpos_computation_input(
      use_vnodes_for_xpos,
      x_base_sizes,
      x_groups,
      ordering,
    )
  let x_positions = compute_x_positions(
    graph,
    prep.nodes,
    prep.edges,
    rank_data.edge_tail,
    rank_data.edge_head,
    rank_data.edge_out_order,
    ordering.nlist_order,
    ordering.gdnlist_order,
    xpos_input.x_ranks,
    xpos_input.x_rank_keys,
    x_groups,
    xpos_input.x_sizes,
    prep.output_sizes,
    x_cluster_keys,
    rank_heights.nodesep_pt,
    prep.has_edge_labels,
    xpos_input.x_extra_nodes,
    flat_label_edges,
    xpos_input.x_edge_vnodes,
  )
  x_positions
}


///|
/// Graphviz parity: flat-edge label vnodes can raise per-rank half-heights,
/// and these maxima must feed y-rank placement exactly as in Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn apply_flat_label_heights(
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  vnode_sizes : Map[String, NodeSize],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Unit {
  if flat_label_nodes.length() > 0 {
    for name, info in flat_label_nodes {
      let size = match vnode_sizes.get(name) {
        Some(value) => value
        None => continue
      }
      let half_height = size.height_pt / 2.0
      let rank = info.rank
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current {
        rank_pht[rank] = half_height
      }
      let current_ht1 = match rank_ht1.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht1 {
        rank_ht1[rank] = half_height
      }
      let current_ht2 = match rank_ht2.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if half_height > current_ht2 {
        rank_ht2[rank] = half_height
      }
    }
  }
}

///|
/// Graphviz parity: y-rank sweep range expands to include inserted flat-label
/// vnode ranks, while preserving continuous rank iteration.
/// Do not change behavior without updating fixtures/tests.
fn build_y_all_ranks_with_flat(
  rank_keys : Array[Int],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> Array[Int] {
  let y_all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let mut min_rank = rank_keys[0]
    let mut max_rank = rank_keys[rank_keys.length() - 1]
    if flat_label_nodes.length() > 0 {
      for _name, info in flat_label_nodes {
        if info.rank < min_rank {
          min_rank = info.rank
        }
        if info.rank > max_rank {
          max_rank = info.rank
        }
      }
    }
    for rank in min_rank..=max_rank {
      y_all_ranks.push(rank)
    }
  }
  y_all_ranks
}

///|
/// Graphviz parity: when flipped cluster-rank heights adjust rank_y, node y
/// coordinates are rebuilt from rank order/groups without extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_from_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
) -> Map[String, Double] {
  let y_positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let pos_y = match rank_y.get(rank) {
      Some(value) => value
      None => 0.0
    }
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      y_positions[name] = pos_y
    }
  }
  y_positions
}

///|
/// Graphviz parity: y-position stage runs fill_rank_positions first, then
/// optional flip-cluster height correction (cluster.c path) and y rebuild.
/// Do not change behavior without updating fixtures/tests.
priv struct YPositionsWithFlipOutput {
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
}

///|
/// Graphviz parity: y-position stage runs fill_rank_positions first, then
/// optional flip-cluster height correction (cluster.c path) and y rebuild.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_with_flip(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair],
  y_all_ranks : Array[Int],
) -> YPositionsWithFlipOutput {
  let mut y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions(
    rank_keys,
    groups,
    y_all_ranks,
    rank_pht,
    rank_ht1,
    rank_ht2,
    ranksep_pt,
    y_positions,
    rank_y,
  )
  if (rankdir == RankDir::LR || rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(graph) {
    let min_root_rank = if y_all_ranks.length() > 0 { y_all_ranks[0] } else { 0 }
    let adjusted =
      adjust_flip_rank_heights(
      graph,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      cluster_bbox_heights,
      min_root_rank,
      0.0,
    )
    if adjusted {
      y_positions = build_y_positions_from_groups(rank_keys, groups, rank_y)
    }
  }
  { y_positions, rank_y }
}

///|
/// Graphviz parity: y-position pre-solve in compute_positions keeps cluster bbox
/// derivation, flat-label rank-height updates, and y-sweep wiring unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_y_position_data(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> YPositionComputationData {
  let rank_pht = rank_heights.rank_pht
  let rank_ht1 = rank_heights.rank_ht1
  let rank_ht2 = rank_heights.rank_ht2
  let cluster_bbox_heights =
    if cluster_meta.has_clusters {
      compute_cluster_bbox_heights(
        graph,
        rank_data.ranks,
        prep.sizes,
        rank_data.self_edge_labels,
        prep.rankdir,
      )
    } else {
      Map::new()
    }
  apply_flat_label_heights(
    flat_label_nodes,
    ordering.vnode_info.vnode_sizes,
    rank_pht,
    rank_ht1,
    rank_ht2,
  )
  let y_all_ranks =
    build_y_all_ranks_with_flat(rank_data.rank_keys, flat_label_nodes)
  let y_position_output =
    build_y_positions_with_flip(
      graph,
      prep.rankdir,
      rank_data.rank_keys,
      rank_data.groups,
      rank_data.ranks,
      rank_pht,
      rank_ht1,
      rank_ht2,
      rank_heights.ranksep_pt,
      cluster_bbox_heights,
      y_all_ranks,
    )
  let y_positions = y_position_output.y_positions
  let rank_y = y_position_output.rank_y
  { y_positions, rank_y, cluster_bbox_heights }
}


///|
/// Graphviz parity: final output map assembly keeps intercluster alignment,
/// cluster boundary capture, vnode projection, and rounding adjustment order.
/// Do not change behavior without updating fixtures/tests.
fn build_position_output_maps(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_positions : Map[String, Double],
  y_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> PositionOutputMaps {
  let intercluster_alignment_enabled =
    match @sys.get_env_var("DOT_INTERCLUSTER_ALIGN") {
      Some(value) => {
        let lower = value.to_lower()
        lower != "0" && lower != "false" && lower != "no"
      }
      None => false
    }
  if cluster_meta.has_clusters && prep.has_dotted_edges &&
    intercluster_alignment_enabled {
    adjust_intercluster_alignment(
      prep.nodes,
      prep.edges,
      rank_data.ranks,
      x_positions,
      cluster_meta.cluster_keys,
      cluster_meta.intercluster_keys,
      rank_heights.nodesep_pt,
      prep.has_edge_labels,
    )
  }
  // Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
  let cluster_boundary_x =
    build_cluster_boundary_x(graph, cluster_meta, x_positions)
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    build_vnode_positions(
      use_vnodes_for_xpos,
      prep,
      rank_data,
      ordering,
      x_positions,
      rank_y,
    )
  let positions : Map[String, @geom.Point] = Map::new()
  for node in prep.nodes {
    let name = node.name()
    let pos_x = match x_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    let pos_y = match y_positions.get(name) {
      Some(value) => value
      None => 0.0
    }
    positions[name] = { x: pos_x, y: pos_y }
  }
  if cluster_meta.has_clusters && cluster_rounding_enabled() {
    let _ = adjust_cluster_positions(
      graph,
      positions,
      vnode_positions,
      ordering.vnode_info.vnode_clusters,
      prep.sizes,
    )
  }
  {
    positions,
    vnode_positions,
    cluster_ln_x: cluster_boundary_x.cluster_ln_x,
    cluster_rn_x: cluster_boundary_x.cluster_rn_x,
  }
}

///|
/// Graphviz parity: final projection stage in compute_positions keeps y/x solve
/// projection and result assembly sequencing identical to Graphviz-aligned flow.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  use_vnodes_for_xpos : Bool,
  x_base_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  x_cluster_keys : Map[String, String],
  flat_label_edges : Array[ConstraintEdge],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  flat_label_edge_vnodes : Map[String, String],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  let y_position_data =
    build_y_position_data(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      flat_label_nodes,
    )
  let x_positions =
    compute_layout_x_positions(
      graph,
      prep,
      rank_data,
      rank_heights,
      ordering,
      use_vnodes_for_xpos,
      x_base_sizes,
      x_groups,
      x_cluster_keys,
      flat_label_edges,
    )
  let position_output_maps =
    build_position_output_maps(
      graph,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      use_vnodes_for_xpos,
      x_positions,
      y_position_data.y_positions,
      y_position_data.rank_y,
    )
  {
    x_groups,
    rank_y: y_position_data.rank_y,
    positions: position_output_maps.positions,
    vnode_positions: position_output_maps.vnode_positions,
    cluster_ln_x: position_output_maps.cluster_ln_x,
    cluster_rn_x: position_output_maps.cluster_rn_x,
    flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
    cluster_bbox_heights: y_position_data.cluster_bbox_heights,
  }
}

///|
/// Graphviz parity: x-positioning aligned to refs/graphviz/lib/dotgen/position.c + dotgen/cluster.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> PositionResult {
  let x_data =
    build_x_with_flat_labels(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
    )
  build_projection_result(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    x_data.use_vnodes_for_xpos,
    x_data.x_base_sizes,
    x_data.x_groups,
    x_data.x_cluster_keys,
    x_data.flat_label_edges,
    x_data.flat_label_nodes,
    x_data.flat_label_edge_vnodes,
    rank_heights.rank_ht1,
    rank_heights.rank_ht2,
  )
}
