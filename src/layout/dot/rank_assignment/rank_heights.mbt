///|
type NodeSize = @node_primitives.NodeSize

///|
pub struct EdgeMidLabelMetrics {
  width : Double
  height : Double
}

///|
pub fn make_edge_mid_label_metrics(
  width : Double,
  height : Double,
) -> EdgeMidLabelMetrics {
  { width, height }
}

///|
/// Graphviz parity: rank-height payload keeps rank and spacing snapshots
/// grouped so Stage-B height wiring remains explicit and stable.
pub struct RankHeightsInput {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  all_ranks : Array[Int]
  sizes : Map[String, NodeSize]
  self_edge_labels : Map[String, Double]
  rankdir : @shared.RankDir
  nodesep_in : Double
  ranksep_in : Double
  has_edge_labels : Bool
  vnode_height_pt : Double
  edge_mid_label_metrics_for : (@cgraph.Edge) -> EdgeMidLabelMetrics?
  cluster_label_padding_for : (
    @cgraph.Graph,
    @shared.RankDir,
  ) -> @clustering.ClusterLabelPadding
}

///|
pub fn make_rank_heights_input(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rankdir : @shared.RankDir,
  nodesep_in : Double,
  ranksep_in : Double,
  has_edge_labels : Bool,
  vnode_height_pt : Double,
  edge_mid_label_metrics_for : (@cgraph.Edge) -> EdgeMidLabelMetrics?,
  cluster_label_padding_for : (
    @cgraph.Graph,
    @shared.RankDir,
  ) -> @clustering.ClusterLabelPadding,
) -> RankHeightsInput {
  {
    graph,
    edges,
    ranks,
    groups,
    rank_keys,
    all_ranks,
    sizes,
    self_edge_labels,
    rankdir,
    nodesep_in,
    ranksep_in,
    has_edge_labels,
    vnode_height_pt,
    edge_mid_label_metrics_for,
    cluster_label_padding_for,
  }
}

///|
pub struct RankHeights {
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  nodesep_pt : Double
  ranksep_pt : Double
}

///|
/// Graphviz parity: long-edge label midpoint contributes half height to the
/// midpoint rank slot before rank height normalization.
/// Do not change behavior without updating fixtures/tests.
fn update_rank_pht_for_label(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rankdir : @shared.RankDir,
  edge_mid_label_metrics_for : (@cgraph.Edge) -> EdgeMidLabelMetrics?,
) -> Unit {
  if !@edge_semantics.edge_has_label(edge) {
    return
  }
  let span = match @edge_semantics.edge_rank_span(edge, ranks) {
    Some(value) => value
    None => return
  }
  if span.max_rank - span.min_rank <= 1 {
    return
  }
  let label_rank = (span.min_rank + span.max_rank) / 2
  let half_height = match (edge_mid_label_metrics_for)(edge) {
    Some(metrics) =>
      if rankdir == @shared.RankDir::LR || rankdir == @shared.RankDir::RL {
        metrics.width / 2.0
      } else {
        metrics.height / 2.0
      }
    None => 0.0
  }
  let current = rank_pht.get(label_rank).unwrap_or_default()
  if half_height > current {
    rank_pht[label_rank] = half_height
  }
}

///|
priv struct RankHeightCopies {
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
priv struct BaseRankHalfHeights {
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
}

///|
fn init_rank_half_heights(
  all_ranks : Array[Int],
) -> Map[Int, Double] {
  let rank_pht : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    rank_pht[rank] = 0.0
  }
  rank_pht
}

