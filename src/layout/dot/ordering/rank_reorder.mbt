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

///|
/// Graphviz parity: port x tie-break matches mincross.c in_cross.
fn in_cross_port_tiebreak(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  fixed_order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_tail_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> Int {
  let _ = rank
  let _ = ranks
  let right_in = match edge_in.get(right) {
    Some(value) => value
    None => []
  }
  let left_in = match edge_in.get(left) {
    Some(value) => value
    None => []
  }
  let mut cross = 0
  for edge_idx in right_in {
    let cnt = edge_penalty[edge_idx]
    if cnt <= 0 {
      continue
    }
    let inv = match order.get(edge_tail[edge_idx]) {
      Some(value) => value
      None =>
        match fixed_order.get(edge_tail[edge_idx]) {
          Some(value) => value
          None => 0
        }
    }
    let inv_port =
      if edge_idx < edge_tail_port_x.length() { edge_tail_port_x[edge_idx] } else {
        0.0
      }
    for edge_idx2 in left_in {
      let weight = edge_penalty[edge_idx2]
      if weight <= 0 {
        continue
      }
      let tail_order = match order.get(edge_tail[edge_idx2]) {
        Some(value) => value
        None =>
          match fixed_order.get(edge_tail[edge_idx2]) {
            Some(value) => value
            None => 0
          }
      }
      let t = tail_order - inv
      let tail_port =
        if edge_idx2 < edge_tail_port_x.length() { edge_tail_port_x[edge_idx2] } else {
          0.0
        }
      if t > 0 || (t == 0 && tail_port > inv_port) {
        cross = cross + weight * cnt
      }
    }
  }
  cross
}

///|
/// Graphviz parity: port x tie-break matches mincross.c out_cross.
fn out_cross_port_tiebreak(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  fixed_order : Map[String, Int],
  edge_out : Map[String, Array[Int]],
  edge_head : Array[String],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> Int {
  let _ = rank
  let _ = ranks
  let right_out = match edge_out.get(right) {
    Some(value) => value
    None => []
  }
  let left_out = match edge_out.get(left) {
    Some(value) => value
    None => []
  }
  let mut cross = 0
  for edge_idx in right_out {
    let cnt = edge_penalty[edge_idx]
    if cnt <= 0 {
      continue
    }
    let inv = match order.get(edge_head[edge_idx]) {
      Some(value) => value
      None =>
        match fixed_order.get(edge_head[edge_idx]) {
          Some(value) => value
          None => 0
        }
    }
    let inv_port =
      if edge_idx < edge_head_port_x.length() { edge_head_port_x[edge_idx] } else {
        0.0
      }
    for edge_idx2 in left_out {
      let weight = edge_penalty[edge_idx2]
      if weight <= 0 {
        continue
      }
      let head_order = match order.get(edge_head[edge_idx2]) {
        Some(value) => value
        None =>
          match fixed_order.get(edge_head[edge_idx2]) {
            Some(value) => value
            None => 0
          }
      }
      let t = head_order - inv
      let head_port =
        if edge_idx2 < edge_head_port_x.length() { edge_head_port_x[edge_idx2] } else {
          0.0
        }
      if t > 0 || (t == 0 && head_port > inv_port) {
        cross = cross + weight * cnt
      }
    }
  }
  cross
}

///|
pub fn count_rank_crossings_port(
  rank : Int,
  names : Array[String],
  ranks : Map[String, Int],
  fixed_order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> Int {
  let order : Map[String, Int] = Map::new()
  for i, name in names {
    order[name] = i
  }
  let mut cross = 0
  let mut left_idx = 0
  while left_idx + 1 < names.length() {
    let left = names[left_idx]
    let mut right_idx = left_idx + 1
    while right_idx < names.length() {
      let right = names[right_idx]
      cross = cross + in_cross_port_tiebreak(
        left,
        right,
        rank,
        ranks,
        order,
        fixed_order,
        edge_in,
        edge_tail,
        edge_tail_port_x,
        edge_penalty,
      )
      cross = cross + out_cross_port_tiebreak(
        left,
        right,
        rank,
        ranks,
        order,
        fixed_order,
        edge_out,
        edge_head,
        edge_head_port_x,
        edge_penalty,
      )
      right_idx = right_idx + 1
    }
    left_idx = left_idx + 1
  }
  cross
}

///|
pub fn has_single_rank_incidents(
  names : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_penalty : Array[Int],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
) -> Bool {
  let rank_nodes : Map[String, Bool] = Map::new()
  for name in names {
    rank_nodes[name] = true
  }
  for edge_idx in 0..<edge_tail.length() {
    let penalty =
      if edge_idx < edge_penalty.length() { edge_penalty[edge_idx] } else { 0 }
    if penalty <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_in = rank_nodes.get(tail) is Some(_)
    let head_in = rank_nodes.get(head) is Some(_)
    if tail_in == head_in {
      continue
    }
    let other = if tail_in { head } else { tail }
    if !is_edge_vnode_name(other) && !other.has_prefix("_mbt_cluster_skel_") {
      return true
    }
  }
  for name in names {
    let out_neighbors = match graphviz_out_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    for other in out_neighbors {
      if rank_nodes.get(other) is Some(_) {
        continue
      }
      if !is_edge_vnode_name(other) && !other.has_prefix("_mbt_cluster_skel_") {
        return true
      }
    }
    let in_neighbors = match graphviz_in_neighbors.get(name) {
      Some(list) => list
      None => []
    }
    for other in in_neighbors {
      if rank_nodes.get(other) is Some(_) {
        continue
      }
      if !is_edge_vnode_name(other) && !other.has_prefix("_mbt_cluster_skel_") {
        return true
      }
    }
  }
  false
}

///|
priv struct TransposeRankResult {
  delta : Int
  changed : Bool
}

///|
fn transpose_rank_port_tiebreak(
  rank : Int,
  ranks : Map[String, Int],
  names : Array[String],
  order : Map[String, Int],
  fixed_order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  reverse : Bool,
  remincross_mode : Bool,
) -> TransposeRankResult {
  let mut changed = false
  let mut delta = 0
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    if left2right_constraint(
      left,
      right,
      cluster_keys,
      cluster_skeleton,
      flat_constraints,
      remincross_mode=remincross_mode,
    ) {
      i = i + 1
      continue
    }
    let mut c0 = 0
    let mut c1 = 0
    c0 = c0 + in_cross_port_tiebreak(
      left,
      right,
      rank,
      ranks,
      order,
      fixed_order,
      edge_in,
      edge_tail,
      edge_tail_port_x,
      edge_penalty,
    )
    c1 = c1 + in_cross_port_tiebreak(
      right,
      left,
      rank,
      ranks,
      order,
      fixed_order,
      edge_in,
      edge_tail,
      edge_tail_port_x,
      edge_penalty,
    )
    c0 = c0 + out_cross_port_tiebreak(
      left,
      right,
      rank,
      ranks,
      order,
      fixed_order,
      edge_out,
      edge_head,
      edge_head_port_x,
      edge_penalty,
    )
    c1 = c1 + out_cross_port_tiebreak(
      right,
      left,
      rank,
      ranks,
      order,
      fixed_order,
      edge_out,
      edge_head,
      edge_head_port_x,
      edge_penalty,
    )
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      names[i] = right
      names[i + 1] = left
      order[left] = i + 1
      order[right] = i
      changed = true
      delta = delta + (c0 - c1)
    }
    i = i + 1
  }
  { delta, changed }
}

///|
pub fn transpose_rank_groups_port(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  ranks : Map[String, Int],
  fixed_order? : Map[String, Int] = Map::new(),
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  reverse : Bool,
  max_passes : Int,
  remincross_mode? : Bool = false,
) -> Bool {
  let mut changed_any = false
  let mut passes = 0
  let rank_len = rank_keys.length()
  let candidate = Array::make(rank_len, true)
  while true {
    if max_passes > 0 && passes >= max_passes {
      break
    }
    passes = passes + 1
    let order = build_order_index(ordered)
    let mut delta = 0
    let mut idx = 0
    while idx < rank_len {
      if !candidate[idx] {
        idx = idx + 1
        continue
      }
      candidate[idx] = false
      let rank = rank_keys[idx]
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      if names.length() < 2 {
        idx = idx + 1
        continue
      }
      let transpose_result = transpose_rank_port_tiebreak(
        rank,
        ranks,
        names,
        order,
        fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        reverse,
        remincross_mode,
      )
      if transpose_result.changed {
        ordered[rank] = names
        changed_any = true
        candidate[idx] = true
        if idx > 0 {
          candidate[idx - 1] = true
        }
        if idx + 1 < rank_len {
          candidate[idx + 1] = true
        }
      }
      delta = delta + transpose_result.delta
      idx = idx + 1
    }
    if delta < 1 {
      break
    }
  }
  changed_any
}

///|
/// Graphviz parity: medians() assigns flat_mval for nodes with no in/out
/// non-flat edges (mincross.c flat_mval + medians).
pub fn apply_flat_mvals(
  names : Array[String],
  desired : Map[String, Double],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  flat_constraints : Map[String, Bool],
) -> Bool {
  let order_index : Map[String, Int] = Map::new()
  let rank_nodes : Map[String, Bool] = Map::new()
  for i, name in names {
    order_index[name] = i
    rank_nodes[name] = true
  }
  let flat_in : Map[String, Array[String]] = Map::new()
  let flat_out : Map[String, Array[String]] = Map::new()
  for name in names {
    flat_in[name] = []
    flat_out[name] = []
  }
  for key, enabled in flat_constraints {
    if !enabled {
      continue
    }
    match @shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if tail == "" || head == "" {
          continue
        }
        if rank_nodes.get(tail) is Some(_) && rank_nodes.get(head) is Some(_) {
          match flat_out.get(tail) {
            Some(list) => list.push(head)
            None => flat_out[tail] = [head]
          }
          match flat_in.get(head) {
            Some(list) => list.push(tail)
            None => flat_in[head] = [tail]
          }
        }
      }
      None => ()
    }
  }
  let mc_eps = 1.0 / 256.0
  let mut hasfixed = false
  for name in names {
    let in_edges = match edge_in.get(name) {
      Some(list) => list
      None => []
    }
    let out_edges = match edge_out.get(name) {
      Some(list) => list
      None => []
    }
    if in_edges.length() > 0 || out_edges.length() > 0 {
      continue
    }
    let in_list = match flat_in.get(name) {
      Some(list) => list
      None => []
    }
    let mut assigned = false
    if in_list.length() > 0 {
      let mut chosen = in_list[0]
      let mut chosen_idx = match order_index.get(chosen) {
        Some(value) => value
        None => -1
      }
      let mut i = 1
      while i < in_list.length() {
        let candidate = in_list[i]
        let candidate_idx = match order_index.get(candidate) {
          Some(value) => value
          None => -1
        }
        if candidate_idx > chosen_idx {
          chosen = candidate
          chosen_idx = candidate_idx
        }
        i = i + 1
      }
      match desired.get(chosen) {
        Some(value) => {
          desired[name] = value + mc_eps
          assigned = true
        }
        None => ()
      }
    } else {
      let out_list = match flat_out.get(name) {
        Some(list) => list
        None => []
      }
      if out_list.length() > 0 {
        let mut chosen = out_list[0]
        let mut chosen_idx = match order_index.get(chosen) {
          Some(value) => value
          None => 0x7fffffff
        }
        let mut i = 1
        while i < out_list.length() {
          let candidate = out_list[i]
          let candidate_idx = match order_index.get(candidate) {
            Some(value) => value
            None => 0x7fffffff
          }
          if candidate_idx < chosen_idx {
            chosen = candidate
            chosen_idx = candidate_idx
          }
          i = i + 1
        }
        match desired.get(chosen) {
          Some(value) => {
            if value > 0.0 {
              desired[name] = value - mc_eps
              assigned = true
            }
          }
          None => ()
        }
      }
    }
    if !assigned {
      hasfixed = true
    }
  }
  hasfixed
}

