///|
fn rank_nodesep_pt(
  rank : Int,
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Double {
  if has_edge_labels && rank % 2 != 0 {
    EDGE_LABEL_NODESEP_PT
  } else {
    nodesep_pt
  }
}

///|
/// Graphviz parity: rank-y fill input keeps rank-order, rank-height maps, and
/// output maps grouped for one deterministic downward sweep.
priv struct FillRankPositionsInput {
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
fn fill_rank_positions(
  input : FillRankPositionsInput,
) -> Unit {
  if input.all_ranks.length() == 0 {
    return ()
  }
  let max_rank = input.all_ranks[input.all_ranks.length() - 1]
  let start_y = match input.rank_ht1.get(max_rank) {
    Some(value) => value
    None => 0.0
  }
  input.rank_y[max_rank] = start_y
  let mut idx = input.all_ranks.length() - 1
  while idx > 0 {
    let upper = input.all_ranks[idx]
    let lower = input.all_ranks[idx - 1]
    let upper_pht = match input.rank_pht.get(upper) {
      Some(value) => value
      None => 0.0
    }
    let lower_pht = match input.rank_pht.get(lower) {
      Some(value) => value
      None => 0.0
    }
    let upper_ht2 = match input.rank_ht2.get(upper) {
      Some(value) => value
      None => 0.0
    }
    let lower_ht1 = match input.rank_ht1.get(lower) {
      Some(value) => value
      None => 0.0
    }
    let d0 = upper_pht + lower_pht + input.ranksep_pt
    let d1 = upper_ht2 + lower_ht1 + CLUSTER_MARGIN_PT
    let delta = if d0 > d1 { d0 } else { d1 }
    let base_y = match input.rank_y.get(upper) {
      Some(value) => value
      None => 0.0
    }
    input.rank_y[lower] = base_y + delta
    idx = idx - 1
  }
  for rank in input.rank_keys {
    let names = match input.groups.get(rank) {
      Some(list) => list
      None => []
    }
    let pos_y = match input.rank_y.get(rank) {
      Some(value) => value
      None => 0.0
    }
    for name in names {
      input.y_positions[name] = pos_y
    }
  }
}

///|
fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    if names.length() == 0 {
      continue
    }
    let first = names[0]
    positions[first] = 0.0
    let mut current = 0
    let mut prev = first
    let mut i = 1
    let rank_nodesep = rank_nodesep_pt(rank, nodesep_pt, has_edge_labels)
    while i < names.length() {
      let name = names[i]
      let tail_right = node_right_pt(prev, sizes)
      let head_left = node_left_pt(name, sizes)
      let width = tail_right + head_left + rank_nodesep
      current = trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
}
