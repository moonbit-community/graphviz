///|
/// Positioning domain: rank-height and y-rank helper kernels shared by the
/// Stage D y-position solve wiring.

///|
/// Graphviz parity: per-rank half-height maxima from flat-edge label vnodes
/// must update rank_pht/rank_ht1/rank_ht2 consistently before y placement.
pub fn apply_rank_half_heights(
  half_heights_by_rank : Map[Int, Double],
  rank_pht : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Unit {
  for rank, half_height in half_heights_by_rank {
    let current_pht = rank_pht.get(rank).unwrap_or_default()
    if half_height > current_pht {
      rank_pht[rank] = half_height
    }
    let current_ht1 = rank_ht1.get(rank).unwrap_or_default()
    if half_height > current_ht1 {
      rank_ht1[rank] = half_height
    }
    let current_ht2 = rank_ht2.get(rank).unwrap_or_default()
    if half_height > current_ht2 {
      rank_ht2[rank] = half_height
    }
  }
}

///|
/// Graphviz parity: y-rank sweep range expands to include inserted flat-label
/// vnode ranks, while preserving continuous rank iteration.
pub fn build_all_ranks_with_overlays(
  rank_keys : Array[Int],
  overlay_ranks : Array[Int],
) -> Array[Int] {
  let all_ranks : Array[Int] = []
  if rank_keys.length() == 0 {
    return all_ranks
  }
  let mut min_rank = rank_keys[0]
  let mut max_rank = rank_keys[rank_keys.length() - 1]
  for rank in overlay_ranks {
    if rank < min_rank {
      min_rank = rank
    }
    if rank > max_rank {
      max_rank = rank
    }
  }
  for rank in min_rank..=max_rank {
    all_ranks.push(rank)
  }
  all_ranks
}

///|
/// Graphviz parity: when flipped cluster-rank heights adjust rank_y, node y
/// coordinates are rebuilt from rank order/groups without extra transforms.
pub fn build_y_positions_from_rank_groups(
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
/// Graphviz parity: y-position-with-flip output keeps node y-map and per-rank
/// y anchors grouped for Stage D projection.
pub struct YPositionsWithFlipOutput {
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
}

///|
/// Graphviz parity: y-position-with-flip source bundle keeps rank maps and
/// root callbacks grouped so Stage D call-sites avoid positional drift.
pub(all) struct YPositionsWithFlipSources {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  y_all_ranks : Array[Int]
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  ranksep_pt : Double
  graphviz_flip : Bool
  graph_has_cluster : Bool
  adjust_flip_rank_heights_fn : (
    Map[Int, Double],
    Map[Int, Double],
    Map[Int, Double],
    Int,
  ) -> Bool
}

///|
/// Graphviz parity: y-position stage runs fill_rank_positions first, then
/// optional flip-cluster height correction and y rebuild from rank_y.
/// Do not change behavior without updating fixtures/tests.
pub fn build_y_positions_with_flip_from_sources(
  sources : YPositionsWithFlipSources,
) -> YPositionsWithFlipOutput {
  let mut y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions(
    {
      rank_keys: sources.rank_keys,
      groups: sources.groups,
      all_ranks: sources.y_all_ranks,
      rank_pht: sources.rank_pht,
      rank_ht1: sources.rank_ht1,
      rank_ht2: sources.rank_ht2,
      ranksep_pt: sources.ranksep_pt,
      y_positions,
      rank_y,
    },
  )
  if sources.graphviz_flip && sources.graph_has_cluster {
    let min_root_rank =
      if sources.y_all_ranks.length() > 0 {
        sources.y_all_ranks[0]
      } else {
        0
      }
    if (sources.adjust_flip_rank_heights_fn)(
      rank_y,
      sources.rank_ht1,
      sources.rank_ht2,
      min_root_rank,
    ) {
      y_positions =
        build_y_positions_from_rank_groups(
          sources.rank_keys,
          sources.groups,
          rank_y,
        )
    }
  }
  { y_positions, rank_y }
}