///|
/// Graphviz parity: flat edge reorder aligned to refs/graphviz/lib/dotgen/flat.c.
/// Do not change behavior without updating fixtures/tests.
pub fn flat_reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  node_ranks : Map[String, Int],
  flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let ordered = clone_rank_groups(groups)
  if flat_constraints.length() == 0 {
    return ordered
  }
  let flat_out : Map[String, Array[String]] = Map::new()
  let flat_in : Map[String, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      flat_out[name] = []
      flat_in[name] = []
    }
  }
  for key, value in flat_constraints {
    if !value {
      continue
    }
    match @shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if tail == "" || head == "" {
          continue
        }
        let tail_rank = match node_ranks.get(tail) {
          Some(value) => value
          None => continue
        }
        let head_rank = match node_ranks.get(head) {
          Some(value) => value
          None => continue
        }
        if tail_rank != head_rank {
          continue
        }
        match flat_out.get(tail) {
          Some(list) => list.push(head)
          None => flat_out[tail] = [head]
        }
        match flat_in.get(head) {
          Some(list) => list.push(tail)
          None => flat_in[head] = [tail]
        }
      }
      None => ()
    }
  }
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    if names.length() <= 1 {
      continue
    }
    let mut has_flat = false
    for name in names {
      let out = match flat_out.get(name) {
        Some(list) => list
        None => []
      }
      let inn = match flat_in.get(name) {
        Some(list) => list
        None => []
      }
      if out.length() > 0 || inn.length() > 0 {
        has_flat = true
        break
      }
    }
    if !has_flat {
      continue
    }
    let marked : Map[String, Bool] = Map::new()
    for name in names {
      marked[name] = false
    }
    let temprank : Array[String] = []
    let postorder = (start : String) => {
      let stack : Array[(String, Int)] = [(start, 0)]
      while stack.length() > 0 {
        let top_idx = stack.length() - 1
        let (current, idx) = stack[top_idx]
        if marked.get(current) != Some(true) {
          marked[current] = true
        }
        let out = match flat_out.get(current) {
          Some(list) => list
          None => []
        }
        if idx >= out.length() {
          let _ = stack.pop()
          temprank.push(current)
          continue
        }
        let next = out[idx]
        stack[top_idx] = (current, idx + 1)
        if marked.get(next) != Some(true) {
          stack.push((next, 0))
        }
      }
    }
    let mut i = 0
    while i < names.length() {
      let v =
        if graphviz_flip {
          names[i]
        } else {
          names[names.length() - i - 1]
        }
      let local_in = match flat_in.get(v) {
        Some(list) => list
        None => []
      }
      let local_out = match flat_out.get(v) {
        Some(list) => list
        None => []
      }
      if local_in.length() == 0 && local_out.length() == 0 {
        temprank.push(v)
      } else if marked.get(v) != Some(true) && local_in.length() == 0 {
        postorder(v)
      }
      i = i + 1
    }
    if temprank.length() == 0 {
      continue
    }
    let reordered : Array[String] =
      if graphviz_flip {
        temprank
      } else {
        let reversed : Array[String] = []
        let mut idx = temprank.length()
        while idx > 0 {
          idx = idx - 1
          reversed.push(temprank[idx])
        }
        reversed
      }
    if reordered.length() < names.length() {
      let seen : Map[String, Bool] = Map::new()
      for name in reordered {
        seen[name] = true
      }
      let updated = reordered.copy()
      for name in names {
        if seen.get(name) is None {
          updated.push(name)
        }
      }
      ordered[rank] = updated
    } else {
      ordered[rank] = reordered
    }
  }
  ordered
}


