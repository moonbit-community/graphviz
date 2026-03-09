///|
type NodeSize = @node_primitives.NodeSize

///|
pub(all) struct ExtraConstraintNode {
  name : String
  rank : Int
}

///|
pub fn merge_sizes_with_vnodes(
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  let merged : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    merged[name] = size
  }
  for name, size in vnode_sizes {
    merged[name] = size
  }
  merged
}

///|
/// Graphviz parity: vnode rank overlays replace base-node ranks for vnode
/// names while preserving all existing base rank entries.
/// Do not change behavior without updating fixtures/tests.
pub fn merge_ranks_with_vnodes(
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Map[String, Int] {
  let merged : Map[String, Int] = Map::new()
  for name, rank in ranks {
    merged[name] = rank
  }
  for name, rank in vnode_ranks {
    merged[name] = rank
  }
  merged
}

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
/// Graphviz parity: preserve vnode insertion order when seeding extra nodes
/// for xpos constraints (nlist-driven ordering), with map-order fallback.
/// Do not change behavior without updating fixtures/tests.
pub fn build_vnode_extra_nodes(
  vnode_order : Array[String],
  vnode_ranks : Map[String, Int],
) -> Array[ExtraConstraintNode] {
  let extra : Array[ExtraConstraintNode] = []
  let seen : Map[String, Bool] = Map::new()
  if vnode_order.length() > 0 {
    for name in vnode_order {
      match vnode_ranks.get(name) {
        Some(rank) => {
          extra.push({ name, rank })
          seen[name] = true
        }
        None => ()
      }
    }
  }
  if extra.length() < vnode_ranks.length() {
    for name, rank in vnode_ranks {
      if seen.get(name) is None {
        extra.push({ name, rank })
      }
    }
  }
  extra
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
/// Graphviz parity: rank=same ordering applies only for unported groups.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_rank_same_order(
  groups : Map[Int, Array[String]],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let _ = node_order
  let adjusted : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    adjusted[rank] = names.copy()
  }
  if rank_same_groups.length() == 0 {
    return adjusted
  }
  for _rank, names in adjusted {
    if names.length() <= 1 {
      continue
    }
    let group_positions : Map[Int, Array[Int]] = Map::new()
    let group_nodes : Map[Int, Array[String]] = Map::new()
    let group_has_ported : Map[Int, Bool] = Map::new()
    for i in 0..<names.length() {
      let name = names[i]
      match rank_same_groups.get(name) {
        Some(group) => {
          match group_positions.get(group) {
            Some(list) => list.push(i)
            None => group_positions[group] = [i]
          }
          match group_nodes.get(group) {
            Some(list) => list.push(name)
            None => group_nodes[group] = [name]
          }
          if port_edge_nodes.get(name) == Some(true) {
            group_has_ported[group] = true
          }
        }
        None => ()
      }
    }
    for group, positions in group_positions {
      if group_has_ported.get(group) == Some(true) {
        continue
      }
      let nodes = match group_nodes.get(group) {
        Some(list) => list
        None => []
      }
      if nodes.length() <= 1 {
        continue
      }
      let sorted = nodes.copy()
      sorted.sort_by((a, b) => {
        let a_idx = match rank_same_order.get(a) {
          Some(value) => value
          None => 0
        }
        let b_idx = match rank_same_order.get(b) {
          Some(value) => value
          None => 0
        }
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      })
      let mut idx = 0
      while idx < positions.length() && idx < sorted.length() {
        names[positions[idx]] = sorted[idx]
        idx = idx + 1
      }
    }
  }
  adjusted
}

///|
/// Graphviz parity: unported rank=same groups keep subgraph order for ND_order.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_rank_same_order_nodes(
  node_order : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> Unit {
  if rank_same_groups.length() == 0 {
    return ()
  }
  let group_nodes : Map[Int, Array[String]] = Map::new()
  let group_has_ported : Map[Int, Bool] = Map::new()
  for name, group in rank_same_groups {
    if node_order.get(name) is None {
      continue
    }
    match group_nodes.get(group) {
      Some(list) => list.push(name)
      None => group_nodes[group] = [name]
    }
    if port_edge_nodes.get(name) == Some(true) {
      group_has_ported[group] = true
    }
  }
  for group, names in group_nodes {
    if group_has_ported.get(group) == Some(true) {
      continue
    }
    if names.length() <= 1 {
      continue
    }
    let sorted_names = names.copy()
    sorted_names.sort_by((a, b) => {
      let a_idx = match rank_same_order.get(a) {
        Some(value) => value
        None => 0
      }
      let b_idx = match rank_same_order.get(b) {
        Some(value) => value
        None => 0
      }
      if a_idx < b_idx {
        -1
      } else if a_idx > b_idx {
        1
      } else {
        0
      }
    })
    let orders : Array[Int] = []
    for name in names {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      orders.push(order_value)
    }
    if orders.length() <= 1 {
      continue
    }
    orders.sort()
    let mut idx = 0
    while idx < sorted_names.length() && idx < orders.length() {
      node_order[sorted_names[idx]] = orders[idx]
      idx = idx + 1
    }
  }
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
