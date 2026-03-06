///|
/// Stage D y-rank placement and flip-adjustment helpers.

///|
/// Stage D x-position solver input assembly and invocation.

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
  let solve_input =
    @positioning.build_x_position_solve_input(
      {
        use_vnodes_for_xpos: input.x_data.use_vnodes_for_xpos,
        x_base_sizes: input.x_data.x_base_sizes,
        x_groups: input.x_data.x_groups,
        vnode_sizes: input.pipeline.ordering.vnode_info.vnode_sizes,
        vnode_creation_order: input.pipeline.ordering.vnode_creation_order,
        vnode_ranks: input.pipeline.ordering.vnode_info.vnode_ranks,
        edge_vnodes: input.pipeline.ordering.vnode_info.edge_vnodes,
        graph: input.pipeline.graph,
        nodes: input.pipeline.prep.nodes,
        edges: input.pipeline.prep.edges,
        edge_tail: input.pipeline.rank_data.edge_tail,
        edge_head: input.pipeline.rank_data.edge_head,
        edge_out_order: input.pipeline.rank_data.edge_out_order,
        nlist_order: input.pipeline.ordering.nlist_order,
        gdnlist_order: input.pipeline.ordering.gdnlist_order,
        cluster_keys: input.x_data.x_cluster_keys,
        nodesep_pt: input.pipeline.rank_heights.nodesep_pt,
        has_edge_labels: input.pipeline.prep.has_edge_labels,
        output_sizes: input.pipeline.prep.output_sizes,
        flat_label_edges: input.x_data.flat_label_edges,
      },
    )
  compute_x_positions(solve_input)
}

///|
/// Stage D y-position stage helpers for rank-height adjustments and y-coordinate
/// solve wiring.

///|
type YPositionComputationData = @positioning.YPositionPipelineOutput

///|
/// Graphviz parity: y-position pre-solve input keeps rank metadata, cluster
/// gates, and flat-label adjustments grouped before y sweep.
priv struct YPositionBuildInput {
  pipeline : PositionPipelineContext
  flat_label_ranks : Map[String, Int]
}

///|
/// Graphviz parity: y-position pre-solve in compute_positions keeps cluster bbox
/// derivation, flat-label rank-height updates, and y-sweep wiring unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_y_position_data(
  input : YPositionBuildInput,
) -> YPositionComputationData {
  @positioning.build_y_position_pipeline(
    {
      has_clusters: input.pipeline.cluster_meta.has_clusters,
      graph: input.pipeline.graph,
      rankdir: input.pipeline.prep.rankdir,
      rank_keys: input.pipeline.rank_data.rank_keys,
      groups: input.pipeline.rank_data.groups,
      ranks: input.pipeline.rank_data.ranks,
      sizes: input.pipeline.prep.sizes,
      self_edge_labels: input.pipeline.rank_data.self_edge_labels,
      rank_pht: input.pipeline.rank_heights.rank_pht,
      rank_ht1: input.pipeline.rank_heights.rank_ht1,
      rank_ht2: input.pipeline.rank_heights.rank_ht2,
      ranksep_pt: input.pipeline.rank_heights.ranksep_pt,
      flat_label_ranks: input.flat_label_ranks,
      vnode_sizes: input.pipeline.ordering.vnode_info.vnode_sizes,
      cluster_margin_pt_for: @positioning.cluster_margin_pt,
      cluster_label_padding_for: cluster_label_padding_for_layout,
      node_half_height_pt_for: node_half_height_pt,
      cluster_label_width_pt_for: cluster_label_width_with_pad_for_layout,
    },
  )
}

///|
/// Stage D output map assembly helpers for intercluster alignment, vnode
/// projection, and final position maps.

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
  @positioning.build_position_output_pipeline(
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
      cluster_rounding_enabled: cluster_rounding_enabled(),
      vnode_clusters: input.pipeline.ordering.vnode_info.vnode_clusters,
      sizes: input.pipeline.prep.sizes,
      cluster_margin_pt_for: @positioning.cluster_margin_pt,
      expand_cluster_label_bbox:
        (graph, bbox) =>
          match graph_label_metrics(graph) {
            Some(metrics) =>
              expand_bbox_for_label(
                bbox,
                metrics.width_pt,
                metrics.height_pt,
                graph_label_loc(graph),
              )
            None => bbox
          },
    },
  )
}

///|
fn cluster_rounding_enabled() -> Bool {
  @dot_shared.env_flag_enabled_nonempty(
    @sys.get_env_var("DOT_ADJUST_CLUSTER_ROUNDING"),
  )
}
