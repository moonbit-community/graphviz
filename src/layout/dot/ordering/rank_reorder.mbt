///|
pub fn order_rank_by_cluster(
  names : Array[String],
  desired : Map[String, Double],
  x_positions : Map[String, Double],
  primary : Map[String, Array[String]],
  secondary : Map[String, Array[String]],
  node_penalty : Map[String, Int],
  parents_map : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  edge_pair_order : Map[String, Int],
  port_order_positions : Map[String, Double],
  reverse_ties : Bool,
) -> Array[String] {
  if names.length() < 2 {
    return names.copy()
  }
  let group_keys : Array[String] = []
  let group_nodes : Array[Array[String]] = []
  let group_order : Array[Int] = []
  let group_index : Map[String, Int] = Map::new()
  let mut next_index = 0
  for name in names {
    let cluster_key = match cluster_keys.get(name) {
      Some(value) => value
      None => ""
    }
    let group_key = if cluster_key == "" { name } else { cluster_key }
    let idx = match group_index.get(group_key) {
      Some(value) => value
      None => {
        let index = next_index
        next_index = next_index + 1
        group_index[group_key] = index
        group_keys.push(group_key)
        group_nodes.push([])
        group_order.push(index)
        index
      }
    }
    group_nodes[idx].push(name)
  }
  let group_values : Array[Double] = []
  let group_secondary : Array[Int] = []
  for i in 0..<group_nodes.length() {
    let values : Array[Double] = []
    let mut secondary_total = 0
    for name in group_nodes[i] {
      match desired.get(name) {
        Some(value) => values.push(value)
        None =>
          match x_positions.get(name) {
            Some(value) => values.push(value)
            None => ()
          }
      }
      match secondary.get(name) {
        Some(list) => secondary_total = secondary_total + list.length()
        None => ()
      }
    }
    let value = match median_value(values) {
      Some(val) => val
      None => 0.0
    }
    group_values.push(value)
    group_secondary.push(secondary_total)
  }
  let order : Array[Int] = []
  for i in 0..<group_nodes.length() {
    order.push(i)
  }
  let mut i = 1
  while i < order.length() {
    let current = order[i]
    let current_val = group_values[current]
    let mut j = i
    while j > 0 {
      let prev = order[j - 1]
      let prev_val = group_values[prev]
      if prev_val < current_val {
        break
      }
      if prev_val == current_val {
        let prev_secondary = group_secondary[prev]
        let current_secondary = group_secondary[current]
        if prev_secondary < current_secondary {
          // move current left
        } else if prev_secondary > current_secondary {
          break
        } else {
          let keep_order =
            if reverse_ties {
              group_order[prev] >= group_order[current]
            } else {
              group_order[prev] <= group_order[current]
            }
          if keep_order {
            break
          }
        }
      }
      order[j] = prev
      j = j - 1
    }
    order[j] = current
    i = i + 1
  }
  let result : Array[String] = []
  for idx in order {
    let group = group_nodes[idx]
    let ordered_group = sort_by_positions(
      group, desired, x_positions, primary, secondary, node_penalty, parents_map,
      rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
      edge_pair_order, port_order_positions,
      reverse_ties,
    )
    for name in ordered_group {
      result.push(name)
    }
  }
  result
}

pub fn reorder_by_medians(
  names : Array[String],
  desired : Map[String, Double],
  reverse : Bool,
  hasfixed : Bool,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  remincross_mode? : Bool = false,
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let mut ep = sorted.length()
  let mut nelt = sorted.length() - 1
  while nelt >= 0 {
    let mut lp = 0
    while lp < ep {
      while lp < ep && desired.get(sorted[lp]) is None {
        lp = lp + 1
      }
      if lp >= ep {
        break
      }
      let mut rp = lp + 1
      let mut muststay = false
      let mut sawclust = false
      while rp < ep {
        let mut rp_cluster = ""
        match cluster_keys.get(sorted[rp]) {
          Some(value) => rp_cluster = value
          None => ()
        }
        if sawclust && rp_cluster != "" {
          rp = rp + 1
          continue
        }
        if left2right_constraint(
          sorted[lp],
          sorted[rp],
          cluster_keys,
          cluster_skeleton,
          flat_constraints,
          remincross_mode=remincross_mode,
        ) {
          muststay = true
          break
        }
        if desired.get(sorted[rp]) is Some(_) {
          break
        }
        if rp_cluster != "" {
          sawclust = true
        }
        rp = rp + 1
      }
      if rp >= ep {
        break
      }
      if !muststay {
        let p1 = match desired.get(sorted[lp]) {
          Some(value) => value
          None => -1.0
        }
        let p2 = match desired.get(sorted[rp]) {
          Some(value) => value
          None => -1.0
        }
        if p1 > p2 || (p1 >= p2 && reverse) {
          let tmp = sorted[lp]
          sorted[lp] = sorted[rp]
          sorted[rp] = tmp
        }
      }
      lp = rp
    }
    if !hasfixed && !reverse {
      ep = ep - 1
    }
    nelt = nelt - 1
  }
  sorted
}

pub fn compute_desired_positions(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  x_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    match preferred_positions.get(name) {
      Some(value) => {
        desired[name] = value
        continue
      }
      None => ()
    }
    match port_order_contrib.get(name) {
      Some(list) => {
        let mut sum = 0.0
        let mut count = 0
        for entry in list {
          let (anchor, offset) = entry
          match x_positions.get(anchor) {
            Some(anchor_pos) => {
              sum = sum + anchor_pos + offset
              count = count + 1
            }
            None => ()
          }
        }
        if count > 0 {
          desired[name] = sum / count.to_double()
          continue
        }
      }
      None => ()
    }
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for neighbor in list {
      match x_positions.get(neighbor) {
        Some(value) => values.push(value)
        None => ()
      }
    }
    match median_value(values) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|
pub fn compute_scaled_medians(
  names : Array[String],
  neighbors : Map[String, Array[(String, Double)]],
  x_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
    let list = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    let values : Array[Double] = []
    for entry in list {
      let (neighbor, port_order) = entry
      match x_positions.get(neighbor) {
        Some(value) => values.push(value + port_order)
        None => ()
      }
    }
    match median_value_mc_scale(values) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

fn transpose_rank(
  rank : Int,
  names : Array[String],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  order : Map[String, Int],
  reverse : Bool,
) -> Bool {
  let mut changed = false
  let parent_orders =
    build_neighbor_order_index(names, parents, ranks, order, rank - 1)
  let child_orders =
    build_neighbor_order_index(names, children, ranks, order, rank + 1)
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    let c0 = crossing_for_pair(
      left, right, parent_orders, child_orders,
    )
    let c1 = crossing_for_pair(
      right, left, parent_orders, child_orders,
    )
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      names[i] = right
      names[i + 1] = left
      order[left] = i + 1
      order[right] = i
      changed = true
    }
    i = i + 1
  }
  changed
}

///|
pub fn transpose_rank_groups_limited(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  ranks : Map[String, Int],
  reverse : Bool,
  max_passes : Int,
) -> Bool {
  let mut changed_any = false
  let mut changed = true
  let mut passes = 0
  while changed {
    if passes >= max_passes {
      break
    }
    passes = passes + 1
    changed = false
    let order = build_order_index(ordered)
    for rank in rank_keys {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() < 2 {
        continue
      }
      if transpose_rank(rank, names, parents, children, ranks, order, reverse) {
        ordered[rank] = names
        changed = true
        changed_any = true
      }
    }
  }
  changed_any
}
