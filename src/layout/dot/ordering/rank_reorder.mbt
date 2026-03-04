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
