///|
/// Stage D Phase D0 split: output map assembly helpers
/// for intercluster alignment, vnode projection, and final position maps.

type PositionOutputMaps = @positioning.PositionOutputMaps

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
  @positioning.build_position_output_maps_from_sources(
    {
      has_clusters: input.pipeline.cluster_meta.has_clusters,
      has_dotted_edges: input.pipeline.prep.has_dotted_edges,
      graph: input.pipeline.graph,
      nodes: input.pipeline.prep.nodes,
      edges: input.pipeline.prep.edges,
      ranks: input.pipeline.rank_data.ranks,
      x_positions: input.x_positions,
      y_positions: input.y_positions,
      rank_y: input.rank_y,
      cluster_keys: input.pipeline.cluster_meta.cluster_keys,
      intercluster_keys: input.pipeline.cluster_meta.intercluster_keys,
      nodesep_pt: input.pipeline.rank_heights.nodesep_pt,
      has_edge_labels: input.pipeline.prep.has_edge_labels,
      use_vnodes_for_xpos: input.use_vnodes_for_xpos,
      vnode_ranks: input.pipeline.ordering.vnode_info.vnode_ranks,
      edge_vnodes: input.pipeline.ordering.vnode_info.edge_vnodes,
      vnode_clusters: input.pipeline.ordering.vnode_info.vnode_clusters,
      sizes: input.pipeline.prep.sizes,
      cluster_ln_prefix: CLUSTER_LN_PREFIX,
      cluster_rn_prefix: CLUSTER_RN_PREFIX,
      collect_cluster_names_fn: collect_cluster_names,
      cluster_key_from_boundary_fn: cluster_key_from_boundary,
      adjust_intercluster_alignment_fn:
        (
          nodes,
          edges,
          ranks,
          x_positions,
          cluster_keys,
          intercluster_keys,
          nodesep_pt,
          has_edge_labels,
        ) =>
          adjust_intercluster_alignment(
            {
              nodes,
              edges,
              ranks,
              x_positions,
              cluster_keys,
              intercluster_keys,
              nodesep_pt,
              has_edge_labels,
            },
          ),
      vnode_positions_from_edges_fn: vnode_positions_from_edges,
      cluster_rounding_enabled_fn: cluster_rounding_enabled,
      adjust_cluster_positions_fn:
        (
          graph,
          positions,
          vnode_positions,
          vnode_clusters,
          sizes,
        ) =>
          adjust_cluster_positions(
            {
              graph,
              positions,
              vnode_positions,
              vnode_clusters,
              sizes,
            },
          ),
    },
  )
}
