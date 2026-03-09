///|
/// Rank/group helpers used by ordering and positioning subpackages.

///|
fn sort_rank_items(items : Array[(Double, Int, String)]) -> Array[String] {
  let sorted = items.copy()
  if sorted.length() > 1 {
    let eps = 0.000001
    sorted.sort_by((a, b) => {
      let (a_key, a_tie, _a_name) = a
      let (b_key, b_tie, _b_name) = b
      let diff = a_key - b_key
      if Double::abs(diff) <= eps {
        if a_tie < b_tie {
          -1
        } else if a_tie > b_tie {
          1
        } else {
          0
        }
      } else if diff < 0.0 {
        -1
      } else {
        1
      }
    })
  }
  let names : Array[String] = []
  for item in sorted {
    let (_key, _tie, name) = item
    names.push(name)
  }
  names
}

///|
pub fn build_x_groups_with_vnodes(
  ordered_groups : Map[Int, Array[String]],
  order_index : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
  vnode_order_keys : Map[String, Double],
) -> Map[Int, Array[String]] {
  let result : Map[Int, Array[String]] = Map::new()
  let rank_set : Map[Int, Bool] = Map::new()
  for rank, _names in ordered_groups {
    rank_set[rank] = true
  }
  for rank, _names in vnodes_by_rank {
    rank_set[rank] = true
  }
  let ranks : Array[Int] = []
  for rank, _ in rank_set {
    ranks.push(rank)
  }
  ranks.sort()
  for rank in ranks {
    let names = match ordered_groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    let vnodes = match vnodes_by_rank.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    if vnodes.length() == 0 {
      if names.length() > 0 {
        result[rank] = names
      }
      continue
    }
    let items : Array[(Double, Int, String)] = []
    let mut idx = 0
    for name in names {
      let key = match order_index.get(name) {
        Some(value) => value.to_double()
        None => idx.to_double()
      }
      items.push((key, idx, name))
      idx = idx + 1
    }
    let tie_offset = names.length() + 1
    let mut v_idx = 0
    for name in vnodes {
      let key = match vnode_order_keys.get(name) {
        Some(value) => value
        None => 0.0
      }
      items.push((key, tie_offset + v_idx, name))
      v_idx = v_idx + 1
    }
    result[rank] = sort_rank_items(items)
  }
  result
}

///|
pub fn collect_rank_keys(groups : Map[Int, Array[String]]) -> Array[Int] {
  let keys : Array[Int] = []
  for rank, _ in groups {
    keys.push(rank)
  }
  keys.sort()
  keys
}

///|
pub fn clone_rank_groups(
  groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let cloned : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    cloned[rank] = names.copy()
  }
  cloned
}

///|
pub fn build_node_ranks(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map::new()
  for rank, names in groups {
    for name in names {
      ranks[name] = rank
    }
  }
  ranks
}

///|
pub fn build_order_index(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      order[names[i]] = i
    }
  }
  order
}

///|
pub fn order_positions_from_groups(
  groups : Map[Int, Array[String]],
) -> Map[String, Double] {
  let positions : Map[String, Double] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      positions[names[i]] = i.to_double()
    }
  }
  positions
}