///|
pub let capture_pass0_flat_seed_groups_enabled : Ref[Bool] = Ref::new(false)

///|
pub let capture_pass0_flat_seed_groups_value : Ref[Map[Int, Array[String]]?] = Ref::new(None)

///|
fn maybe_capture_seed_groups(
  pass : Int,
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
) -> Unit {
  if !capture_pass0_flat_seed_groups_enabled.val || pass != 0 {
    return
  }
  if capture_pass0_flat_seed_groups_value.val is Some(_) {
    return
  }
  let snapshot : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    snapshot[rank] = names
  }
  capture_pass0_flat_seed_groups_value.val = Some(snapshot)
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/mincross.c and flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  parents : Map[String, Array[String]],
  children : Map[String, Array[String]],
  cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  edge_order : Map[String, Int],
  node_order : Map[String, Int],
  sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  preferred_positions : Map[String, Double],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_out_neighbors? : Map[String, Array[String]] = Map::new(),
  graphviz_in_neighbors? : Map[String, Array[String]] = Map::new(),
  fixed_positions? : Map[String, Double] = Map::new(),
  fixed_ranks? : Map[String, Int] = Map::new(),
  graphviz_flip? : Bool = false,
  coalesce_parallel_edges? : Bool = false,
  startpass? : Int = 0,
  startpass_init_infinite? : Bool = false,
  remincross_mode? : Bool = false,
) -> Map[Int, Array[String]] {
  let _ = sizes
  let _ = nodesep_pt
  let _ = has_edge_labels
  let startpass =
    if startpass < 0 { 0 } else if startpass > 2 { 2 } else { startpass }
  let mut ordered : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list.copy()
      None => []
    }
    ordered[rank] = names
  }
  let rank_sizes : Map[Int, Int] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    rank_sizes[rank] = names.length()
  }
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = @shared.port_is_explicit(edge.tail_port()) ||
      @shared.port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  let edge_pair_order : Map[String, Int] = Map::new()
  let mut edge_idx = 0
  for _edge in edges {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    edge_pair_order["\{tail}|\{head}"] = edge_idx
    edge_idx = edge_idx + 1
  }
  let node_penalty : Map[String, Int] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = @shared.edge_xpenalty(edge)
    if penalty <= 0 {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let tail_sum = match node_penalty.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_sum = match node_penalty.get(head) {
      Some(value) => value
      None => 0
    }
    node_penalty[tail] = tail_sum + penalty
    node_penalty[head] = head_sum + penalty
  }
  let node_ranks = build_node_ranks(ordered)
  // Graphviz parity: cluster-local mincross uses merged rank map including
  // virtual nodes that may not be in the local rank groups.
  for name, rank in fixed_ranks {
    if node_ranks.get(name) is None {
      node_ranks[name] = rank
    }
  }
  let mut best_ordered = clone_rank_groups(ordered)
  let mut order_positions = order_positions_from_groups(ordered)
  let fixed_order : Map[String, Int] = Map::new()
  for name, pos in fixed_positions {
    fixed_order[name] = pos.to_int()
  }
  let merge_fixed_positions = () => {
    // Graphviz parity: current ND_order snapshot (fixed_positions) must win.
    for name, pos in fixed_positions {
      if order_positions.get(name) is None {
        order_positions[name] = pos
      }
    }
    // Graphviz parity: startpass=2 median lookups may still reference names
    // missing from fixed_positions (e.g. fixture-only anchors).
    if startpass > 1 {
      for name, idx in node_order {
        if order_positions.get(name) is None {
          order_positions[name] = idx.to_double()
        }
      }
    }
  }
  merge_fixed_positions()
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_preferred = false
  for name, _ in preferred_positions {
    // Graphviz parity: vnode ordering hints should not disable
    // mincross graphviz-style passes.
    if !name.has_prefix(EDGE_VNODE_PREFIX) {
      has_preferred = true
      break
    }
  }
  // Graphviz parity: port order hints do not switch mincross out of
  // graphviz-style passes (mincross.c still uses in/out port x ties).
  let graphviz_style = !has_preferred
  let median_parents : Map[String, Array[(String, Double)]] = Map::new()
  let median_children : Map[String, Array[(String, Double)]] = Map::new()
  let edge_penalty : Array[Int] = []
  let edge_in : Map[String, Array[Int]] = Map::new()
  let edge_out : Map[String, Array[Int]] = Map::new()
  let mut has_graphviz_neighbor_hints = false
  let mut has_external_in_anchor = false
  let mut has_external_out_anchor = false
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      if graphviz_style {
        median_parents[name] = []
        median_children[name] = []
      }
      edge_in[name] = []
      edge_out[name] = []
    }
  }
  let coalesced_edge_index : Map[String, Int] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let base_penalty = @shared.edge_xpenalty(edge)
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let mut penalty = base_penalty
    if coalesce_parallel_edges && base_penalty > 0 && @shared.edge_is_constraint(edge) {
      let tail_port_order =
        if edge_idx < edge_tail_port_order.length() { edge_tail_port_order[edge_idx] } else {
          0.5
        }
      let head_port_order =
        if edge_idx < edge_head_port_order.length() { edge_head_port_order[edge_idx] } else {
          0.5
        }
      let merge_key =
        "\{tail}|\{head}|\{tail_port_order.to_string()}|\{head_port_order.to_string()}"
      match coalesced_edge_index.get(merge_key) {
        Some(first_idx) => {
          let prev = edge_penalty[first_idx]
          edge_penalty[first_idx] = prev + base_penalty
          penalty = 0
        }
        None => coalesced_edge_index[merge_key] = edge_idx
      }
    }
    edge_penalty.push(penalty)
    if penalty <= 0 || !@shared.edge_is_constraint(edge) {
      continue
    }
    let tail_rank = match node_ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match node_ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    if graphviz_style {
      // Graphviz parity: median neighbor positions include compass-port order
      // fractions (VAL/MC_SCALE tie-breaking in mincross.c).
      let tail_port_order =
        if edge_idx < edge_tail_port_order.length() { edge_tail_port_order[edge_idx] } else {
          0.5
        }
      let head_port_order =
        if edge_idx < edge_head_port_order.length() { edge_head_port_order[edge_idx] } else {
          0.5
        }
      match median_parents.get(head) {
        Some(list) => list.push((tail, tail_port_order))
        None => median_parents[head] = [(tail, tail_port_order)]
      }
      match median_children.get(tail) {
        Some(list) => list.push((head, head_port_order))
        None => median_children[tail] = [(head, head_port_order)]
      }
    }
    match edge_out.get(tail) {
      Some(list) => list.push(edge_idx)
      None => edge_out[tail] = [edge_idx]
    }
    match edge_in.get(head) {
      Some(list) => list.push(edge_idx)
      None => edge_in[head] = [edge_idx]
    }
  }
  if graphviz_style && startpass > 1 && rank_keys.length() <= 3 {
    for rank in rank_keys {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      for name in names {
        let in_neighbors = match graphviz_in_neighbors.get(name) {
          Some(list) => list
          None => []
        }
        if in_neighbors.length() > 0 {
          has_graphviz_neighbor_hints = true
          for other in in_neighbors {
            if node_ranks.get(other) is None {
              has_external_in_anchor = true
              break
            }
          }
          match median_parents.get(name) {
            Some(list) =>
              for other in in_neighbors {
                list.push((other, 0.0))
              }
            None =>
              if in_neighbors.length() > 0 {
                let list : Array[(String, Double)] = []
                for other in in_neighbors {
                  list.push((other, 0.0))
                }
                median_parents[name] = list
              }
          }
        }
        let out_neighbors = match graphviz_out_neighbors.get(name) {
          Some(list) => list
          None => []
        }
        if out_neighbors.length() > 0 {
          has_graphviz_neighbor_hints = true
          for other in out_neighbors {
            if node_ranks.get(other) is None {
              has_external_out_anchor = true
              break
            }
          }
          match median_children.get(name) {
            Some(list) =>
              for other in out_neighbors {
                list.push((other, 0.0))
              }
            None =>
              if out_neighbors.length() > 0 {
                let list : Array[(String, Double)] = []
                for other in out_neighbors {
                  list.push((other, 0.0))
                }
                median_children[name] = list
              }
          }
        }
      }
    }
  }
  // Graphviz parity: initial passes should always allow acceptance of
  // improved orderings before final crossing baseline is established.
  let mut best_cross =
    if graphviz_style && startpass > 1 && startpass_init_infinite {
    2147483647
  } else if graphviz_style && startpass <= 1 {
    2147483647
  } else if graphviz_style {
    count_crossings_port_aware(
      ordered,
      node_ranks,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x=edge_tail_port_x,
      edge_head_port_x=edge_head_port_x,
      fixed_order=fixed_order,
    )
  } else {
    count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if !graphviz_style && rank_keys.length() > 1 {
    ordered = build_component_rank_groups(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      0,
      flat_constraints,
      flip=graphviz_flip,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
    )
    ordered = flat_reorder_rank_groups(
      rank_keys,
      ordered,
      node_ranks,
      flat_constraints,
      graphviz_flip,
    )
    order_positions = order_positions_from_groups(ordered)
    merge_fixed_positions()
    let seed_cross =
      count_crossings_port_aware(
        ordered,
        node_ranks,
        edges,
        edge_tail,
        edge_head,
        edge_tail_port_x=edge_tail_port_x,
        edge_head_port_x=edge_head_port_x,
        fixed_order=fixed_order,
      )
    if seed_cross > 0 {
      let _ = transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order=fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
        remincross_mode=remincross_mode,
      )
      order_positions = order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    best_ordered = clone_rank_groups(ordered)
    best_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if graphviz_style && rank_keys.length() == 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
    let rank = rank_keys[0]
    let single_names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    if !has_single_rank_incidents(
      single_names,
      edge_tail,
      edge_head,
      edge_penalty,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
    ) {
      return ordered
    }
    let compute_single_cross = () => {
      let names = match ordered.get(rank) {
        Some(list) => list
        None => []
      }
      count_rank_crossings_port(
        rank,
        names,
        node_ranks,
        fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
      )
    }
    let mut force_single_rank_probe = false
    if startpass > 1 {
      best_cross = compute_single_cross()
      best_ordered = clone_rank_groups(ordered)
      if best_cross == 0 && has_graphviz_neighbor_hints {
        // Graphviz parity: ND_in/ND_out driven medians can still reorder even
        // when local crossing count is zero.
        force_single_rank_probe = true
        best_cross = 1
      }
    } else {
      best_cross = 2147483647
    }
    let mut cur_cross = best_cross
    let mut pass = startpass
    while pass <= 2 {
      let max_this_pass =
        if pass <= 1 {
        if max_iter < 4 { max_iter } else { 4 }
      } else {
        max_iter
      }
      if pass <= 1 {
        ordered = build_component_rank_groups(
          rank_keys,
          groups,
          edge_tail,
          edge_head,
          node_ranks,
          node_order,
          cluster_keys,
          cluster_skeleton,
          pass,
          flat_constraints,
          flip=graphviz_flip,
          graphviz_out_neighbors=graphviz_out_neighbors,
          graphviz_in_neighbors=graphviz_in_neighbors,
        )
        let seed_cross = compute_single_cross()
        if seed_cross > 0 {
          let _ = transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order=fixed_order,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_tail_port_x,
            edge_head_port_x,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            false,
            0,
            remincross_mode=remincross_mode,
          )
        }
        ordered = flat_reorder_rank_groups(
          rank_keys,
          ordered,
          node_ranks,
          flat_constraints,
          graphviz_flip,
        )
        maybe_capture_seed_groups(pass, rank_keys, ordered)
        order_positions = order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = compute_single_cross()
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
        }
      } else {
        if cur_cross > best_cross {
          for rank in rank_keys {
            let names = match best_ordered.get(rank) {
              Some(list) => list.copy()
              None => []
            }
            ordered[rank] = names
          }
          order_positions = order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        cur_cross = best_cross
      }
      let mut trying = 0
      let mut iter = 0
      let min_probe_iters = if force_single_rank_probe { 2 } else { 0 }
      while iter < max_this_pass {
        if trying >= min_quit || (cur_cross == 0 && iter >= min_probe_iters) {
          break
        }
        trying = trying + 1
        let reverse = iter % 4 < 2
        let names = match ordered.get(rank) {
          Some(list) => list
          None => []
        }
        if names.length() > 1 {
          let desired =
            if iter % 2 == 0 {
              compute_scaled_medians(
                names,
                median_parents,
                order_positions,
              )
            } else {
              compute_scaled_medians(
                names,
                median_children,
                order_positions,
              )
            }
          let hasfixed = apply_flat_mvals(
            names,
            desired,
            edge_in,
            edge_out,
            flat_constraints,
          )
          ordered[rank] = reorder_by_medians(
            names,
            desired,
            reverse,
            hasfixed,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            remincross_mode=remincross_mode,
          )
          order_positions = order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        let _ = transpose_rank_groups_port(
          rank_keys,
          ordered,
          node_ranks,
          fixed_order=fixed_order,
          edge_in,
          edge_out,
          edge_tail,
          edge_head,
          edge_tail_port_x,
          edge_head_port_x,
          edge_penalty,
          cluster_keys,
          cluster_skeleton,
          flat_constraints,
          !reverse,
          0,
          remincross_mode=remincross_mode,
        )
        order_positions = order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = compute_single_cross()
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
          if prev_best > 0 &&
            cur_cross.to_double() < convergence * prev_best.to_double() {
            trying = 0
          }
        }
        iter = iter + 1
      }
      if cur_cross == 0 {
        break
      }
      pass = pass + 1
    }
    if cur_cross > best_cross {
      for rank in rank_keys {
        let names = match best_ordered.get(rank) {
          Some(list) => list.copy()
          None => []
        }
        ordered[rank] = names
      }
      order_positions = order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    if best_cross > 0 {
      let _ = transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order=fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
        remincross_mode=remincross_mode,
      )
    }
    return ordered
  }
  if graphviz_style && rank_keys.length() > 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
    let mut force_graphviz_probe = false
    if startpass > 1 && rank_keys.length() <= 3 && best_cross == 0 &&
      has_graphviz_neighbor_hints {
      // Graphviz parity: ND_in/ND_out medians may drive reorder despite a
      // zero local crossing baseline.
      force_graphviz_probe = true
      best_cross = 1
    }
    let mut cur_cross = best_cross
    let mut pass = startpass
    while pass <= 2 {
      let max_this_pass =
        if pass <= 1 {
        if max_iter < 4 { max_iter } else { 4 }
      } else {
        max_iter
      }
      if pass <= 1 {
        ordered = build_component_rank_groups(
          rank_keys,
          groups,
          edge_tail,
          edge_head,
          node_ranks,
          node_order,
          cluster_keys,
          cluster_skeleton,
          pass,
          flat_constraints,
          flip=graphviz_flip,
          graphviz_out_neighbors=graphviz_out_neighbors,
          graphviz_in_neighbors=graphviz_in_neighbors,
        )
        // Graphviz parity: seed transpose probe runs before flat reorder in
        // each graphviz-style pass, independent of port-order hints.
        let seed_cross =
          count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if seed_cross > 0 {
          let _ = transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order=fixed_order,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_tail_port_x,
            edge_head_port_x,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            false,
            0,
            remincross_mode=remincross_mode,
          )
        }
        ordered = flat_reorder_rank_groups(
          rank_keys,
          ordered,
          node_ranks,
          flat_constraints,
          graphviz_flip,
        )
        maybe_capture_seed_groups(pass, rank_keys, ordered)
        order_positions = order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross =
          count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
        }
      } else {
        if cur_cross > best_cross {
          for rank in rank_keys {
            let names = match best_ordered.get(rank) {
              Some(list) => list.copy()
              None => []
            }
            ordered[rank] = names
          }
          order_positions = order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        cur_cross = best_cross
      }
      let mut trying = 0
      let mut iter = 0
      let min_probe_iters = if force_graphviz_probe { 2 } else { 0 }
      let use_full_rank_sweeps = force_graphviz_probe
      let include_min_rank = use_full_rank_sweeps || has_external_in_anchor
      let include_max_rank = use_full_rank_sweeps || has_external_out_anchor
      while iter < max_this_pass {
        if trying >= min_quit || (cur_cross == 0 && iter >= min_probe_iters) {
          break
        }
        trying = trying + 1
        let reverse = iter % 4 < 2
        let use_sweep_snapshot = startpass > 1 && pass > 1 &&
          has_graphviz_neighbor_hints && iter % 2 == 0
        let sweep_positions =
          if use_sweep_snapshot { order_positions.copy() } else { order_positions }
        if iter % 2 == 0 {
          let mut idx = if include_min_rank { 0 } else { 1 }
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired_positions =
                if use_sweep_snapshot { sweep_positions } else { order_positions }
              let desired = compute_scaled_medians(
                names,
                median_parents,
                desired_positions,
              )
              let hasfixed = apply_flat_mvals(
                names,
                desired,
                edge_in,
                edge_out,
                flat_constraints,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                hasfixed,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              if !use_sweep_snapshot {
                order_positions = order_positions_from_groups(ordered)
                merge_fixed_positions()
              }
            }
            idx = idx + 1
          }
        } else {
          let mut idx =
            if include_max_rank {
              rank_keys.length() - 1
            } else {
              rank_keys.length() - 2
            }
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired_positions =
                if use_sweep_snapshot { sweep_positions } else { order_positions }
              let desired = compute_scaled_medians(
                names,
                median_children,
                desired_positions,
              )
              let hasfixed = apply_flat_mvals(
                names,
                desired,
                edge_in,
                edge_out,
                flat_constraints,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                hasfixed,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              if !use_sweep_snapshot {
                order_positions = order_positions_from_groups(ordered)
                merge_fixed_positions()
              }
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if use_sweep_snapshot {
          order_positions = order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        // Graphviz parity: transpose remains active with port-order hints;
        // ties are resolved by in/out port x during crossing checks.
        let _ = transpose_rank_groups_port(
          rank_keys,
          ordered,
          node_ranks,
          fixed_order=fixed_order,
          edge_in,
          edge_out,
          edge_tail,
          edge_head,
          edge_tail_port_x,
          edge_head_port_x,
          edge_penalty,
          cluster_keys,
          cluster_skeleton,
          flat_constraints,
          !reverse,
          0,
          remincross_mode=remincross_mode,
        )
        order_positions = order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross =
          count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = clone_rank_groups(ordered)
          if prev_best > 0 &&
            cur_cross.to_double() < convergence * prev_best.to_double() {
            trying = 0
          }
        }
        iter = iter + 1
      }
      if cur_cross == 0 {
        break
      }
      pass = pass + 1
    }
    if cur_cross > best_cross {
      for rank in rank_keys {
        let names = match best_ordered.get(rank) {
          Some(list) => list.copy()
          None => []
        }
        ordered[rank] = names
      }
      order_positions = order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    if best_cross > 0 {
      let _ = transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order=fixed_order,
        edge_in,
        edge_out,
        edge_tail,
        edge_head,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
        cluster_keys,
        cluster_skeleton,
        flat_constraints,
        false,
        0,
        remincross_mode=remincross_mode,
      )
    }
    return ordered
  }
  if !graphviz_style && rank_keys.length() > 1 {
    let iterations = if rank_keys.length() > 2 { 2 } else { 1 }
    let mut iter = 0
    while iter < iterations {
      let reverse_ties = iter % 2 == 1
      if graphviz_style {
        if iter % 2 == 0 {
          let mut idx = 1
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_scaled_medians(
                names,
                median_parents,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              order_positions = order_positions_from_groups(ordered)
              merge_fixed_positions()
            }
            idx = idx + 1
          }
        } else {
          let mut idx = rank_keys.length() - 2
          while true {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_scaled_medians(
                names,
                median_children,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode=remincross_mode,
              )
              order_positions = order_positions_from_groups(ordered)
              merge_fixed_positions()
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order=fixed_order,
            edge_in,
            edge_out,
            edge_tail,
            edge_head,
            edge_tail_port_x,
            edge_head_port_x,
            edge_penalty,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            !reverse_ties,
            0,
            remincross_mode=remincross_mode,
          )
          order_positions = order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        let cross =
          count_crossings_port_aware(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
            fixed_order=fixed_order,
          )
        if cross <= best_cross {
          best_cross = cross
          best_ordered = clone_rank_groups(ordered)
        }
      } else {
        let mut idx = rank_keys.length() - 1
        while idx > 0 {
          let rank = rank_keys[idx - 1]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
          idx = idx - 1
        }
        if !has_port_order {
          let _ = transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, true, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              parents,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
        }
        let down_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if down_cross < best_cross {
          best_cross = down_cross
          best_ordered = clone_rank_groups(ordered)
        }
        let mut j = 1
        while j < rank_keys.length() {
          let rank = rank_keys[j]
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
          j = j + 1
        }
        if !has_port_order {
          let _ = transpose_rank_groups_limited(
            rank_keys, ordered, parents, children, node_ranks, false, 2,
          )
        }
        for rank in rank_keys {
          let names = match ordered.get(rank) {
            Some(list) => list
            None => []
          }
          if names.length() > 1 {
            let desired = compute_desired_positions(
              names,
              children,
              order_positions,
              port_order_contrib,
              preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys,
              rank_same_groups, rank_same_order, edge_order, node_order, port_edge_nodes,
              edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
        }
        let up_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
        if up_cross < best_cross {
          best_cross = up_cross
          best_ordered = clone_rank_groups(ordered)
        }
      }
      iter = iter + 1
    }
  }
  best_ordered
}

///|
/// Graphviz parity: non-cluster rank reorder call uses the same
/// reorder_rank_groups wiring as Graphviz non-cluster mincross pass.
pub fn run_noncluster_rank_reorder(
  call_inputs : NonclusterRankReorderInputs,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    call_inputs.rank_keys,
    call_inputs.groups,
    call_inputs.order_edges,
    call_inputs.order_edge_tail,
    call_inputs.order_edge_head,
    call_inputs.order_edge_tail_port_x,
    call_inputs.order_edge_head_port_x,
    call_inputs.order_edge_tail_port_order,
    call_inputs.order_edge_head_port_order,
    call_inputs.parents,
    call_inputs.children,
    call_inputs.cluster_keys,
    call_inputs.rank_same_groups,
    call_inputs.rank_same_order,
    call_inputs.edge_order,
    call_inputs.order_node_order,
    call_inputs.order_sizes,
    call_inputs.nodesep_pt,
    call_inputs.has_edge_labels,
    call_inputs.port_order_positions,
    call_inputs.port_order_contrib,
    Map::new(),
    call_inputs.cluster_skeleton,
    call_inputs.flat_constraints,
    graphviz_out_neighbors=call_inputs.graphviz_out_neighbors,
    graphviz_in_neighbors=call_inputs.graphviz_in_neighbors,
    graphviz_flip=call_inputs.graphviz_flip,
  )
}