///|
fn apply_node_rank_half_heights(
  rank_pht : Map[Int, Double],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Unit {
  for rank in rank_keys {
    let names = groups.get(rank).unwrap_or_default()
    let mut max_half = 0.0
    for name in names {
      let half_height =
        @positioning.node_half_height_pt(name, sizes, self_edge_labels)
      if half_height > max_half {
        max_half = half_height
      }
    }
    rank_pht[rank] = max_half
  }
}

///|
fn apply_edge_label_rank_half_heights(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  rankdir : @shared.RankDir,
  edge_mid_label_metrics_for : (@cgraph.Edge) -> EdgeMidLabelMetrics?,
) -> Unit {
  for edge in edges {
    update_rank_pht_for_label(
      edge,
      ranks,
      rank_pht,
      rankdir,
      edge_mid_label_metrics_for,
    )
  }
}

///|
fn apply_vnode_rank_half_heights(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  rank_pht : Map[Int, Double],
  vnode_height_pt : Double,
) -> Unit {
  // Graphviz parity: long edges reserve vnode half-height across
  // intermediate ranks before cluster rank height adjustments.
  let vnode_half_height = vnode_height_pt / 2.0
  for edge in edges {
    let span = match @edge_semantics.edge_rank_span(edge, ranks) {
      Some(value) => value
      None => continue
    }
    if span.max_rank - span.min_rank <= 1 {
      continue
    }
    for rank in (span.min_rank + 1)..<span.max_rank {
      let current = rank_pht.get(rank).unwrap_or_default()
      if vnode_half_height > current {
        rank_pht[rank] = vnode_half_height
      }
    }
  }
}

///|
fn clone_rank_half_heights(
  all_ranks : Array[Int],
  rank_pht : Map[Int, Double],
) -> RankHeightCopies {
  // Graphviz parity: rank_ht1/rank_ht2 start as symmetric copies of rank_pht
  // before cluster-specific adjustments.
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  for rank in all_ranks {
    let half_height = rank_pht.get(rank).unwrap_or_default()
    rank_ht1[rank] = half_height
    rank_ht2[rank] = half_height
  }
  { rank_ht1, rank_ht2 }
}

///|
/// Graphviz parity: base rank half-heights are computed before cluster-specific
/// rank height adjustment in the same node->edge-label->vnode order as rank.c.
/// Do not change behavior without updating fixtures/tests.
fn build_base_rank_half_heights(
  input : RankHeightsInput,
) -> BaseRankHalfHeights {
  let rank_pht = init_rank_half_heights(input.all_ranks)
  apply_node_rank_half_heights(
    rank_pht,
    input.rank_keys,
    input.groups,
    input.sizes,
    input.self_edge_labels,
  )
  if input.has_edge_labels {
    apply_edge_label_rank_half_heights(
      input.edges,
      input.ranks,
      rank_pht,
      input.rankdir,
      input.edge_mid_label_metrics_for,
    )
  }
  apply_vnode_rank_half_heights(
    input.edges,
    input.ranks,
    rank_pht,
    input.vnode_height_pt,
  )
  let rank_height_copies = clone_rank_half_heights(input.all_ranks, rank_pht)
  {
    rank_pht,
    rank_ht1: rank_height_copies.rank_ht1,
    rank_ht2: rank_height_copies.rank_ht2,
  }
}

///|
/// Graphviz parity: rank height/spacing aligned to refs/graphviz/lib/dotgen/rank.c
/// + dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_rank_heights(
  input : RankHeightsInput,
) -> RankHeights {
  let base_half_heights = build_base_rank_half_heights(input)
  let rank_pht = base_half_heights.rank_pht
  let rank_ht1 = base_half_heights.rank_ht1
  let rank_ht2 = base_half_heights.rank_ht2
  let _ = @clustering.apply_cluster_rank_heights(
    {
      graph: input.graph,
      ranks: input.ranks,
      sizes: input.sizes,
      self_edge_labels: input.self_edge_labels,
      rank_ht1,
      rank_ht2,
      rankdir: input.rankdir,
      cluster_margin_pt_for: @clustering.cluster_margin_pt,
      cluster_label_padding_for: input.cluster_label_padding_for,
      node_half_height_pt_for: @positioning.node_half_height_pt,
    },
  )
  let nodesep_pt = @shared.round_int(input.nodesep_in * 72.0).to_double()
  let mut ranksep_pt_int = @shared.round_int(input.ranksep_in * 72.0)
  if input.has_edge_labels {
    ranksep_pt_int = (ranksep_pt_int + 1) / 2
  }
  let ranksep_pt = ranksep_pt_int.to_double()
  { rank_pht, rank_ht1, rank_ht2, nodesep_pt, ranksep_pt }
}
