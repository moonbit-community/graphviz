///|
/// Stage D Phase D0 split: x-position stage helpers
/// for mode gating, reorder preparation, flat-label augmentation, and xpos solve.

///|
priv struct XposComputationInput {
  x_sizes : Map[String, NodeSize]
  x_rank_keys : Array[Int]
  x_ranks : Map[String, Int]
  x_extra_nodes : Array[@ordering.ExtraConstraintNode]
  x_edge_vnodes : Map[String, Array[String]]
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
/// Graphviz parity: x-position solve input keeps x-stage bundle plus ordering
/// and rank context grouped for one compute_x_positions invocation.
priv struct XPositionBuildInput {
  pipeline : PositionPipelineContext
  x_data : XWithFlatLabelData
}

///|
priv struct PositionModeFlags {
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
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
  pipeline : PositionPipelineContext,
) -> XWithFlatLabelData {
  let mode_flags = build_position_mode_flags(pipeline.prep, pipeline.ordering)
  let x_seed =
    build_x_seed_data(
      {
        use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
        pipeline,
      },
    )
  let flat_label_augmentation =
    build_x_flat_labels(
      {
        xpos_reorder_enabled: false,
        use_vnodes_for_xpos: mode_flags.use_vnodes_for_xpos,
        allow_xpos_reorder: mode_flags.allow_xpos_reorder,
        graphviz_flip: mode_flags.graphviz_flip,
        pipeline,
        x_seed,
      },
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
/// Graphviz parity: xpos solver inputs must preserve vnode-size merge,
/// rank-map/key derivation, and vnode-edge/slack toggles.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_computation_input(
  input : XPositionBuildInput,
) -> XposComputationInput {
  let x_sizes =
    if input.x_data.use_vnodes_for_xpos {
      @ordering.merge_sizes_with_vnodes(
        input.x_data.x_base_sizes,
        input.pipeline.ordering.vnode_info.vnode_sizes,
      )
    } else {
      input.x_data.x_base_sizes
    }
  let x_rank_keys = @ordering.collect_rank_keys(input.x_data.x_groups)
  let x_ranks = @ordering.build_node_ranks(input.x_data.x_groups)
  let vnode_extra_nodes =
    if input.x_data.use_vnodes_for_xpos {
      @ordering.build_vnode_extra_nodes(
        input.pipeline.ordering.vnode_creation_order,
        input.pipeline.ordering.vnode_info.vnode_ranks,
      )
    } else {
      []
    }
  let x_extra_nodes = vnode_extra_nodes.copy()
  let x_edge_vnodes =
    if input.x_data.use_vnodes_for_xpos {
      input.pipeline.ordering.vnode_info.edge_vnodes
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
  input : XPositionBuildInput,
) -> Map[String, Double] {
  let xpos_input = build_xpos_computation_input(input)
  let x_positions = compute_x_positions(
    input.pipeline.graph,
    input.pipeline.prep.nodes,
    input.pipeline.prep.edges,
    input.pipeline.rank_data.edge_tail,
    input.pipeline.rank_data.edge_head,
    input.pipeline.rank_data.edge_out_order,
    input.pipeline.ordering.nlist_order,
    input.pipeline.ordering.gdnlist_order,
    xpos_input.x_ranks,
    xpos_input.x_rank_keys,
    input.x_data.x_groups,
    xpos_input.x_sizes,
    input.pipeline.prep.output_sizes,
    input.x_data.x_cluster_keys,
    input.pipeline.rank_heights.nodesep_pt,
    input.pipeline.prep.has_edge_labels,
    xpos_input.x_extra_nodes,
    input.x_data.flat_label_edges,
    xpos_input.x_edge_vnodes,
  )
  x_positions
}
