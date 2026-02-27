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
/// Graphviz parity: position-mode gate values are derived once from prep and
/// ordering before final mode-flag output assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_gate_values_for_positions(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> PositionModeGateValues {
  let use_vnodes_for_xpos = should_use_vnodes_for_xpos_in_positions(prep, ordering)
  let allow_xpos_reorder =
    should_allow_xpos_reorder_in_positions(use_vnodes_for_xpos, ordering)
  let graphviz_flip = is_graphviz_rankdir_flip_for_positions(prep)
  { use_vnodes_for_xpos, allow_xpos_reorder, graphviz_flip }
}

///|
/// Graphviz parity: position-mode output object maps computed gate values and
/// preserves fixed xpos_reorder_enabled=false behavior.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_flags_output_for_positions(
  use_vnodes_for_xpos : Bool,
  allow_xpos_reorder : Bool,
  graphviz_flip : Bool,
) -> PositionModeFlags {
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
/// Graphviz parity: position-mode gates (vnode usage / reorder allowance /
/// rankdir flip) are computed once from prep+ordering and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_mode_flags(
  prep : LayoutPrep,
  ordering : OrderingResult,
) -> PositionModeFlags {
  let mode_gate_values =
    build_position_mode_gate_values_for_positions(prep, ordering)
  build_position_mode_flags_output_for_positions(
    mode_gate_values.use_vnodes_for_xpos,
    mode_gate_values.allow_xpos_reorder,
    mode_gate_values.graphviz_flip,
  )
}

///|
/// Graphviz parity: x-stage mode/slack output object maps gate flags and
/// synthesized virtual-slack edges without extra normalization.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_virtual_slack_output_for_positions(
  mode_flags : PositionModeFlags,
  virtual_slack_edges : Array[ConstraintEdge],
) -> XStageModeAndSlackData {
  {
    use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
    allow_xpos_reorder: mode_flags.allow_xpos_reorder,
    graphviz_flip: mode_flags.graphviz_flip,
    xpos_reorder_enabled: mode_flags.xpos_reorder_enabled,
    virtual_slack_edges,
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
  build_x_stage_mode_and_virtual_slack_output_for_positions(
    mode_flags,
    virtual_slack_edges,
  )
}

///|
/// Graphviz parity: x-stage seed+flat-label output object maps seed base sizes
/// with flat-label augmentation data without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_seed_and_flat_label_output_for_positions(
  x_stage_seed : XPositionStageSeedData,
  flat_label_augmentation : XposFlatLabelAugmentation,
) -> XStageSeedAndFlatLabelData {
  let x_base_sizes = x_stage_seed.x_base_sizes
  { x_base_sizes, flat_label_augmentation }
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
  build_x_stage_seed_and_flat_label_output_for_positions(
    x_stage_seed,
    flat_label_augmentation,
  )
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
/// Graphviz parity: x-stage mode/seed output object maps stage-local data
/// bundles without additional transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_seed_output_for_positions(
  mode_slack_data : XStageModeAndSlackData,
  seed_flat_label_data : XStageSeedAndFlatLabelData,
) -> XStageModeAndSeedData {
  { mode_slack_data, seed_flat_label_data }
}

///|
/// Graphviz parity: x-stage mode/slack and seed/flat-label stages are executed
/// in fixed order before final x-stage output assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_x_stage_mode_and_seed_data_for_positions(
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
) -> XStageModeAndSeedData {
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
  build_x_stage_mode_and_seed_output_for_positions(
    mode_slack_data,
    seed_flat_label_data,
  )
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
  let x_stage_mode_and_seed_data =
    build_x_stage_mode_and_seed_data_for_positions(
      prep,
      rank_data,
      rank_heights,
      cluster_meta,
      ordering,
    )
  build_x_stage_output_from_mode_and_seed_data_for_positions(
    x_stage_mode_and_seed_data.mode_slack_data,
    x_stage_mode_and_seed_data.seed_flat_label_data,
  )
}


///|
/// Graphviz parity: x-stage to projection handoff copies each computed field
/// unchanged before projection call wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_from_x_stage_data_for_positions(
  x_stage_data : XStageWithFlatLabelData,
) -> ProjectionFromXStageData {
  {
    use_vnodes_for_xpos: x_stage_data.use_vnodes_for_xpos,
    x_base_sizes: x_stage_data.x_base_sizes,
    x_groups: x_stage_data.x_groups,
    x_cluster_keys: x_stage_data.x_cluster_keys,
    virtual_slack_edges: x_stage_data.virtual_slack_edges,
    flat_label_edges: x_stage_data.flat_label_edges,
    flat_label_nodes: x_stage_data.flat_label_nodes,
    flat_label_edge_vnodes: x_stage_data.flat_label_edge_vnodes,
  }
}

///|
/// Graphviz parity: projection stage call consumes x-stage handoff fields and
/// rank-height maps directly, without extra remapping.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_from_handoff_with_rank_maps_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  projection_from_x_stage_data : ProjectionFromXStageData,
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  build_projection_result_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    projection_from_x_stage_data.use_vnodes_for_xpos,
    projection_from_x_stage_data.x_base_sizes,
    projection_from_x_stage_data.x_groups,
    projection_from_x_stage_data.x_cluster_keys,
    projection_from_x_stage_data.virtual_slack_edges,
    projection_from_x_stage_data.flat_label_edges,
    projection_from_x_stage_data.flat_label_nodes,
    projection_from_x_stage_data.flat_label_edge_vnodes,
    rank_ht1,
    rank_ht2,
  )
}

///|
/// Graphviz parity: projection handoff consumes x-stage bundle fields and rank
/// height maps without changing Graphviz-aligned parameter wiring.
/// Do not change behavior without updating fixtures/tests.
fn build_projection_result_from_x_stage_data_with_rank_maps_for_positions(
  graph : @cgraph.Graph,
  prep : LayoutPrep,
  rank_data : RankData,
  rank_heights : RankHeights,
  cluster_meta : ClusterMetadata,
  ordering : OrderingResult,
  x_stage_data : XStageWithFlatLabelData,
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> PositionResult {
  let projection_from_x_stage_data =
    build_projection_from_x_stage_data_for_positions(x_stage_data)
  build_projection_result_from_handoff_with_rank_maps_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    projection_from_x_stage_data,
    rank_ht1,
    rank_ht2,
  )
}

///|
/// Graphviz parity: projection handoff rank-height maps are sourced directly
/// from rank_heights and forwarded unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_position_rank_height_maps_for_projection_for_positions(
  rank_heights : RankHeights,
) -> PositionRankHeightMaps {
  { rank_ht1: rank_heights.rank_ht1, rank_ht2: rank_heights.rank_ht2 }
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
  let projection_rank_height_maps =
    build_position_rank_height_maps_for_projection_for_positions(rank_heights)
  build_projection_result_from_x_stage_data_with_rank_maps_for_positions(
    graph,
    prep,
    rank_data,
    rank_heights,
    cluster_meta,
    ordering,
    x_stage_data,
    projection_rank_height_maps.rank_ht1,
    projection_rank_height_maps.rank_ht2,
  )
}
