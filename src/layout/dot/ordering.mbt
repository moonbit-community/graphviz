///|
fn merge_sizes_with_vnodes(
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
fn collect_rank_same_order(
  graph : @cgraph.Graph,
  group_ids : Map[String, Int],
  order_ids : Map[String, Int],
  next_group : Int,
) -> Int {
  let mut current_group = next_group
  match graph.get_attr("rank") {
    Some(value) =>
      if value.to_lower() == "same" {
        let group_id = current_group
        current_group = current_group + 1
        let mut idx = 0
        for node in graph.nodes() {
          if group_ids.get(node.name()) is None {
            group_ids[node.name()] = group_id
            order_ids[node.name()] = idx
          }
          idx = idx + 1
        }
      }
    None => ()
  }
  for child in graph.subgraphs() {
    current_group = collect_rank_same_order(
      child, group_ids, order_ids, current_group,
    )
  }
  current_group
}

///|
fn position_key(
  name : String,
  desired : Map[String, Double],
  x_positions : Map[String, Double],
) -> Double {
  match desired.get(name) {
    Some(value) => value
    None =>
      match x_positions.get(name) {
        Some(value) => value
        None => 0.0
      }
  }
}

///|
priv struct PositionSortInfo {
  name : String
  key : Double
  is_vnode : Bool
  degree : Int
  secondary : Int
  penalty : Int
  ported : Bool
  node_order : Int
  original_index : Int
  port_order : Double?
  rank_same_group : Int?
  rank_same_order : Int
}

///|
fn sort_by_positions_fast(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  node_order : Map[String, Int],
  reverse_ties : Bool,
) -> Array[String] {
  let infos : Array[PositionSortInfo] = []
  for i in 0..<names.length() {
    let name = names[i]
    let key = position_key(name, desired, x_positions)
    let degree = match primary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let secondary_degree = match secondary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let penalty = match node_penalty.get(name) {
      Some(value) => value
      None => 0
    }
    let ported = port_edge_nodes.get(name) is Some(_)
    let is_vnode = is_edge_vnode_name(name)
    let order_value = match node_order.get(name) {
      Some(value) => value
      None => i
    }
    infos.push({
      name,
      key,
      is_vnode,
      degree,
      secondary: secondary_degree,
      penalty,
      ported,
      node_order: order_value,
      original_index: i,
      port_order: None,
      rank_same_group: None,
      rank_same_order: 0,
    })
  }
  let eps = 0.000001
  infos.sort_by((a, b) => {
    let diff = a.key - b.key
    if Double::abs(diff) > eps {
      if diff < 0.0 { -1 } else { 1 }
    } else if a.is_vnode != b.is_vnode {
      if a.is_vnode { -1 } else { 1 }
    } else if a.degree != b.degree {
      if a.degree > b.degree { -1 } else { 1 }
    } else if a.ported != b.ported {
      if a.ported { -1 } else { 1 }
    } else if a.secondary != b.secondary {
      if a.secondary > b.secondary { -1 } else { 1 }
    } else if a.penalty != b.penalty {
      if a.penalty > b.penalty { -1 } else { 1 }
    } else if a.node_order != b.node_order {
      if reverse_ties {
        if a.node_order < b.node_order { 1 } else { -1 }
      } else {
        if a.node_order < b.node_order { -1 } else { 1 }
      }
    } else if a.original_index != b.original_index {
      if reverse_ties {
        if a.original_index < b.original_index { 1 } else { -1 }
      } else {
        if a.original_index < b.original_index { -1 } else { 1 }
      }
    } else {
      0
    }
  })
  let sorted : Array[String] = []
  for info in infos {
    sorted.push(info.name)
  }
  sorted
}

///|
fn sort_by_positions_large(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  node_order : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  let infos : Array[PositionSortInfo] = []
  for i in 0..<names.length() {
    let name = names[i]
    let key = position_key(name, desired, x_positions)
    let degree = match primary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let secondary_degree = match secondary.get(name) {
      Some(list) => list.length()
      None => 0
    }
    let penalty = match node_penalty.get(name) {
      Some(value) => value
      None => 0
    }
    let ported = port_edge_nodes.get(name) is Some(_)
    let is_vnode = is_edge_vnode_name(name)
    let order_value = match node_order.get(name) {
      Some(value) => value
      None => i
    }
    let port_order = port_order_positions.get(name)
    let rank_group = rank_same_groups.get(name)
    let rank_order = match rank_same_order.get(name) {
      Some(value) => value
      None => 0
    }
    infos.push({
      name,
      key,
      is_vnode,
      degree,
      secondary: secondary_degree,
      penalty,
      ported,
      node_order: order_value,
      original_index: i,
      port_order,
      rank_same_group: rank_group,
      rank_same_order: rank_order,
    })
  }
  let eps = 0.000001
  infos.sort_by((a, b) => {
    let diff = a.key - b.key
    if Double::abs(diff) > eps {
      if diff < 0.0 { -1 } else { 1 }
    } else {
      let port_cmp = match a.port_order {
        Some(a_port) =>
          match b.port_order {
            Some(b_port) =>
              if a_port != b_port {
                if a_port < b_port { -1 } else { 1 }
              } else {
                0
              }
            None => 0
          }
        None => 0
      }
      if port_cmp != 0 {
        port_cmp
      } else if a.is_vnode != b.is_vnode {
        if a.is_vnode { -1 } else { 1 }
      } else if a.degree != b.degree {
        if a.degree > b.degree { -1 } else { 1 }
      } else if a.ported != b.ported {
        if a.ported { -1 } else { 1 }
      } else if a.secondary != b.secondary {
        if a.secondary > b.secondary { -1 } else { 1 }
      } else if a.penalty != b.penalty {
        if a.penalty > b.penalty { -1 } else { 1 }
      } else if a.ported && b.ported && a.node_order != b.node_order {
        if reverse_ties {
          if a.node_order < b.node_order { 1 } else { -1 }
        } else {
          if a.node_order < b.node_order { -1 } else { 1 }
        }
      } else {
        match a.rank_same_group {
          Some(group) =>
            match b.rank_same_group {
              Some(other_group) =>
                if group == other_group && a.rank_same_order != b.rank_same_order {
                  if a.rank_same_order < b.rank_same_order { -1 } else { 1 }
                } else if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order { 1 } else { -1 }
                  } else {
                    if a.node_order < b.node_order { -1 } else { 1 }
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index { 1 } else { -1 }
                  } else {
                    if a.original_index < b.original_index { -1 } else { 1 }
                  }
                } else {
                  0
                }
              None =>
                if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order { 1 } else { -1 }
                  } else {
                    if a.node_order < b.node_order { -1 } else { 1 }
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index { 1 } else { -1 }
                  } else {
                    if a.original_index < b.original_index { -1 } else { 1 }
                  }
                } else {
                  0
                }
            }
          None =>
            if a.node_order != b.node_order {
              if reverse_ties {
                if a.node_order < b.node_order { 1 } else { -1 }
              } else {
                if a.node_order < b.node_order { -1 } else { 1 }
              }
            } else if a.original_index != b.original_index {
              if reverse_ties {
                if a.original_index < b.original_index { 1 } else { -1 }
              } else {
                if a.original_index < b.original_index { -1 } else { 1 }
              }
            } else {
              0
            }
        }
      }
    }
  })
  let sorted : Array[String] = []
  for info in infos {
    sorted.push(info.name)
  }
  sorted
}

