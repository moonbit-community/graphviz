///|
/// Cluster rank-height application helpers shared by rank assignment so
/// cluster-derived top/bottom half-heights are pushed back into rank bands.

///|
/// Graphviz parity: cluster rank-height application input keeps recursive graph
/// walk payload grouped so rank half-height propagation remains explicit.
pub(all) struct ClusterRankHeightsApplyInput {
  graph : @cgraph.Graph
  ranks : Map[String, Int]
  sizes : Map[String, @node_primitives.NodeSize]
  self_edge_labels : Map[String, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  rankdir : @rankdir.RankDir
  cluster_margin_pt_for : (@cgraph.Graph) -> Double
  cluster_label_padding_for : (
    @cgraph.Graph,
    @rankdir.RankDir,
  ) -> ClusterLabelPadding
  node_half_height_pt_for : (
    String,
    Map[String, @node_primitives.NodeSize],
    Map[String, Double],
  ) -> Double
}

fn apply_cluster_rank_heights_inner(
  input : ClusterRankHeightsApplyInput,
) -> ClusterHeights? {
  let is_cluster = @cluster_graph.is_cluster_graph(input.graph)
  let children = input.graph.subgraphs()
  if !is_cluster {
    for child in children {
      let _ = apply_cluster_rank_heights_inner(
        {
          graph: child,
          ranks: input.ranks,
          sizes: input.sizes,
          self_edge_labels: input.self_edge_labels,
          rank_ht1: input.rank_ht1,
          rank_ht2: input.rank_ht2,
          rankdir: input.rankdir,
          cluster_margin_pt_for: input.cluster_margin_pt_for,
          cluster_label_padding_for: input.cluster_label_padding_for,
          node_half_height_pt_for: input.node_half_height_pt_for,
        },
      )
    }
    return None
  }
  let seen : Map[String, Bool] = Map::new()
  let rank_heights : Map[Int, Double] = Map::new()
  let rank_bounds = collect_cluster_rank_heights(
    {
      graph: input.graph,
      ranks: input.ranks,
      sizes: input.sizes,
      self_edge_labels: input.self_edge_labels,
      seen,
      rank_heights,
      min_rank: None,
      max_rank: None,
      node_half_height_pt_for: input.node_half_height_pt_for,
    },
  )
  let min_rank_value = match rank_bounds.min_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights_inner(
          {
            graph: child,
            ranks: input.ranks,
            sizes: input.sizes,
            self_edge_labels: input.self_edge_labels,
            rank_ht1: input.rank_ht1,
            rank_ht2: input.rank_ht2,
            rankdir: input.rankdir,
            cluster_margin_pt_for: input.cluster_margin_pt_for,
            cluster_label_padding_for: input.cluster_label_padding_for,
            node_half_height_pt_for: input.node_half_height_pt_for,
          },
        )
      }
      return None
    }
  }
  let max_rank_value = match rank_bounds.max_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights_inner(
          {
            graph: child,
            ranks: input.ranks,
            sizes: input.sizes,
            self_edge_labels: input.self_edge_labels,
            rank_ht1: input.rank_ht1,
            rank_ht2: input.rank_ht2,
            rankdir: input.rankdir,
            cluster_margin_pt_for: input.cluster_margin_pt_for,
            cluster_label_padding_for: input.cluster_label_padding_for,
            node_half_height_pt_for: input.node_half_height_pt_for,
          },
        )
      }
      return None
    }
  }
  let margin = (input.cluster_margin_pt_for)(input.graph)
  let base_top = match rank_heights.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let base_bottom = match rank_heights.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let mut ht1 = add_cluster_margin_if_nonzero(base_top, margin)
  let mut ht2 = add_cluster_margin_if_nonzero(base_bottom, margin)
  for child in children {
    match
      apply_cluster_rank_heights_inner(
        {
          graph: child,
          ranks: input.ranks,
          sizes: input.sizes,
          self_edge_labels: input.self_edge_labels,
          rank_ht1: input.rank_ht1,
          rank_ht2: input.rank_ht2,
          rankdir: input.rankdir,
          cluster_margin_pt_for: input.cluster_margin_pt_for,
          cluster_label_padding_for: input.cluster_label_padding_for,
          node_half_height_pt_for: input.node_half_height_pt_for,
        },
      ) {
      Some(info) => {
        if info.max_rank == max_rank_value {
          let candidate = add_cluster_margin_if_nonzero(info.ht1, margin)
          if candidate > ht1 {
            ht1 = candidate
          }
        }
        if info.min_rank == min_rank_value {
          let candidate = add_cluster_margin_if_nonzero(info.ht2, margin)
          if candidate > ht2 {
            ht2 = candidate
          }
        }
      }
      None => ()
    }
  }
  let label_padding = (input.cluster_label_padding_for)(input.graph, input.rankdir)
  ht1 = ht1 + label_padding.bottom
  ht2 = ht2 + label_padding.top
  let current_top = match input.rank_ht1.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht1 > current_top {
    input.rank_ht1[max_rank_value] = ht1
  }
  let current_bottom = match input.rank_ht2.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht2 > current_bottom {
    input.rank_ht2[min_rank_value] = ht2
  }
  Some({ min_rank: min_rank_value, max_rank: max_rank_value, ht1, ht2 })
}

pub fn apply_cluster_rank_heights(input : ClusterRankHeightsApplyInput) -> Unit {
  let _ = apply_cluster_rank_heights_inner(input)
}