///|
/// Graphviz parity: root ReMincross rank reorder call uses the same
/// reorder_rank_groups wiring as Graphviz root mincross pass.
pub fn run_root_rank_reorder_call(
  reorder_inputs : RootRankReorderInputs,
  root_graphviz_flip : Bool,
  coalesce_parallel : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    reorder_inputs.order_rank_keys_for_mincross,
    reorder_inputs.order_groups_for_mincross,
    reorder_inputs.order_edges_out_mincross,
    reorder_inputs.order_edge_tail_out_mincross,
    reorder_inputs.order_edge_head_out_mincross,
    reorder_inputs.order_edge_tail_port_x_mincross,
    reorder_inputs.order_edge_head_port_x_mincross,
    reorder_inputs.order_edge_tail_port_order_mincross,
    reorder_inputs.order_edge_head_port_order_mincross,
    reorder_inputs.parents,
    reorder_inputs.children,
    reorder_inputs.order_cluster_keys,
    reorder_inputs.rank_same_groups,
    reorder_inputs.rank_same_order,
    reorder_inputs.edge_order,
    reorder_inputs.order_node_order,
    reorder_inputs.order_sizes_out,
    reorder_inputs.nodesep_pt,
    reorder_inputs.has_edge_labels,
    reorder_inputs.port_order_positions,
    reorder_inputs.port_order_contrib,
    reorder_inputs.preferred_positions,
    reorder_inputs.order_cluster_skeleton,
    reorder_inputs.order_flat_constraints,
    graphviz_out_neighbors=reorder_inputs.graphviz_out_neighbors,
    graphviz_in_neighbors=reorder_inputs.graphviz_in_neighbors,
    graphviz_flip=root_graphviz_flip,
    coalesce_parallel_edges=coalesce_parallel,
  )
}

