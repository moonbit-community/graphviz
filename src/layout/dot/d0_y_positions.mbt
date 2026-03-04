///|
/// Stage D Phase D0 split: y-position stage helpers
/// for rank-height adjustments and y-coordinate solve wiring.

///|
priv struct YPositionComputationData {
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
}

///|
/// Graphviz parity: y-position pre-solve input keeps rank metadata, cluster
/// gates, and flat-label adjustments grouped before y sweep.
priv struct YPositionBuildInput {
  pipeline : PositionPipelineContext
  flat_label_nodes : Map[String, FlatLabelNodeInfo]
}

///|
/// Graphviz parity: y-position pre-solve in compute_positions keeps cluster bbox
/// derivation, flat-label rank-height updates, and y-sweep wiring unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_y_position_data(
  input : YPositionBuildInput,
) -> YPositionComputationData {
  let rank_pht = input.pipeline.rank_heights.rank_pht
  let rank_ht1 = input.pipeline.rank_heights.rank_ht1
  let rank_ht2 = input.pipeline.rank_heights.rank_ht2
  let cluster_bbox_heights =
    if input.pipeline.cluster_meta.has_clusters {
      compute_cluster_bbox_heights(
        input.pipeline.graph,
        input.pipeline.rank_data.ranks,
        input.pipeline.prep.sizes,
        input.pipeline.rank_data.self_edge_labels,
        input.pipeline.prep.rankdir,
      )
    } else {
      Map::new()
    }
  apply_flat_label_heights(
    input.flat_label_nodes,
    input.pipeline.ordering.vnode_info.vnode_sizes,
    rank_pht,
    rank_ht1,
    rank_ht2,
  )
  let y_all_ranks =
    build_y_all_ranks_with_flat(input.pipeline.rank_data.rank_keys, input.flat_label_nodes)
  let y_position_output =
    build_y_positions_with_flip(
      {
        graph: input.pipeline.graph,
        rankdir: input.pipeline.prep.rankdir,
        rank_keys: input.pipeline.rank_data.rank_keys,
        groups: input.pipeline.rank_data.groups,
        ranks: input.pipeline.rank_data.ranks,
        rank_pht,
        rank_ht1,
        rank_ht2,
        ranksep_pt: input.pipeline.rank_heights.ranksep_pt,
        cluster_bbox_heights,
        y_all_ranks,
      },
    )
  let y_positions = y_position_output.y_positions
  let rank_y = y_position_output.rank_y
  { y_positions, rank_y, cluster_bbox_heights }
}
