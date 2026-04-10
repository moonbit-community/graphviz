// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
const LARGE_SORT_THRESHOLD : Int = 128

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
    let is_vnode = @edge_identity.is_edge_vnode_name(name)
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
      if diff < 0.0 {
        -1
      } else {
        1
      }
    } else if a.is_vnode != b.is_vnode {
      if a.is_vnode {
        -1
      } else {
        1
      }
    } else if a.degree != b.degree {
      if a.degree > b.degree {
        -1
      } else {
        1
      }
    } else if a.ported != b.ported {
      if a.ported {
        -1
      } else {
        1
      }
    } else if a.secondary != b.secondary {
      if a.secondary > b.secondary {
        -1
      } else {
        1
      }
    } else if a.penalty != b.penalty {
      if a.penalty > b.penalty {
        -1
      } else {
        1
      }
    } else if a.node_order != b.node_order {
      if reverse_ties {
        if a.node_order < b.node_order {
          1
        } else {
          -1
        }
      } else if a.node_order < b.node_order {
        -1
      } else {
        1
      }
    } else if a.original_index != b.original_index {
      if reverse_ties {
        if a.original_index < b.original_index {
          1
        } else {
          -1
        }
      } else if a.original_index < b.original_index {
        -1
      } else {
        1
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
    let is_vnode = @edge_identity.is_edge_vnode_name(name)
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
      if diff < 0.0 {
        -1
      } else {
        1
      }
    } else {
      let port_cmp = match a.port_order {
        Some(a_port) =>
          match b.port_order {
            Some(b_port) =>
              if a_port != b_port {
                if a_port < b_port {
                  -1
                } else {
                  1
                }
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
        if a.is_vnode {
          -1
        } else {
          1
        }
      } else if a.degree != b.degree {
        if a.degree > b.degree {
          -1
        } else {
          1
        }
      } else if a.ported != b.ported {
        if a.ported {
          -1
        } else {
          1
        }
      } else if a.secondary != b.secondary {
        if a.secondary > b.secondary {
          -1
        } else {
          1
        }
      } else if a.penalty != b.penalty {
        if a.penalty > b.penalty {
          -1
        } else {
          1
        }
      } else if a.ported && b.ported && a.node_order != b.node_order {
        if reverse_ties {
          if a.node_order < b.node_order {
            1
          } else {
            -1
          }
        } else if a.node_order < b.node_order {
          -1
        } else {
          1
        }
      } else {
        match a.rank_same_group {
          Some(group) =>
            match b.rank_same_group {
              Some(other_group) =>
                if group == other_group &&
                  a.rank_same_order != b.rank_same_order {
                  if a.rank_same_order < b.rank_same_order {
                    -1
                  } else {
                    1
                  }
                } else if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order {
                      1
                    } else {
                      -1
                    }
                  } else if a.node_order < b.node_order {
                    -1
                  } else {
                    1
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index {
                      1
                    } else {
                      -1
                    }
                  } else if a.original_index < b.original_index {
                    -1
                  } else {
                    1
                  }
                } else {
                  0
                }
              None =>
                if a.node_order != b.node_order {
                  if reverse_ties {
                    if a.node_order < b.node_order {
                      1
                    } else {
                      -1
                    }
                  } else if a.node_order < b.node_order {
                    -1
                  } else {
                    1
                  }
                } else if a.original_index != b.original_index {
                  if reverse_ties {
                    if a.original_index < b.original_index {
                      1
                    } else {
                      -1
                    }
                  } else if a.original_index < b.original_index {
                    -1
                  } else {
                    1
                  }
                } else {
                  0
                }
            }
          None =>
            if a.node_order != b.node_order {
              if reverse_ties {
                if a.node_order < b.node_order {
                  1
                } else {
                  -1
                }
              } else if a.node_order < b.node_order {
                -1
              } else {
                1
              }
            } else if a.original_index != b.original_index {
              if reverse_ties {
                if a.original_index < b.original_index {
                  1
                } else {
                  -1
                }
              } else if a.original_index < b.original_index {
                -1
              } else {
                1
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
pub fn sort_by_positions(
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
      sorted, desired, x_positions, primary, secondary, node_penalty, port_edge_nodes,
      node_order, rank_same_groups, rank_same_order, port_order_positions, reverse_ties,
    )
  }
  if sorted.length() >= 64 &&
    !has_port_order &&
    !has_rank_same &&
    !has_ported_nodes {
    return sort_by_positions_fast(
      sorted, desired, x_positions, primary, secondary, node_penalty, port_edge_nodes,
      node_order, reverse_ties,
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
        let prev_vnode = @edge_identity.is_edge_vnode_name(prev)
        let current_vnode = @edge_identity.is_edge_vnode_name(current)
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
                  let keep_order = if reverse_ties {
                    prev_idx >= current_idx
                  } else {
                    prev_idx <= current_idx
                  }
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
                            let current_idx = match
                              rank_same_order.get(current) {
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
                            let keep_order = if reverse_ties {
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
pub fn median_value(values : Array[Double]) -> Double? {
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
pub fn median_value_mc_scale(values : Array[Double]) -> Double? {
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
    let weighted = scaled[lm].to_double() * rspan.to_double() +
      scaled[rm].to_double() * lspan.to_double()
    Some(weighted / (lspan + rspan).to_double() / scale)
  }
}

///|
fn left2right_constraint_resolved(
  left : String,
  right : String,
  left_cluster : String,
  right_cluster : String,
  left_skel : Bool,
  right_skel : Bool,
  flat_constraints : Map[String, Bool],
  remincross_mode : Bool,
) -> Bool {
  if remincross_mode {
    // Graphviz parity: in ReMincross, nodes in different buckets are pinned.
    if left_cluster != right_cluster {
      return true
    }
  }
  if left_cluster != "" && right_cluster != "" && left_cluster != right_cluster {
    if !left_skel && !right_skel {
      return true
    }
  }
  let key = "\{left}|\{right}"
  flat_constraints.get(key) == Some(true)
}

///|
pub fn left2right_constraint(
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
  left2right_constraint_resolved(
    left,
    right,
    left_cluster,
    right_cluster,
    cluster_skeleton.get(left) == Some(true),
    cluster_skeleton.get(right) == Some(true),
    flat_constraints,
    remincross_mode,
  )
}