///|
fn sort_by_positions(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  parents_map : Map[String, Array[String]],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_rank_same = false
  for _name, _ in rank_same_groups {
    has_rank_same = true
    break
  }
  let mut has_ported_nodes = false
  for _name, _ in port_edge_nodes {
    has_ported_nodes = true
    break
  }
  if sorted.length() >= LARGE_SORT_THRESHOLD {
    return sort_by_positions_large(
      sorted,
      desired,
      x_positions,
      primary,
      secondary,
      node_penalty,
      port_edge_nodes,
      node_order,
      rank_same_groups,
      rank_same_order,
      port_order_positions,
      reverse_ties,
    )
  }
  if sorted.length() >= 64 && !has_port_order && !has_rank_same && !has_ported_nodes {
    return sort_by_positions_fast(
      sorted,
      desired,
      x_positions,
      primary,
      secondary,
      node_penalty,
      port_edge_nodes,
      node_order,
      reverse_ties,
    )
  }
  let _ = edge_order
  let mut i = 1
  while i < sorted.length() {
    let current = sorted[i]
    let current_key = position_key(current, desired, x_positions)
    let mut j = i
    let current_degree = match primary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    let current_secondary = match secondary.get(current) {
      Some(list) => list.length()
      None => 0
    }
    let current_penalty = match node_penalty.get(current) {
      Some(value) => value
      None => 0
    }
    while j > 0 {
      let prev = sorted[j - 1]
      let prev_has_desired = desired.get(prev) is Some(_)
      let current_has_desired = desired.get(current) is Some(_)
      if !prev_has_desired || !current_has_desired {
        break
      }
      let prev_key = position_key(prev, desired, x_positions)
      let diff = prev_key - current_key
      if diff < -0.000001 {
        break
      }
      if Double::abs(diff) <= 0.000001 {
        match port_order_positions.get(prev) {
          Some(prev_port) =>
            match port_order_positions.get(current) {
              Some(current_port) =>
                if prev_port != current_port {
                  if prev_port <= current_port {
                    break
                  }
                }
              None => ()
            }
          None => ()
        }
        let prev_vnode = is_edge_vnode_name(prev)
        let current_vnode = is_edge_vnode_name(current)
        if prev_vnode != current_vnode {
          if prev_vnode {
            break
          }
        }
        let prev_degree = match primary.get(prev) {
          Some(list) => list.length()
          None => 0
        }
        if prev_degree < current_degree {
          // move current left
        } else if prev_degree > current_degree {
          break
        } else {
          let prev_ported = port_edge_nodes.get(prev) is Some(_)
          let current_ported = port_edge_nodes.get(current) is Some(_)
          if prev_ported != current_ported {
            if !current_ported {
              break
            }
          } else {
            let prev_secondary = match secondary.get(prev) {
              Some(list) => list.length()
              None => 0
            }
            if prev_secondary < current_secondary {
              // move current left
            } else if prev_secondary > current_secondary {
              break
            } else {
              let prev_penalty = match node_penalty.get(prev) {
                Some(value) => value
                None => 0
              }
              if prev_penalty < current_penalty {
                // move current left
              } else if prev_penalty > current_penalty {
                break
              } else {
              let mut decided = false
              if prev_ported && current_ported {
                let prev_idx = match node_order.get(prev) {
                  Some(value) => value
                  None => 0
                }
                let current_idx = match node_order.get(current) {
                  Some(value) => value
                  None => 0
                }
                decided = true
                let keep_order =
                  if reverse_ties { prev_idx >= current_idx } else { prev_idx <= current_idx }
                if keep_order {
                  break
                }
              }
              if !decided {
                match rank_same_groups.get(prev) {
                  Some(prev_group) =>
                    match rank_same_groups.get(current) {
                      Some(current_group) =>
                        if prev_group == current_group {
                          let prev_idx = match rank_same_order.get(prev) {
                            Some(value) => value
                            None => 0
                          }
                          let current_idx = match rank_same_order.get(current) {
                            Some(value) => value
                            None => 0
                          }
                          decided = true
                          let keep_order = prev_idx <= current_idx
                          if keep_order {
                            break
                          }
                        }
                      None => ()
                    }
                  None => ()
                }
              }
              if !decided {
                let prev_parents = match parents_map.get(prev) {
                  Some(list) => list
                  None => []
                }
                let current_parents = match parents_map.get(current) {
                  Some(list) => list
                  None => []
                }
                for parent in prev_parents {
                  let mut shared = false
                  for candidate in current_parents {
                    if candidate == parent {
                      shared = true
                      break
                    }
                  }
                  if !shared {
                    continue
                  }
                  let prev_key = "\{parent}|\{prev}"
                  let current_key = "\{parent}|\{current}"
                  match edge_pair_order.get(prev_key) {
                    Some(prev_idx) =>
                      match edge_pair_order.get(current_key) {
                        Some(current_idx) => {
                          decided = true
                          let keep_order =
                            if reverse_ties {
                              prev_idx >= current_idx
                            } else {
                              prev_idx <= current_idx
                            }
                          if keep_order {
                            break
                          }
                        }
                        None => ()
                      }
                    None => ()
                  }
                  if decided {
                    break
                  }
                }
              }
              if !decided {
                if !reverse_ties {
                  break
                }
              }
              }
            }
          }
        }
      }
      sorted[j] = prev
      j = j - 1
    }
    sorted[j] = current
    i = i + 1
  }
  sorted
}

