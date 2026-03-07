///|
/// Positioning domain: rank-spacing helpers shared by rank-height accounting
/// and final y-rank placement.

///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
pub fn node_half_height_pt(
  name : String,
  sizes : Map[String, @shared.NodeSize],
  self_edge_labels : Map[String, Double],
) -> Double {
  let base_height = match sizes.get(name) {
    Some(value) => value.height_pt / 2.0
    None => 0.0
  }
  let label_height = match self_edge_labels.get(name) {
    Some(value) => value
    None => 0.0
  }
  if label_height > base_height {
    label_height
  } else {
    base_height
  }
}

///|
pub fn self_edge_label_half_heights(
  edges : Array[@cgraph.Edge],
  edge_label_height_pt_for : (@cgraph.Edge) -> Double,
) -> Map[String, Double] {
  let heights : Map[String, Double] = Map::new()
  for edge in edges {
    if !@edge_semantics.edge_is_self(edge) {
      continue
    }
    let tail = edge.tail().name()
    let half_height = (edge_label_height_pt_for)(edge) / 2.0
    let current = match heights.get(tail) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current {
      heights[tail] = half_height
    }
  }
  heights
}

///|
/// Graphviz parity: rank-y fill input keeps rank-order, rank-height maps, and
/// output maps grouped for one deterministic downward sweep.
pub(all) struct FillRankPositionsInput {
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  all_ranks : Array[Int]
  rank_pht : Map[Int, Double]
  rank_ht1 : Map[Int, Double]
  rank_ht2 : Map[Int, Double]
  ranksep_pt : Double
  y_positions : Map[String, Double]
  rank_y : Map[Int, Double]
}

///|
pub fn fill_rank_positions(
  input : FillRankPositionsInput,
) -> Unit {
  if input.all_ranks.length() == 0 {
    return ()
  }
  let max_rank = input.all_ranks[input.all_ranks.length() - 1]
  let start_y = input.rank_ht1.get(max_rank).unwrap_or_default()
  input.rank_y[max_rank] = start_y
  let mut idx = input.all_ranks.length() - 1
  while idx > 0 {
    let upper = input.all_ranks[idx]
    let lower = input.all_ranks[idx - 1]
    let upper_pht = input.rank_pht.get(upper).unwrap_or_default()
    let lower_pht = input.rank_pht.get(lower).unwrap_or_default()
    let upper_ht2 = input.rank_ht2.get(upper).unwrap_or_default()
    let lower_ht1 = input.rank_ht1.get(lower).unwrap_or_default()
    let d0 = upper_pht + lower_pht + input.ranksep_pt
    let d1 = upper_ht2 + lower_ht1 + CLUSTER_MARGIN_PT
    let delta = if d0 > d1 { d0 } else { d1 }
    let base_y = input.rank_y.get(upper).unwrap_or_default()
    input.rank_y[lower] = base_y + delta
    idx = idx - 1
  }
  for rank in input.rank_keys {
    let names = input.groups.get(rank).unwrap_or_default()
    let pos_y = input.rank_y.get(rank).unwrap_or_default()
    for name in names {
      input.y_positions[name] = pos_y
    }
  }
}
