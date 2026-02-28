///|
/// Stage D Phase D1/D5 split: mode-gating and projection
/// handoff helpers for the x-stage/y-projection pipeline.

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
  // Graphviz parity: xpos constraints must preserve mincross ordering; do not reorder here.
  let xpos_reorder_enabled = false
  {
    use_vnodes_for_xpos,
    allow_xpos_reorder,
    graphviz_flip,
    xpos_reorder_enabled,
  }
}


///|
/// Graphviz parity: x-stage mode/virtual-slack setup keeps gate derivation,
/// vnode trace emission, and virtual-slack synthesis ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_virtual_slack_data_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XStageModeAndSlackData {
  let mode_flags = build_position_mode_flags(prep, ordering)
  dot_trace("layout_dot: vnodes built count=\{ordering.vnode_count}")
  let virtual_slack_edges =
    build_virtual_slack_edges_for_positions(
      mode_flags.use_vnodes_for_xpos,
      prep,
      rank_data,
      ordering,
      cluster_meta,
    )
  {
    use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
    allow_xpos_reorder: mode_flags.allow_xpos_reorder,
    graphviz_flip: mode_flags.graphviz_flip,
    xpos_reorder_enabled: mode_flags.xpos_reorder_enabled,
    virtual_slack_edges,
  }
}

///|
/// Graphviz parity: x-stage seed build and flat-label augmentation preserve the
/// same mode-gated reorder/transpose inputs and call order as Graphviz fixtures.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_seed_and_flat_label_data_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  mode_slack_data : XStageModeAndSlackData,
) -> XStageSeedAndFlatLabelData {
  let x_stage_seed =
    build_x_position_stage_seed_data_for_positions(
      mode_slack_data.use_vnodes_for_xpos,
      prep,
      rank_data,
      cluster_meta,
      ordering,
    )
  let flat_label_augmentation =
    build_x_stage_with_flat_label_augmentation_for_positions(
      mode_slack_data.xpos_reorder_enabled,
      mode_slack_data.use_vnodes_for_xpos,
      mode_slack_data.allow_xpos_reorder,
      mode_slack_data.graphviz_flip,
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      x_stage_seed,
    )
  let x_base_sizes = x_stage_seed.x_base_sizes
  { x_base_sizes, flat_label_augmentation }
}

///|
/// Graphviz parity: x-stage precompute in compute_positions keeps mode flags,
/// virtual-slack generation, reorder/transpose, and flat-label augmentation in
/// Graphviz-aligned order and wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_with_flat_labels_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XStageWithFlatLabelData {
  let mode_slack_data =
    build_x_stage_mode_and_virtual_slack_data_for_positions(
      prep,
      rank_data,
      cluster_meta,
      ordering,
    )
  let seed_flat_label_data =
    build_x_stage_seed_and_flat_label_data_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
      mode_slack_data,
    )
  let flat_label_augmentation = seed_flat_label_data.flat_label_augmentation
  {
    use_vnodes_for_xpos: mode_slack_data.use_vnodes_for_xpos,
    virtual_slack_edges: mode_slack_data.virtual_slack_edges,
    x_base_sizes: seed_flat_label_data.x_base_sizes,
    x_groups: flat_label_augmentation.x_groups,
    x_cluster_keys: flat_label_augmentation.x_cluster_keys,
    flat_label_edges: flat_label_augmentation.flat_label_edges,
    flat_label_nodes: flat_label_augmentation.flat_label_nodes,
    flat_label_edge_vnodes: flat_label_augmentation.flat_label_edge_vnodes,
  }
}