///|
fn median_value(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  let sorted = values.copy()
  sorted.sort()
  let mid = sorted.length() / 2
  if sorted.length() % 2 == 0 {
    Some((sorted[mid - 1] + sorted[mid]) / 2.0)
  } else {
    Some(sorted[mid])
  }
}

///|
fn median_value_mc_scale(values : Array[Double]) -> Double? {
  if values.length() == 0 {
    return None
  }
  // Graphviz parity: medians are computed on MC_SCALE=256 integer values,
  // which affects tie behavior via integer division.
  let scale = 256.0
  let scaled : Array[Int] = []
  for value in values {
    scaled.push((value * scale).trunc().to_int())
  }
  scaled.sort()
  if scaled.length() == 1 {
    return Some(scaled[0].to_double() / scale)
  }
  if scaled.length() == 2 {
    return Some(((scaled[0] + scaled[1]) / 2).to_double() / scale)
  }
  let mid = scaled.length() / 2
  if scaled.length() % 2 == 1 {
    return Some(scaled[mid].to_double() / scale)
  }
  let rm = mid
  let lm = rm - 1
  let rspan = scaled[scaled.length() - 1] - scaled[rm]
  let lspan = scaled[lm] - scaled[0]
  if lspan == rspan {
    Some(((scaled[lm] + scaled[rm]) / 2).to_double() / scale)
  } else {
    let weighted =
      scaled[lm].to_double() * rspan.to_double() +
      scaled[rm].to_double() * lspan.to_double()
    Some(weighted / (lspan + rspan).to_double() / scale)
  }
}

