///|
fn cluster_label_padding_pt(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> ClusterLabelPadding {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    return { top: 0.0, bottom: 0.0 }
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let loc = graph_label_loc(graph)
      let pad = CLUSTER_LABEL_PAD_PT
      match loc {
        LabelLoc::Top => { top: metrics.height_pt + pad, bottom: 0.0 }
        LabelLoc::Bottom => { top: 0.0, bottom: metrics.height_pt + pad }
      }
    }
    None => { top: 0.0, bottom: 0.0 }
  }
}

priv struct ClusterLabelPadding {
  top : Double
  bottom : Double
}

///|
priv struct ClusterBboxHeightPair {
  ht1 : Double
  ht2 : Double
}

///|
priv struct ClusterHeights {
  min_rank : Int
  max_rank : Int
  ht1 : Double
  ht2 : Double
}

priv struct ClusterRankBounds {
  min_rank : Int?
  max_rank : Int?
}

///|
/// Graphviz parity: LR/RL cluster label height adjustment aligned to
/// refs/graphviz/lib/dotgen/position.c (adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn adjust_flip_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  cluster_heights : Map[String, ClusterBboxHeightPair],
  min_root_rank : Int,
  margin_total : Double,
) -> Bool {
  let mut changed = false
  let margin = if graph.is_root() { 0.0 } else { cluster_margin_pt(graph) }
  for child in graph.subgraphs() {
    if adjust_flip_rank_heights(
      child,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
      cluster_heights,
      min_root_rank,
      margin_total + margin,
    ) {
      changed = true
    }
  }
  if !@dot_shared.is_cluster_graph(graph) {
    return changed
  }
  let label_width = match graph_label_metrics(graph) {
    Some(metrics) => metrics.width_pt + CLUSTER_LABEL_PAD_PT * 2.0
    None => return changed
  }
  let cluster_nodes : Map[String, Bool] = Map::new()
  @dot_shared.collect_graph_nodes(graph, cluster_nodes)
  let mut min_rank : Int? = None
  let mut max_rank : Int? = None
  for name, _ in cluster_nodes {
    match ranks.get(name) {
      Some(rank) => {
        match min_rank {
          Some(value) => if rank < value { min_rank = Some(rank) }
          None => min_rank = Some(rank)
        }
        match max_rank {
          Some(value) => if rank > value { max_rank = Some(rank) }
          None => max_rank = Some(rank)
        }
      }
      None => ()
    }
  }
  let (min_rank_value, max_rank_value) = match (min_rank, max_rank) {
    (Some(min_value), Some(max_value)) => (min_value, max_value)
    _ => return changed
  }
  let min_rank_y = match rank_y.get(min_rank_value) {
    Some(value) => value
    None => return changed
  }
  let max_rank_y = match rank_y.get(max_rank_value) {
    Some(value) => value
    None => return changed
  }
  let base_ht1 = match rank_ht1.get(max_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let base_ht2 = match rank_ht2.get(min_rank_value) {
    Some(value) => value
    None => 0.0
  }
  let mut ht1 = base_ht1
  let mut ht2 = base_ht2
  match graph.name() {
    Some(name) =>
      match cluster_heights.get(name) {
        Some(value) => {
          ht1 = value.ht1
          ht2 = value.ht2
        }
        None => ()
      }
    None => ()
  }
  let rht = min_rank_y - max_rank_y
  let delta = label_width - (rht + ht1 + ht2)
  if delta > 0.0 {
    let bottom = (delta + 1.0) / 2.0
    let delbottom = ht1 + bottom - (base_ht1 - margin_total)
    if delbottom > 0.0 {
      let mut r = max_rank_value
      while true {
        match rank_y.get(r) {
          Some(value) => rank_y[r] = value + delbottom
          None => ()
        }
        if r == min_rank_value {
          break
        }
        r = r - 1
      }
    }
    let deltop =
      ht2 + (delta - bottom) + delbottom - (base_ht2 - margin_total)
    if deltop > 0.0 {
      let mut r = min_rank_value - 1
      while r >= min_root_rank {
        match rank_y.get(r) {
          Some(value) => rank_y[r] = value + deltop
          None => ()
        }
        if r == min_root_rank {
          break
        }
        r = r - 1
      }
    }
    let next_ht1 = ht1 + bottom
    let next_ht2 = ht2 + (delta - bottom)
    match graph.name() {
      Some(name) => cluster_heights[name] = { ht1: next_ht1, ht2: next_ht2 }
      None => ()
    }
    let current_ht1 = match rank_ht1.get(max_rank_value) {
      Some(value) => value
      None => 0.0
    }
    if next_ht1 > current_ht1 {
      rank_ht1[max_rank_value] = next_ht1
    }
    let current_ht2 = match rank_ht2.get(min_rank_value) {
      Some(value) => value
      None => 0.0
    }
    if next_ht2 > current_ht2 {
      rank_ht2[min_rank_value] = next_ht2
    }
    changed = true
  }
  changed
}

fn collect_cluster_bbox_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rankdir : RankDir,
  cluster_heights : Map[String, ClusterBboxHeightPair],
) -> ClusterHeights? {
  let is_cluster = @dot_shared.is_cluster_graph(graph)
  let children = graph.subgraphs()
  if !is_cluster {
    for child in children {
      let _ =
        collect_cluster_bbox_heights(
        child,
        ranks,
        sizes,
        self_edge_labels,
        rankdir,
        cluster_heights,
      )
    }
    return None
  }
  let collect_children = () => {
    for child in children {
      let _ =
        collect_cluster_bbox_heights(
          child,
          ranks,
          sizes,
          self_edge_labels,
          rankdir,
          cluster_heights,
        )
    }
  }
  let seen : Map[String, Bool] = Map::new()
  let rank_heights : Map[Int, Double] = Map::new()
  let rank_bounds = collect_cluster_rank_heights(
    graph,
    ranks,
    sizes,
    self_edge_labels,
    seen,
    rank_heights,
    None,
    None,
  )
  let min_rank_value = match rank_bounds.min_rank {
    Some(value) => value
    None => {
      collect_children()
      return None
    }
  }
  let max_rank_value = match rank_bounds.max_rank {
    Some(value) => value
    None => {
      collect_children()
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
  let mut ht1 = add_cluster_margin_if_nonzero(base_top, margin)
  let mut ht2 = add_cluster_margin_if_nonzero(base_bottom, margin)
  for child in children {
    match
      collect_cluster_bbox_heights(
        child,
        ranks,
        sizes,
        self_edge_labels,
        rankdir,
        cluster_heights,
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
  let label_padding = cluster_label_padding_pt(graph, rankdir)
  ht1 = ht1 + label_padding.bottom
  ht2 = ht2 + label_padding.top
  match graph.name() {
    Some(name) => cluster_heights[name] = { ht1, ht2 }
    None => ()
  }
  Some({ min_rank: min_rank_value, max_rank: max_rank_value, ht1, ht2 })
}

///|
/// Graphviz parity: cluster bbox heights aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_bbox_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rankdir : RankDir,
) -> Map[String, ClusterBboxHeightPair] {
  let cluster_heights : Map[String, ClusterBboxHeightPair] = Map::new()
  let _ =
    collect_cluster_bbox_heights(
    graph,
    ranks,
    sizes,
    self_edge_labels,
    rankdir,
    cluster_heights,
  )
  cluster_heights
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
) -> ClusterRankBounds {
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
        // Graphviz parity: external ranksets can delete cluster membership
        // for a node while the cluster rank span still reflects subgraph
        // structure (node_induce + mark_clusters behavior).
        if graph_contains_node(graph, node) {
          let half_height = node_half_height_pt(name, sizes, self_edge_labels)
          let current = match rank_heights.get(rank) {
            Some(value) => value
            None => 0.0
          }
          if half_height > current {
            rank_heights[rank] = half_height
          }
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
    let child_bounds = collect_cluster_rank_heights(
      child, ranks, sizes, self_edge_labels, seen, rank_heights, next_min, next_max,
    )
    next_min = child_bounds.min_rank
    next_max = child_bounds.max_rank
  }
  { min_rank: next_min, max_rank: next_max }
}

fn add_cluster_margin_if_nonzero(height : Double, margin : Double) -> Double {
  if height > 0.0 {
    height + margin
  } else {
    0.0
  }
}

///|
fn apply_cluster_rank_heights(
  graph : @cgraph.Graph,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  rankdir : RankDir,
) -> ClusterHeights? {
  let is_cluster = @dot_shared.is_cluster_graph(graph)
  let children = graph.subgraphs()
  if !is_cluster {
    for child in children {
      let _ = apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2, rankdir,
      )

    }
    return None
  }
  let apply_children = () => {
    for child in children {
      let _ = apply_cluster_rank_heights(
        child,
        ranks,
        sizes,
        self_edge_labels,
        rank_ht1,
        rank_ht2,
        rankdir,
      )
    }
  }
  let seen : Map[String, Bool] = Map::new()
  let rank_heights : Map[Int, Double] = Map::new()
  let rank_bounds = collect_cluster_rank_heights(
    graph,
    ranks,
    sizes,
    self_edge_labels,
    seen,
    rank_heights,
    None,
    None,
  )
  let min_rank_value = match rank_bounds.min_rank {
    Some(value) => value
    None => {
      apply_children()
      return None
    }
  }
  let max_rank_value = match rank_bounds.max_rank {
    Some(value) => value
    None => {
      apply_children()
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
  let mut ht1 = add_cluster_margin_if_nonzero(base_top, margin)
  let mut ht2 = add_cluster_margin_if_nonzero(base_bottom, margin)
  for child in children {
    match
      apply_cluster_rank_heights(
        child, ranks, sizes, self_edge_labels, rank_ht1, rank_ht2, rankdir,
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
  let label_padding = cluster_label_padding_pt(graph, rankdir)
  ht1 = ht1 + label_padding.bottom
  ht2 = ht2 + label_padding.top
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
