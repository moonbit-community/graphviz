///|
/// Stage D Phase D5 split: x-position solver input assembly and invocation.

///|
/// Graphviz parity: x-position solve input keeps x-stage bundle plus ordering
/// and rank context grouped for one compute_x_positions invocation.
priv struct XPositionBuildInput {
  pipeline : PositionPipelineContext
  x_data : XWithFlatLabelData
}

///|
/// Graphviz parity: x-position stage must use identical xpos input assembly,
/// and solver invocation as Graphviz-aligned pipeline order.
/// Do not change behavior without updating fixtures/tests.
fn compute_layout_x_positions(
  input : XPositionBuildInput,
) -> Map[String, Double] {
  let xpos_input =
    @positioning.build_xpos_computation_input_from_sources(
      {
        use_vnodes_for_xpos: input.x_data.use_vnodes_for_xpos,
        x_base_sizes: input.x_data.x_base_sizes,
        x_groups: input.x_data.x_groups,
        vnode_sizes: input.pipeline.ordering.vnode_info.vnode_sizes,
        vnode_creation_order: input.pipeline.ordering.vnode_creation_order,
        vnode_ranks: input.pipeline.ordering.vnode_info.vnode_ranks,
        edge_vnodes: input.pipeline.ordering.vnode_info.edge_vnodes,
      },
    )
  let x_positions = compute_x_positions(
    {
      graph: input.pipeline.graph,
      nodes: input.pipeline.prep.nodes,
      edges: input.pipeline.prep.edges,
      edge_tail: input.pipeline.rank_data.edge_tail,
      edge_head: input.pipeline.rank_data.edge_head,
      edge_out_order: input.pipeline.rank_data.edge_out_order,
      nlist_order: input.pipeline.ordering.nlist_order,
      gdnlist_order: input.pipeline.ordering.gdnlist_order,
      ranks: xpos_input.x_ranks,
      rank_keys: xpos_input.x_rank_keys,
      groups: input.x_data.x_groups,
      sizes: xpos_input.x_sizes,
      output_sizes: input.pipeline.prep.output_sizes,
      cluster_keys: input.x_data.x_cluster_keys,
      nodesep_pt: input.pipeline.rank_heights.nodesep_pt,
      has_edge_labels: input.pipeline.prep.has_edge_labels,
      extra_nodes: xpos_input.x_extra_nodes,
      flat_label_edges: input.x_data.flat_label_edges,
      edge_vnodes: xpos_input.x_edge_vnodes,
    },
  )
  x_positions
}