///|
/// Graphviz parity: root cluster-rank-order pass uses reorder_rank_groups with
/// coalesced-parallel mode on root-only rematerialized edge arrays.
pub fn run_root_rank_order_reorder(
  call_inputs : RootRankOrderCallInputs,
  root_graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    call_inputs.root_rank_keys,
    call_inputs.root_groups,
    call_inputs.root_edges_out,
    call_inputs.root_edge_tail_out,
    call_inputs.root_edge_head_out,
    call_inputs.root_edge_tail_port_x,
    call_inputs.root_edge_head_port_x,
    call_inputs.root_edge_tail_port_order,
    call_inputs.root_edge_head_port_order,
    call_inputs.root_parents,
    call_inputs.root_children,
    call_inputs.order_cluster_keys,
    call_inputs.rank_same_groups,
    call_inputs.rank_same_order,
    call_inputs.root_edge_order,
    call_inputs.root_node_order,
    call_inputs.order_sizes_out,
    call_inputs.nodesep_pt,
    call_inputs.has_edge_labels,
    call_inputs.port_order_positions,
    call_inputs.port_order_contrib,
    Map::new(),
    call_inputs.order_cluster_skeleton,
    call_inputs.order_flat_constraints,
    graphviz_flip=root_graphviz_flip,
    coalesce_parallel_edges=true,
  )
}

