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
  @positioning.build_xpos_reorder_pipeline_input_from_sources(
    {
      xpos_reorder_enabled: input.xpos_reorder_enabled,
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      allow_xpos_reorder: input.allow_xpos_reorder,
      has_vnode_order: input.x_seed.has_vnode_order,
      ordering_set: pipeline.cluster_meta.ordering_set,
      has_clusters: pipeline.cluster_meta.has_clusters,
      x_groups: input.x_seed.x_groups,
      x_order_sizes: input.x_seed.x_order_sizes,
      x_cluster_keys: input.x_seed.x_cluster_keys,
      cluster_min_rank: pipeline.cluster_meta.cluster_min_rank,
      cluster_max_rank: pipeline.cluster_meta.cluster_max_rank,
      node_order: pipeline.prep.node_order,
      cluster_skeleton_prefix: CLUSTER_SKELETON_PREFIX,
      cluster_skeleton_size: vnode_size_from_widths(1.0, 1.0),
      edges: pipeline.prep.edges,
      edge_tail: pipeline.rank_data.edge_tail,
      edge_head: pipeline.rank_data.edge_head,
      ranks: pipeline.rank_data.ranks,
      edge_vnodes: pipeline.ordering.vnode_info.edge_vnodes,
      vnode_ranks: pipeline.ordering.vnode_info.vnode_ranks,
      edge_tail_port_x: input.x_seed.x_edge_tail_port_x,
      edge_head_port_x: input.x_seed.x_edge_head_port_x,
      edge_tail_port_order: input.x_seed.x_edge_tail_port_order,
      edge_head_port_order: input.x_seed.x_edge_head_port_order,
      cluster_skeleton_penalty: CL_CROSS,
      rank_same_groups: pipeline.cluster_meta.rank_same_groups,
      rank_same_order: pipeline.cluster_meta.rank_same_order,
      nodesep_pt: pipeline.rank_heights.nodesep_pt,
      has_edge_labels: pipeline.prep.has_edge_labels,
      flat_constraints: pipeline.cluster_meta.flat_constraints,
      graphviz_flip: input.graphviz_flip,
      nodes: pipeline.prep.nodes,
      order_edges: pipeline.ordering.order_edges,
      order_edge_tail: pipeline.ordering.order_edge_tail,
      order_edge_head: pipeline.ordering.order_edge_head,
      edge_order: pipeline.ordering.edge_order,
      port_order_positions: pipeline.prep.port_order_positions,
      port_order_contrib: pipeline.prep.port_order_contrib,
      cluster_skeleton: pipeline.cluster_meta.cluster_skeleton,
      transpose_max_passes: 4,
    },
  )
}
