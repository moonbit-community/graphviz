///|
/// Stage B Phase B1/B2 split: rank-height assembly
/// helpers for layered spacing preparation.

///|
/// Graphviz parity: long-edge label midpoint contributes half height to the
/// midpoint rank slot before rank height normalization.
/// Do not change behavior without updating fixtures/tests.
fn update_rank_pht_for_edge_label_midpoint(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rankdir : RankDir,
) -> Unit {
  if !edge_has_label(edge) {
    return
  }
  let tail = edge.tail().name()
  let head = edge.head().name()
  let tail_rank = match ranks.get(tail) {
    Some(value) => value
    None => return
  }
  let head_rank = match ranks.get(head) {
    Some(value) => value
    None => return
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  if max_rank - min_rank <= 1 {
    return
  }
  let label_rank = (min_rank + max_rank) / 2
  let half_height = match edge_mid_label_metrics(edge) {
    Some((width, height)) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        width / 2.0
      } else {
        height / 2.0
      }
    None => 0.0
  }
  let current = match rank_pht.get(label_rank) {
    Some(value) => value
    None => 0.0
  }
  if half_height > current {
    rank_pht[label_rank] = half_height
  }
}



///|
/// Graphviz parity: initial per-rank half-heights come from the tallest
/// real node (plus self-edge label inflation) in each rank.
/// Do not change behavior without updating fixtures/tests.
fn build_initial_rank_pht_for_rank_heights(
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Map[Int, Double] {
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_half = 0.0
    for name in names {
      let half_height = node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
  rank_pht
}



///|
/// Graphviz parity: long edges reserve vnode half-height across intermediate
/// ranks before cluster rank height adjustments.
/// Do not change behavior without updating fixtures/tests.
fn apply_vnode_half_heights_for_rank_pht(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
) -> Unit {
  let vnode_half_height = VNODE_HEIGHT_PT / 2.0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    if max_rank - min_rank <= 1 {
      continue
    }
    for rank in (min_rank + 1)..<max_rank {
      let current = match rank_pht.get(rank) {
        Some(value) => value
        None => 0.0
      }
      if vnode_half_height > current {
        rank_pht[rank] = vnode_half_height
      }
    }
  }
}



///|
/// Graphviz parity: rank_ht1/rank_ht2 start as symmetric copies of rank_pht
/// before cluster-specific adjustments.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_ht_maps_from_rank_pht(
  all_ranks : Array[Int],
  rank_pht : Map[Int, Double],
) -> (Map[Int, Double], Map[Int, Double]) {
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = match rank_pht.get(rank) {
      Some(value) => value
      None => 0.0
    }
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  (rank_ht1, rank_ht2)
}



///|
/// Graphviz parity: rank height/spacing aligned to refs/graphviz/lib/dotgen/rank.c + dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_rank_heights(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rankdir : RankDir,
  nodesep_in : Double,
  ranksep_in : Double,
  has_edge_labels : Bool,
) -> RankHeights {
  let rank_pht = build_initial_rank_pht_for_rank_heights(
    groups,
    rank_keys,
    all_ranks,
    sizes,
    self_edge_labels,
  )
  // Graphviz parity: edge labels can raise intermediate rank half-heights
  // for long edges before vnode rank expansion in rank.c/position.c flow.
  if has_edge_labels {
    for edge in edges {
      update_rank_pht_for_edge_label_midpoint(edge, ranks, rank_pht, rankdir)
    }
  }
  apply_vnode_half_heights_for_rank_pht(edges, ranks, rank_pht)
  let (rank_ht1, rank_ht2) =
    build_rank_ht_maps_from_rank_pht(all_ranks, rank_pht)
  let _ = apply_cluster_rank_heights(
    graph, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2, rankdir,
  )
  let nodesep_pt = round_int(nodesep_in * 72.0).to_double()
  let mut ranksep_pt_int = round_int(ranksep_in * 72.0)
  if has_edge_labels {
    ranksep_pt_int = (ranksep_pt_int + 1) / 2
  }
  let ranksep_pt = ranksep_pt_int.to_double()
  { rank_pht, rank_ht1, rank_ht2, nodesep_pt, ranksep_pt }
}
