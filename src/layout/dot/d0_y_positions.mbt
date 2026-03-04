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
/// Graphviz parity: y-position stage runs fill_rank_positions first, then
/// optional flip-cluster height correction (cluster.c path) and y rebuild.
/// Do not change behavior without updating fixtures/tests.
priv struct YPositionsWithFlipOutput {
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
}

///|
/// Graphviz parity: y-position flip solve input keeps rank maps, rank spacing,
/// cluster heights, and traversal bounds grouped for one fill+adjust pass.
priv struct YPositionsWithFlipInput {
  graph : @cgraph.Graph
  rankdir : RankDir
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  ranks : Map[String, Int]
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  ranksep_pt : Double
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair]
  y_all_ranks : Array[Int]
}

///|
/// Graphviz parity: flat-edge label vnodes can raise per-rank half-heights,
/// and these maxima must feed y-rank placement exactly as in Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn update_rank_height_max(
  rank_heights : Map[Int, Double],
  rank : Int,
  candidate : Double,
) -> Unit {
  let current = rank_heights.get(rank).unwrap_or_default()
  if candidate > current {
    rank_heights[rank] = candidate
  }
}

///|
/// Graphviz parity: flat-edge label vnodes can raise per-rank half-heights,
/// and these maxima must feed y-rank placement exactly as in Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn apply_flat_label_heights(
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  vnode_sizes : Map[String, NodeSize],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Unit {
  if flat_label_nodes.length() > 0 {
    for name, info in flat_label_nodes {
      let size = match vnode_sizes.get(name) {
        Some(value) => value
        None => continue
      }
      let half_height = size.height_pt / 2.0
      let rank = info.rank
      update_rank_height_max(rank_pht, rank, half_height)
      update_rank_height_max(rank_ht1, rank, half_height)
      update_rank_height_max(rank_ht2, rank, half_height)
    }
  }
}

///|
/// Graphviz parity: y-rank sweep range expands to include inserted flat-label
/// vnode ranks, while preserving continuous rank iteration.
/// Do not change behavior without updating fixtures/tests.
fn build_y_all_ranks_with_flat(
  rank_keys : Array[Int],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> Array[Int] {
  let y_all_ranks : Array[Int] = []
  if rank_keys.length() > 0 {
    let mut min_rank = rank_keys[0]
    let mut max_rank = rank_keys[rank_keys.length() - 1]
    if flat_label_nodes.length() > 0 {
      for _name, info in flat_label_nodes {
        if info.rank < min_rank {
          min_rank = info.rank
        }
        if info.rank > max_rank {
          max_rank = info.rank
        }
      }
    }
    for rank in min_rank..=max_rank {
      y_all_ranks.push(rank)
    }
  }
  y_all_ranks
}

///|
/// Graphviz parity: when flipped cluster-rank heights adjust rank_y, node y
/// coordinates are rebuilt from rank order/groups without extra transforms.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_from_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
) -> Map[String, Double] {
  let y_positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let pos_y = rank_y.get(rank).unwrap_or_default()
    let names = groups.get(rank).unwrap_or_default()
    for name in names {
      y_positions[name] = pos_y
    }
  }
  y_positions
}

///|
/// Graphviz parity: y-position stage runs fill_rank_positions first, then
/// optional flip-cluster height correction (cluster.c path) and y rebuild.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_with_flip(
  input : YPositionsWithFlipInput,
) -> YPositionsWithFlipOutput {
  let mut y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions(
    input.rank_keys,
    input.groups,
    input.y_all_ranks,
    input.rank_pht,
    input.rank_ht1,
    input.rank_ht2,
    input.ranksep_pt,
    y_positions,
    rank_y,
  )
  if (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
    @dot_shared.graph_has_cluster(input.graph) {
    let min_root_rank =
      if input.y_all_ranks.length() > 0 { input.y_all_ranks[0] } else { 0 }
    let adjusted =
      adjust_flip_rank_heights(
      input.graph,
      input.ranks,
      rank_y,
      input.rank_ht1,
      input.rank_ht2,
      input.cluster_bbox_heights,
      min_root_rank,
      0.0,
    )
    if adjusted {
      y_positions =
        build_y_positions_from_groups(input.rank_keys, input.groups, rank_y)
    }
  }
  { y_positions, rank_y }
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