///|
fn collect_edge_order(edges : Array[@cgraph.Edge]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  let mut idx = 0
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if order.get(tail) is None {
      order[tail] = idx
    }
    if order.get(head) is None {
      order[head] = idx
    }
    idx = idx + 1
  }
  order
}

///|
fn left2right_constraint(
  left : String,
  right : String,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  remincross_mode? : Bool = false,
) -> Bool {
  let left_cluster = match cluster_keys.get(left) {
    Some(value) => value
    None => ""
  }
  let right_cluster = match cluster_keys.get(right) {
    Some(value) => value
    None => ""
  }
  if remincross_mode {
    // Graphviz parity: in ReMincross, nodes in different buckets are pinned.
    if left_cluster != right_cluster {
      return true
    }
  }
  if left_cluster != "" && right_cluster != "" && left_cluster != right_cluster {
    let left_skel = cluster_skeleton.get(left) == Some(true)
    let right_skel = cluster_skeleton.get(right) == Some(true)
    if !left_skel && !right_skel {
      return true
    }
  }
  let key = "\{left}|\{right}"
  flat_constraints.get(key) == Some(true)
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
fn build_x_groups_with_vnodes(
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
fn collect_rank_keys(groups : Map[Int, Array[String]]) -> Array[Int] {
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
fn build_vnode_extra_nodes(
  vnode_order : Array[String],
  vnode_ranks : Map[String, Int],
) -> Array[(String, Int)] {
  let extra : Array[(String, Int)] = []
  let seen : Map[String, Bool] = Map::new()
  if vnode_order.length() > 0 {
    for name in vnode_order {
      match vnode_ranks.get(name) {
        Some(rank) => {
          extra.push((name, rank))
          seen[name] = true
        }
        None => ()
      }
    }
  }
  if extra.length() < vnode_ranks.length() {
    for name, rank in vnode_ranks {
      if seen.get(name) is None {
        extra.push((name, rank))
      }
    }
  }
  extra
}

///|
fn clone_rank_groups(
  groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let cloned : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    cloned[rank] = names.copy()
  }
  cloned
}

/// Graphviz parity: rank=same ordering applies only for unported groups.
/// Do not change behavior without updating fixtures/tests.
fn apply_rank_same_order_with_ports(
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
fn apply_rank_same_order_to_node_order(
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
fn build_node_ranks(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map::new()
  for rank, names in groups {
    for name in names {
      ranks[name] = rank
    }
  }
  ranks
}

///|
fn build_order_index(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      order[names[i]] = i
    }
  }
  order
}

///|
fn order_positions_from_groups(
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

///|
fn count_inversions(values : Array[Int]) -> Int {
  let n = values.length()
  if n < 2 {
    return 0
  }
  let mut src = values.copy()
  let mut dst = Array::make(n, 0)
  let mut size = 1
  let mut total = 0
  while size < n {
    let mut i = 0
    while i < n {
      let left = i
      let mid = {
        let next = i + size
        if next < n { next } else { n }
      }
      let right = {
        let next = i + size + size
        if next < n { next } else { n }
      }
      let mut a = left
      let mut b = mid
      let mut k = left
      while a < mid && b < right {
        if src[a] <= src[b] {
          dst[k] = src[a]
          a = a + 1
        } else {
          dst[k] = src[b]
          b = b + 1
          total = total + (mid - a)
        }
        k = k + 1
      }
      while a < mid {
        dst[k] = src[a]
        a = a + 1
        k = k + 1
      }
      while b < right {
        dst[k] = src[b]
        b = b + 1
        k = k + 1
      }
      i = i + size + size
    }
    let tmp = src
    src = dst
    dst = tmp
    size = size + size
  }
  total
}

///|
fn count_crossings(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Int {
  let order = build_order_index(groups)
  let edge_groups : Map[(Int, Int), Array[(Int, Int)]] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !@dot_shared.edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    if tail_rank == head_rank {
      continue
    }
    let low_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
    let high_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
    let low_node = if tail_rank < head_rank { tail } else { head }
    let high_node = if tail_rank < head_rank { head } else { tail }
    let low_order = match order.get(low_node) {
      Some(value) => value
      None => continue
    }
    let high_order = match order.get(high_node) {
      Some(value) => value
      None => continue
    }
    let key = (low_rank, high_rank)
    match edge_groups.get(key) {
      Some(list) => list.push((low_order, high_order))
      None => edge_groups[key] = [(low_order, high_order)]
    }
  }
  let mut crossings = 0
  for _key, list in edge_groups {
    if list.length() < 2 {
      continue
    }
    list.sort_by((a, b) => {
      let (a0, a1) = a
      let (b0, b1) = b
      if a0 == b0 { a1 - b1 } else { a0 - b0 }
    })
    let heads : Array[Int] = []
    for pair in list {
      let (_, h) = pair
      heads.push(h)
    }
    crossings = crossings + count_inversions(heads)
  }
  crossings
}

///|
///|
/// Graphviz parity: include local port-order crossings
/// (mincross.c rcross/local_cross).
/// Do not change behavior without updating fixtures/tests.
fn local_cross_out_port_aware(
  node : String,
  next_rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_out : Map[String, Array[Int]],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> Int {
  let outs = match edge_out.get(node) {
    Some(list) => list
    None => []
  }
  if outs.length() < 2 {
    return 0
  }
  let items : Array[(Int, Double, Int)] = []
  for edge_idx in outs {
    let head = edge_head[edge_idx]
    if ranks.get(head) != Some(next_rank) {
      continue
    }
    let head_order = match order.get(head) {
      Some(value) => value
      None => continue
    }
    let penalty =
      if edge_idx < edge_penalty.length() { edge_penalty[edge_idx] } else { 0 }
    if penalty <= 0 {
      continue
    }
    let port_x =
      if edge_idx < edge_tail_port_x.length() { edge_tail_port_x[edge_idx] } else {
        0.0
      }
    items.push((head_order, port_x, penalty))
  }
  if items.length() < 2 {
    return 0
  }
  let mut cross = 0
  let mut i = 0
  while i + 1 < items.length() {
    let (order_i, port_i, pen_i) = items[i]
    let mut j = i + 1
    while j < items.length() {
      let (order_j, port_j, pen_j) = items[j]
      if (order_j - order_i).to_double() * (port_j - port_i) < 0.0 {
        cross = cross + pen_i * pen_j
      }
      j = j + 1
    }
    i = i + 1
  }
  cross
}

///|
/// Graphviz parity: include local port-order crossings
/// (mincross.c rcross/local_cross).
/// Do not change behavior without updating fixtures/tests.
fn local_cross_in_port_aware(
  node : String,
  prev_rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> Int {
  let ins = match edge_in.get(node) {
    Some(list) => list
    None => []
  }
  if ins.length() < 2 {
    return 0
  }
  let items : Array[(Int, Double, Int)] = []
  for edge_idx in ins {
    let tail = edge_tail[edge_idx]
    if ranks.get(tail) != Some(prev_rank) {
      continue
    }
    let tail_order = match order.get(tail) {
      Some(value) => value
      None => continue
    }
    let penalty =
      if edge_idx < edge_penalty.length() { edge_penalty[edge_idx] } else { 0 }
    if penalty <= 0 {
      continue
    }
    let port_x =
      if edge_idx < edge_head_port_x.length() { edge_head_port_x[edge_idx] } else {
        0.0
      }
    items.push((tail_order, port_x, penalty))
  }
  if items.length() < 2 {
    return 0
  }
  let mut cross = 0
  let mut i = 0
  while i + 1 < items.length() {
    let (order_i, port_i, pen_i) = items[i]
    let mut j = i + 1
    while j < items.length() {
      let (order_j, port_j, pen_j) = items[j]
      if (order_j - order_i).to_double() * (port_j - port_i) < 0.0 {
        cross = cross + pen_i * pen_j
      }
      j = j + 1
    }
    i = i + 1
  }
  cross
}

///|
/// Graphviz parity: rcross-style crossing count with local port-order ties.
/// Do not change behavior without updating fixtures/tests.
fn count_crossings_port_aware(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x? : Array[Double] = [],
  edge_head_port_x? : Array[Double] = [],
  fixed_order? : Map[String, Int] = Map::new(),
) -> Int {
  let order = build_order_index(groups)
  let rank_keys : Array[Int] = []
  for rank, _ in groups {
    rank_keys.push(rank)
  }
  if rank_keys.length() == 0 {
    return 0
  }
  rank_keys.sort()
  let edge_out : Map[String, Array[Int]] = Map::new()
  let edge_in : Map[String, Array[Int]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      edge_out[name] = []
      edge_in[name] = []
    }
  }
  let edge_penalty : Array[Int] = []
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = @dot_shared.edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if !@dot_shared.edge_is_constraint(edge) {
      continue
    }
    if penalty <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
    let head = edge_head[edge_idx]
    match edge_in.get(head) {
      Some(list) => list.push(edge_idx)
      None => edge_in[head] = [edge_idx]
    }
  }
  let include_ports =
    edge_tail_port_x.length() > 0 || edge_head_port_x.length() > 0
  let mut crossings = 0
  let mut idx = 0
  while idx + 1 < rank_keys.length() {
    let rank = rank_keys[idx]
    let next_rank = rank_keys[idx + 1]
    let mut rank_cross = 0
    let top_nodes = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let next_nodes = match groups.get(next_rank) {
      Some(list) => list
      None => []
    }
    let mut max_slot = next_nodes.length()
    for top in top_nodes {
      let outs = match edge_out.get(top) {
        Some(list) => list
        None => []
      }
      for edge_idx in outs {
        let head = edge_head[edge_idx]
        if ranks.get(head) != Some(next_rank) {
          continue
        }
        let penalty = edge_penalty[edge_idx]
        if penalty <= 0 {
          continue
        }
        let inv =
          match order.get(head) {
            Some(value) => value
            None =>
              match fixed_order.get(head) {
                Some(value) => value
                None => continue
              }
          }
        if inv < 0 {
          continue
        }
        if inv > max_slot {
          max_slot = inv
        }
      }
    }
    // Graphviz parity with fixed external slots: local rank slices may carry
    // sparse slot indices, so the counting array must follow max slot.
    let count = Array::make(max_slot + 1, 0)
    let mut max_order = 0
    for top in top_nodes {
      let outs = match edge_out.get(top) {
        Some(list) => list
        None => []
      }
      if max_order > 0 {
        for edge_idx in outs {
          let head = edge_head[edge_idx]
          if ranks.get(head) != Some(next_rank) {
            continue
          }
          let inv =
            match order.get(head) {
              Some(value) => value
              None =>
                match fixed_order.get(head) {
                  Some(value) => value
                  None => continue
                }
            }
          if inv < 0 {
            continue
          }
          let penalty = edge_penalty[edge_idx]
          if penalty <= 0 {
            continue
          }
          let mut k = inv + 1
          while k <= max_order {
            rank_cross = rank_cross + count[k] * penalty
            k = k + 1
          }
        }
      }
      for edge_idx in outs {
        let head = edge_head[edge_idx]
        if ranks.get(head) != Some(next_rank) {
          continue
        }
        let inv =
          match order.get(head) {
            Some(value) => value
            None =>
              match fixed_order.get(head) {
                Some(value) => value
                None => continue
              }
          }
        if inv < 0 {
          continue
        }
        let penalty = edge_penalty[edge_idx]
        if penalty <= 0 {
          continue
        }
        if inv > max_order {
          max_order = inv
        }
        count[inv] = count[inv] + penalty
      }
    }
    if include_ports {
      for top in top_nodes {
        rank_cross =
          rank_cross +
          local_cross_out_port_aware(
            top,
            next_rank,
            ranks,
            order,
            edge_out,
            edge_head,
            edge_tail_port_x,
            edge_penalty,
          )
      }
      for bottom in next_nodes {
        rank_cross =
          rank_cross +
          local_cross_in_port_aware(
            bottom,
            rank,
            ranks,
            order,
            edge_in,
            edge_tail,
            edge_head_port_x,
            edge_penalty,
          )
      }
    }
    crossings = crossings + rank_cross
    idx = idx + 1
  }
  crossings
}

///|
fn count_pairs_greater(left : Array[Int], right : Array[Int]) -> Int {
  if left.length() == 0 || right.length() == 0 {
    return 0
  }
  let mut count = 0
  let mut j = 0
  for i in 0..<left.length() {
    let l = left[i]
    while j < right.length() && right[j] < l {
      j = j + 1
    }
    count = count + j
  }
  count
}

///|
fn build_neighbor_order_index(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
  target_rank : Int,
) -> Map[String, Array[Int]] {
  let result : Map[String, Array[Int]] = Map::new()
  for name in names {
    let orders : Array[Int] = []
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    for neighbor in list {
      if ranks.get(neighbor) != Some(target_rank) {
        continue
      }
      match order.get(neighbor) {
        Some(idx) => orders.push(idx)
        None => ()
      }
    }
    if orders.length() > 1 {
      orders.sort()
    }
    result[name] = orders
  }
  result
}

///|
fn crossing_for_pair(
  left : String,
  right : String,
  parent_orders : Map[String, Array[Int]],
  child_orders : Map[String, Array[Int]],
) -> Int {
  let left_parents = match parent_orders.get(left) {
    Some(value) => value
    None => []
  }
  let right_parents = match parent_orders.get(right) {
    Some(value) => value
    None => []
  }
  let left_children = match child_orders.get(left) {
    Some(value) => value
    None => []
  }
  let right_children = match child_orders.get(right) {
    Some(value) => value
    None => []
  }
  count_pairs_greater(left_parents, right_parents) +
    count_pairs_greater(left_children, right_children)
}
