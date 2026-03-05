///|
/// Positioning domain: rank-spacing helpers shared by xpos, intercluster
/// alignment, and y-rank placement.

///|
const CLUSTER_MARGIN_PT : Double = 8.0

///|
const EDGE_LABEL_NODESEP_PT : Double = 5.0

///|
fn trunc_int(value : Double) -> Int {
  if value >= 0.0 {
    value.floor().to_int()
  } else {
    value.ceil().to_int()
  }
}

///|
fn size_left_pt(name : String, sizes : Map[String, @shared.NodeSize]) -> Double {
  match sizes.get(name) {
    Some(size) => size.left_pt
    None => 1.0
  }
}

///|
fn size_right_pt(name : String, sizes : Map[String, @shared.NodeSize]) -> Double {
  match sizes.get(name) {
    Some(size) => size.right_pt
    None => 1.0
  }
}

///|
pub fn rank_nodesep_pt(
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

///|
pub fn compute_rank_positions(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  sizes : Map[String, @shared.NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for rank in rank_keys {
    let names = groups.get(rank).unwrap_or_default()
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
      let tail_right = size_right_pt(prev, sizes)
      let head_left = size_left_pt(name, sizes)
      let width = tail_right + head_left + rank_nodesep
      current = trunc_int(current.to_double() + width)
      positions[name] = current.to_double()
      prev = name
      i = i + 1
    }
  }
  positions
}
