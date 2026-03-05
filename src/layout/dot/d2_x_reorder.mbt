///|
/// Stage D Phase D2 split: x-stage reorder pipeline wiring helpers.

///|
/// Graphviz parity: x-stage flat-label augmentation input keeps reorder flags,
/// stage contexts, and seed snapshots grouped for one reorder+augmentation
/// pass.
priv struct XFlatLabelBuildInput {
  xpos_reorder_enabled : Bool
  use_vnodes_for_xpos : Bool
  allow_xpos_reorder : Bool
  graphviz_flip : Bool
  pipeline : PositionPipelineContext
  x_seed : XPositionSeedData
}

///|
/// Graphviz parity: x-stage reorder pipeline input maps x-seed snapshots plus
/// shared stage context to the positioning subpackage in one explicit boundary.
/// Do not change behavior without updating fixtures/tests.
fn build_xpos_reorder_pipeline_input(
  input : XFlatLabelBuildInput,
) -> @positioning.XposReorderPipelineInput {
  let pipeline = input.pipeline
  @positioning.build_xpos_reorder_pipeline_input(
    input.xpos_reorder_enabled,
    input.use_vnodes_for_xpos,
    input.allow_xpos_reorder,
    input.x_seed.has_vnode_order,
    pipeline.cluster_meta.ordering_set,
    pipeline.cluster_meta.has_clusters,
    input.x_seed.x_groups,
    input.x_seed.x_order_sizes,
    input.x_seed.x_cluster_keys,
    pipeline.cluster_meta.cluster_min_rank,
    pipeline.cluster_meta.cluster_max_rank,
    pipeline.prep.node_order,
    CLUSTER_SKELETON_PREFIX,
    vnode_size_from_widths(1.0, 1.0),
    pipeline.prep.edges,
    pipeline.rank_data.edge_tail,
    pipeline.rank_data.edge_head,
    pipeline.rank_data.ranks,
    pipeline.ordering.vnode_info.edge_vnodes,
    pipeline.ordering.vnode_info.vnode_ranks,
    input.x_seed.x_edge_tail_port_x,
    input.x_seed.x_edge_head_port_x,
    input.x_seed.x_edge_tail_port_order,
    input.x_seed.x_edge_head_port_order,
    CL_CROSS,
    pipeline.cluster_meta.rank_same_groups,
    pipeline.cluster_meta.rank_same_order,
    pipeline.rank_heights.nodesep_pt,
    pipeline.prep.has_edge_labels,
    pipeline.cluster_meta.flat_constraints,
    input.graphviz_flip,
    pipeline.prep.nodes,
    pipeline.ordering.order_edges,
    pipeline.ordering.order_edge_tail,
    pipeline.ordering.order_edge_head,
    pipeline.ordering.edge_order,
    pipeline.prep.port_order_positions,
    pipeline.prep.port_order_contrib,
    pipeline.cluster_meta.cluster_skeleton,
    4,
  )
}

///|
/// Graphviz parity: non-cluster xpos reorder uses edge-port x-position samples
/// derived from compass/record port geometry before reorder scoring.
/// Do not change behavior without updating fixtures/tests.
fn compute_xpos_reorder_port_positions(
  input : @positioning.XposPortSampleInput,
) -> (Array[Double], Array[Double]) {
  let samples =
    compute_edge_port_positions(
      input.nodes,
      input.order_edges,
      input.order_edge_tail,
      input.order_edge_head,
      input.x_order_sizes,
    )
  (samples.tail_values, samples.head_values)
}

///|
/// Graphviz parity: non-cluster xpos reorder uses edge-port order fractions to
/// break mincross scoring ties consistently with Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn compute_xpos_reorder_port_orders(
  input : @positioning.XposPortSampleInput,
) -> (Array[Double], Array[Double]) {
  let samples =
    compute_edge_port_orders(
      input.nodes,
      input.order_edges,
      input.order_edge_tail,
      input.order_edge_head,
      input.x_order_sizes,
    )
  (samples.tail_values, samples.head_values)
}

///|
/// Graphviz parity: x-stage reorder and transpose-cleanup are applied in
/// fixed order before flat-label augmentation consumes updated x_groups.
/// Do not change behavior without updating fixtures/tests.
fn build_x_groups_after_reorder(
  input : XFlatLabelBuildInput,
) -> Map[Int, Array[String]] {
  @positioning.build_x_groups_after_reorder(
    build_xpos_reorder_pipeline_input(input),
    compute_xpos_reorder_port_positions,
    compute_xpos_reorder_port_orders,
  )
}
