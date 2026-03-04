///|
/// Stage D Phase D0 split: output map assembly helpers
/// for intercluster alignment, vnode projection, and final position maps.

///|
priv struct PositionOutputMaps {
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  cluster_ln_x : Map[String, Double]
  cluster_rn_x : Map[String, Double]
}

///|
/// Graphviz parity: final output map assembly input keeps cluster/rank/xpos
/// snapshots grouped so intercluster alignment, boundary capture, vnode
/// projection, and rounding run in Graphviz-equivalent order.
priv struct PositionOutputBuildInput {
  pipeline : PositionPipelineContext
  use_vnodes_for_xpos : Bool
  x_positions : Map[String, Double]
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
}

///|
/// Graphviz parity: final output map assembly keeps intercluster alignment,
/// cluster boundary capture, vnode projection, and rounding adjustment order.
/// Do not change behavior without updating fixtures/tests.
fn build_position_output_maps(
  input : PositionOutputBuildInput,
) -> PositionOutputMaps {
  if input.pipeline.cluster_meta.has_clusters && input.pipeline.prep.has_dotted_edges &&
    intercluster_alignment_enabled() {
    adjust_intercluster_alignment(
      input.pipeline.prep.nodes,
      input.pipeline.prep.edges,
      input.pipeline.rank_data.ranks,
      input.x_positions,
      input.pipeline.cluster_meta.cluster_keys,
      input.pipeline.cluster_meta.intercluster_keys,
      input.pipeline.rank_heights.nodesep_pt,
      input.pipeline.prep.has_edge_labels,
    )
  }
  // Graphviz parity: cluster x bounds are derived from ln/rn constraint nodes.
  let cluster_boundary_x =
    build_cluster_boundary_x(
      input.pipeline.graph,
      input.pipeline.cluster_meta,
      input.x_positions,
    )
  // Let the final bounding-box translation handle normalization, matching Graphviz.
  let vnode_positions =
    build_vnode_positions(
      {
        pipeline: input.pipeline,
        use_vnodes_for_xpos: input.use_vnodes_for_xpos,
        x_positions: input.x_positions,
        rank_y: input.rank_y,
      },
    )
  let positions =
    build_node_positions_map(
      input.pipeline.prep.nodes,
      input.x_positions,
      input.y_positions,
    )
  if input.pipeline.cluster_meta.has_clusters && cluster_rounding_enabled() {
    let _ = adjust_cluster_positions(
      input.pipeline.graph,
      positions,
      vnode_positions,
      input.pipeline.ordering.vnode_info.vnode_clusters,
      input.pipeline.prep.sizes,
    )
  }
  {
    positions,
    vnode_positions,
    cluster_ln_x: cluster_boundary_x.cluster_ln_x,
    cluster_rn_x: cluster_boundary_x.cluster_rn_x,
  }
}
