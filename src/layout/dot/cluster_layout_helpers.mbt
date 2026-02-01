///|
fn cluster_label_padding_pt(graph : @cgraph.Graph) -> (Double, Double) {
  match graph_label_metrics(graph) {
    Some((_width_pt, height_pt)) => {
      let loc = graph_label_loc(graph)
      let pad = CLUSTER_LABEL_PAD_PT
      match loc {
        LabelLoc::Top => (height_pt + pad, 0.0)
        LabelLoc::Bottom => (0.0, height_pt + pad)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
priv struct ClusterHeights {
  min_rank : Int
  max_rank : Int
  ht1 : Double
  ht2 : Double
}

///|
fn collect_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  seen : Map[String, Bool],
  rank_heights : Map[Int, Double],
  min_rank : Int?,
  max_rank : Int?,
) -> (Int?, Int?) {
  let mut next_min = min_rank
  let mut next_max = max_rank
  for node in graph.nodes() {
    let name = node.name()
    if seen.get(name) is Some(_) {
      continue
    }
    seen[name] = true
    match ranks.get(name) {
      Some(rank) => {
        let half_height = node_half_height_pt(name, sizes, self_edge_labels)
        let current = match rank_heights.get(rank) {
          Some(value) => value
          None => 0.0
        }
        if half_height > current {
          rank_heights[rank] = half_height
        }
        match next_min {
          Some(value) => if rank < value { next_min = Some(rank) }
          None => next_min = Some(rank)
        }
        match next_max {
          Some(value) => if rank > value { next_max = Some(rank) }
          None => next_max = Some(rank)
        }
      }
      None => ()
    }
  }
  for child in graph.subgraphs() {
    let (child_min, child_max) = collect_cluster_rank_heights(
      child, ranks, sizes, self_edge_labels, seen, rank_heights, next_min, next_max,
    )
    next_min = child_min
    next_max = child_max
  }
  (next_min, next_max)
}

///|
fn apply_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> ClusterHeights? {
  let is_cluster = is_cluster_graph(graph)
  let children = graph.subgraphs()
  if !is_cluster {
    for child in children {
      let _ = apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      )

    }
    return None
  }
  let seen : Map[String, Bool] = Map::new()
  let rank_heights : Map[Int, Double] = Map::new()
  let (min_rank, max_rank) = collect_cluster_rank_heights(
    graph,
    ranks,
    sizes,
    self_edge_labels,
    seen,
    rank_heights,
    None,
    None,
  )
  let min_rank_value = match min_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let max_rank_value = match max_rank {
    Some(value) => value
    None => {
      for child in children {
        let _ = apply_cluster_rank_heights(
          child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
        )

      }
      return None
    }
  }
  let margin = cluster_margin_pt(graph)
  let base_top = match rank_heights.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let base_bottom = match rank_heights.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let mut ht1 = base_top + margin
  let mut ht2 = base_bottom + margin
  for child in children {
    match
      apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2,
      ) {
      Some(info) => {
        if info.max_rank == max_rank_value {
          let candidate = info.ht1 + margin
          if candidate > ht1 {
            ht1 = candidate
          }
        }
        if info.min_rank == min_rank_value {
          let candidate = info.ht2 + margin
          if candidate > ht2 {
            ht2 = candidate
          }
        }
      }
      None => ()
    }
  }
  let (label_top, label_bottom) = cluster_label_padding_pt(graph)
  ht1 = ht1 + label_bottom
  ht2 = ht2 + label_top
  let current_top = match rank_ht1.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht1 > current_top {
    rank_ht1[max_rank_value] = ht1
  }
  let current_bottom = match rank_ht2.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  if ht2 > current_bottom {
    rank_ht2[min_rank_value] = ht2
  }
  Some({ min_rank: min_rank_value, max_rank: max_rank_value, ht1, ht2 })
}