///|
/// Graphviz parity: clustered ReMincross cleanup reorder executes startpass=2
/// with coalesced-parallel mode on rematerialized edge arrays.
pub fn run_remincross_cleanup_reorder(
  reorder_inputs : ReMincrossCleanupReorderInputs,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    reorder_inputs.rem_rank_keys,
    reorder_inputs.rem_groups,
    reorder_inputs.rem_edges_out,
    reorder_inputs.rem_edge_tail_out,
    reorder_inputs.rem_edge_head_out,
    reorder_inputs.rem_edge_tail_port_x,
    reorder_inputs.rem_edge_head_port_x,
    reorder_inputs.rem_edge_tail_port_order,
    reorder_inputs.rem_edge_head_port_order,
    reorder_inputs.rem_parents,
    reorder_inputs.rem_children,
    reorder_inputs.rem_cluster_keys,
    reorder_inputs.rank_same_groups,
    reorder_inputs.rank_same_order,
    reorder_inputs.rem_edge_order,
    reorder_inputs.rem_node_order,
    reorder_inputs.rem_sizes,
    reorder_inputs.nodesep_pt,
    reorder_inputs.has_edge_labels,
    reorder_inputs.port_order_positions,
    reorder_inputs.port_order_contrib,
    Map::new(),
    Map::new(),
    reorder_inputs.rem_flat_constraints,
    graphviz_flip=reorder_inputs.graphviz_flip,
    // Graphviz parity: ReMincross counts parallel chain segments once
    // with summed xpenalty before startpass=2 transposition.
    coalesce_parallel_edges=true,
    startpass=2,
    remincross_mode=true,
  )
}
