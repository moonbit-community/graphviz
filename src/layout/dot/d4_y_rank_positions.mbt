///|
/// Stage D Phase D4 split: y-rank placement and flip-adjustment helpers.

type YPositionsWithFlipOutput = @positioning.YPositionsWithFlipOutput

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
fn apply_flat_label_heights(
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  vnode_sizes : Map[String, NodeSize],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Unit {
  let half_heights_by_rank : Map[Int, Double] = Map::new()
  for name, info in flat_label_nodes {
    let size = match vnode_sizes.get(name) {
      Some(value) => value
      None => continue
    }
    let half_height = size.height_pt / 2.0
    let rank = info.rank
    let current = half_heights_by_rank.get(rank).unwrap_or_default()
    if half_height > current {
      half_heights_by_rank[rank] = half_height
    }
  }
  @positioning.apply_rank_half_heights(
    half_heights_by_rank,
    rank_pht,
    rank_ht1,
    rank_ht2,
  )
}

///|
/// Graphviz parity: y-rank sweep range expands to include inserted flat-label
/// vnode ranks, while preserving continuous rank iteration.
/// Do not change behavior without updating fixtures/tests.
fn build_y_all_ranks_with_flat(
  rank_keys : Array[Int],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
) -> Array[Int] {
  let flat_ranks : Array[Int] = []
  for _name, info in flat_label_nodes {
    flat_ranks.push(info.rank)
  }
  @positioning.build_all_ranks_with_overlays(rank_keys, flat_ranks)
}

///|
/// Graphviz parity: y-position stage runs fill_rank_positions first, then
/// optional flip-cluster height correction (cluster.c path) and y rebuild.
/// Do not change behavior without updating fixtures/tests.
fn build_y_positions_with_flip(
  input : YPositionsWithFlipInput,
) -> YPositionsWithFlipOutput {
  @positioning.build_y_positions_with_flip_from_sources(
    {
      rank_keys: input.rank_keys,
      groups: input.groups,
      y_all_ranks: input.y_all_ranks,
      rank_pht: input.rank_pht,
      rank_ht1: input.rank_ht1,
      rank_ht2: input.rank_ht2,
      ranksep_pt: input.ranksep_pt,
      graphviz_flip: input.rankdir == RankDir::LR || input.rankdir == RankDir::RL,
      graph_has_cluster: @dot_shared.graph_has_cluster(input.graph),
      fill_rank_positions_fn:
        (
          rank_keys,
          groups,
          all_ranks,
          rank_pht,
          rank_ht1,
          rank_ht2,
          ranksep_pt,
          y_positions,
          rank_y,
        ) =>
          fill_rank_positions(
            {
              rank_keys,
              groups,
              all_ranks,
              rank_pht,
              rank_ht1,
              rank_ht2,
              ranksep_pt,
              y_positions,
              rank_y,
            },
          ),
      adjust_flip_rank_heights_fn:
        (rank_y, rank_ht1, rank_ht2, min_root_rank) =>
          adjust_flip_rank_heights(
            {
              graph: input.graph,
              ranks: input.ranks,
              rank_y,
              rank_ht1,
              rank_ht2,
              cluster_heights: input.cluster_bbox_heights,
              min_root_rank,
              margin_total: 0.0,
            },
          ),
    },
  )
}
