///|
/// Stage D Phase D1/D5 split: mode-gating and projection
/// handoff helpers for the x-stage/y-projection pipeline.

///|
/// Graphviz parity: vnode xpos mode gate follows Graphviz edge-label/port-edge
/// requirements with vnode-count fallback threshold.
/// Do not change behavior without updating fixtures/tests.
fn should_use_vnodes_for_xpos_in_positions(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> Bool {
  prep.has_edge_labels || prep.has_port_edges || ordering.vnode_count <= MAX_XPOS_VNODES
}

///|
/// Graphviz parity: xpos reorder allowance follows Graphviz vnode-count gating
/// once vnode usage mode is decided.
/// Do not change behavior without updating fixtures/tests.
fn should_allow_xpos_reorder_in_positions(
  use_vnodes_for_xpos : Bool,
  ordering : OrderingResult,
) -> Bool {
  !use_vnodes_for_xpos || ordering.vnode_count <= MAX_XPOS_REORDER_VNODES
}

///|
/// Graphviz parity: rankdir flip gate for xpos follows Graphviz LR/RL handling.
/// Do not change behavior without updating fixtures/tests.
fn is_graphviz_rankdir_flip_for_positions(prep : LayoutPrep) -> Bool {
  prep.rankdir == RankDir::LR || prep.rankdir == RankDir::RL
}


///|
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once from prep+ordering and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_flags(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> PositionModeFlags {
  let use_vnodes_for_xpos = should_use_vnodes_for_xpos_in_positions(prep, ordering)
  let allow_xpos_reorder =
    should_allow_xpos_reorder_in_positions(use_vnodes_for_xpos, ordering)
  let graphviz_flip = is_graphviz_rankdir_flip_for_positions(prep)
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
/// Graphviz parity: virtual-slack synthesis consumes mode flags after vnode
/// trace emission and preserves vnode-xpos gating semantics.
/// Do not change behavior without updating fixtures/tests.
fn build_virtual_slack_edges_from_mode_flags_for_positions(
  mode_flags : PositionModeFlags,
  prep : LayoutPrep,
  rank_data : RankData,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> Array[ConstraintEdge] {
  dot_trace("layout_dot: vnodes built count=\{ordering.vnode_count}")
  build_virtual_slack_edges_for_positions(
    mode_flags.use_vnodes_for_xpos,
    prep,
    rank_data,
    ordering,
    cluster_meta,
  )
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
  let virtual_slack_edges =
    build_virtual_slack_edges_from_mode_flags_for_positions(
      mode_flags,
      prep,
      rank_data,
      cluster_meta,
      ordering,
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
/// Graphviz parity: x-stage final bundle preserves mode/slack and flat-label
/// augmentation field mapping without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_output_from_mode_and_seed_data_for_positions(
  mode_slack_data : XStageModeAndSlackData,
  seed_flat_label_data : XStageSeedAndFlatLabelData,
) -> XStageWithFlatLabelData {
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
  build_x_stage_output_from_mode_and_seed_data_for_positions(
    mode_slack_data,
    seed_flat_label_data,
  )
}


///|
/// Graphviz parity: projection handoff from x-stage bundle keeps field-to-parameter
/// wiring and rank-height map sourcing unchanged before final projection stage.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_from_x_stage_data_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_stage_data : XStageWithFlatLabelData,
) -> PositionResult {
  build_projection_result_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    x_stage_data.use_vnodes_for_xpos,
    x_stage_data.x_base_sizes,
    x_stage_data.x_groups,
    x_stage_data.x_cluster_keys,
    x_stage_data.virtual_slack_edges,
    x_stage_data.flat_label_edges,
    x_stage_data.flat_label_nodes,
    x_stage_data.flat_label_edge_vnodes,
    rank_heights.rank_ht1,
    rank_heights.rank_ht2,
  )
}
