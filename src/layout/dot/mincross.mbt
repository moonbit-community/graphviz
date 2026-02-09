///|
fn order_rank_by_cluster(
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

fn reorder_by_medians(
  names : Array[String],
  desired : Map[String, Double],
  reverse : Bool,
  hasfixed : Bool,
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
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

fn compute_desired_positions(
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
fn compute_desired_positions_graphviz(
  names : Array[String],
  neighbors : Map[String, Array[String]],
  x_positions : Map[String, Double],
) -> Map[String, Double] {
  let desired : Map[String, Double] = Map::new()
  for name in names {
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
    match median_value_graphviz(values) {
      Some(value) => desired[name] = value
      None => ()
    }
  }
  desired
}

///|
fn compute_desired_positions_with_rank_fallback(
  names : Array[String],
  children : Map[String, Array[String]],
  parents : Map[String, Array[String]],
  x_positions : Map[String, Double],
  ranks : Map[String, Int],
  rank_sizes : Map[Int, Int],
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
    let child_list = match children.get(name) {
      Some(value) => value
      None => []
    }
    let mut use_children = false
    for child in child_list {
      match ranks.get(child) {
        Some(rank) =>
          match rank_sizes.get(rank) {
            Some(size) =>
              if size > 1 {
                use_children = true
                break
              }
            None => ()
          }
        None => ()
      }
    }
    let primary = if use_children { children } else { parents }
    let fallback = if use_children { parents } else { children }
    let list = match primary.get(name) {
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
    if desired.get(name) is None {
      let fallback_list = match fallback.get(name) {
        Some(value) => value
        None => []
      }
      let fallback_values : Array[Double] = []
      for neighbor in fallback_list {
        match x_positions.get(neighbor) {
          Some(value) => fallback_values.push(value)
          None => ()
        }
      }
      match median_value(fallback_values) {
        Some(value) => desired[name] = value
        None => ()
      }
    }
  }
  desired
}

///|
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
fn transpose_rank_groups_limited(
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
fn in_cross_graphviz(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_in : Map[String, Array[Int]],
  edge_tail : Array[String],
  edge_tail_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> Int {
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
    let tail_rank = match ranks.get(edge_tail[edge_idx]) {
      Some(value) => value
      None => rank - 1
    }
    if tail_rank != rank - 1 {
      continue
    }
    let inv = match order.get(edge_tail[edge_idx]) {
      Some(value) => value
      None => 0
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
      let tail_rank2 = match ranks.get(edge_tail[edge_idx2]) {
        Some(value) => value
        None => rank - 1
      }
      if tail_rank2 != rank - 1 {
        continue
      }
      let tail_order = match order.get(edge_tail[edge_idx2]) {
        Some(value) => value
        None => 0
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
fn out_cross_graphviz(
  left : String,
  right : String,
  rank : Int,
  ranks : Map[String, Int],
  order : Map[String, Int],
  edge_out : Map[String, Array[Int]],
  edge_head : Array[String],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> Int {
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
    let head_rank = match ranks.get(edge_head[edge_idx]) {
      Some(value) => value
      None => rank + 1
    }
    if head_rank != rank + 1 {
      continue
    }
    let inv = match order.get(edge_head[edge_idx]) {
      Some(value) => value
      None => 0
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
      let head_rank2 = match ranks.get(edge_head[edge_idx2]) {
        Some(value) => value
        None => rank + 1
      }
      if head_rank2 != rank + 1 {
        continue
      }
      let head_order = match order.get(edge_head[edge_idx2]) {
        Some(value) => value
        None => 0
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
fn transpose_rank_graphviz(
  rank : Int,
  ranks : Map[String, Int],
  names : Array[String],
  order : Map[String, Int],
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
) -> (Int, Bool) {
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
    ) {
      i = i + 1
      continue
    }
    let mut c0 = 0
    let mut c1 = 0
    c0 = c0 + in_cross_graphviz(
      left,
      right,
      rank,
      ranks,
      order,
      edge_in,
      edge_tail,
      edge_tail_port_x,
      edge_penalty,
    )
    c1 = c1 + in_cross_graphviz(
      right,
      left,
      rank,
      ranks,
      order,
      edge_in,
      edge_tail,
      edge_tail_port_x,
      edge_penalty,
    )
    c0 = c0 + out_cross_graphviz(
      left,
      right,
      rank,
      ranks,
      order,
      edge_out,
      edge_head,
      edge_head_port_x,
      edge_penalty,
    )
    c1 = c1 + out_cross_graphviz(
      right,
      left,
      rank,
      ranks,
      order,
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
  (delta, changed)
}

///|
fn transpose_rank_groups_graphviz(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  ranks : Map[String, Int],
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
      let (rank_delta, changed) = transpose_rank_graphviz(
        rank,
        ranks,
        names,
        order,
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
      )
      if changed {
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
      delta = delta + rank_delta
      idx = idx + 1
    }
    if delta < 1 {
      break
    }
  }
  changed_any
}

///|
/// Graphviz parity: aligned to refs/graphviz/lib/dotgen/mincross.c and flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn reorder_rank_groups(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
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
  graphviz_flip? : Bool = false,
  startpass? : Int = 0,
) -> Map[Int, Array[String]] {
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
    let ported = port_is_explicit(edge.tail_port()) ||
      port_is_explicit(edge.head_port())
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
    let penalty = edge_xpenalty(edge)
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
  let mut best_ordered = clone_rank_groups(ordered)
  let mut order_positions = order_positions_from_groups(ordered)
  let mut has_port_order = false
  for _name, _ in port_order_positions {
    has_port_order = true
    break
  }
  let mut has_preferred = false
  for _name, _ in preferred_positions {
    has_preferred = true
    break
  }
  let mut has_port_contrib = false
  for _name, _ in port_order_contrib {
    has_port_contrib = true
    break
  }
  let graphviz_style = !has_port_order && !has_preferred && !has_port_contrib
  let median_parents : Map[String, Array[String]] = Map::new()
  let median_children : Map[String, Array[String]] = Map::new()
  let edge_penalty : Array[Int] = []
  let edge_in : Map[String, Array[Int]] = Map::new()
  let edge_out : Map[String, Array[Int]] = Map::new()
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
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if penalty <= 0 || !edge_is_constraint(edge) {
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
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
      match median_parents.get(head) {
        Some(list) => list.push(tail)
        None => median_parents[head] = [tail]
      }
      match median_children.get(tail) {
        Some(list) => list.push(head)
        None => median_children[tail] = [head]
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
  let mut best_cross =
    if graphviz_style {
    count_crossings_graphviz(
      ordered,
      node_ranks,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x=edge_tail_port_x,
      edge_head_port_x=edge_head_port_x,
    )
  } else {
    count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if graphviz_style && startpass > 1 && @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    println("remincross start crossings=\{best_cross}")
  }
  if !graphviz_style && rank_keys.length() > 1 {
    ordered = build_rank_groups_graphviz(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      0,
      flip=graphviz_flip,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
    )
    order_positions = order_positions_from_groups(ordered)
    let seed_cross =
      count_crossings_graphviz(
        ordered,
        node_ranks,
        edges,
        edge_tail,
        edge_head,
        edge_tail_port_x=edge_tail_port_x,
        edge_head_port_x=edge_head_port_x,
      )
    if seed_cross > 0 {
      let _ = transpose_rank_groups_graphviz(
        rank_keys,
        ordered,
        node_ranks,
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
      )
      order_positions = order_positions_from_groups(ordered)
    }
    best_ordered = clone_rank_groups(ordered)
    best_cross = count_crossings(ordered, node_ranks, edges, edge_tail, edge_head)
  }
  if graphviz_style && rank_keys.length() > 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
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
        ordered = build_rank_groups_graphviz(
          rank_keys,
          groups,
          edge_tail,
          edge_head,
          node_ranks,
          node_order,
          cluster_keys,
          cluster_skeleton,
          pass,
          flip=graphviz_flip,
          graphviz_out_neighbors=graphviz_out_neighbors,
          graphviz_in_neighbors=graphviz_in_neighbors,
        )
        order_positions = order_positions_from_groups(ordered)
        if !has_port_order {
          let cross =
            count_crossings_graphviz(
              ordered,
              node_ranks,
              edges,
              edge_tail,
              edge_head,
              edge_tail_port_x=edge_tail_port_x,
              edge_head_port_x=edge_head_port_x,
            )
          if cross > 0 {
            let _ = transpose_rank_groups_graphviz(
              rank_keys,
              ordered,
              node_ranks,
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
            )
            order_positions = order_positions_from_groups(ordered)
          }
        }
        cur_cross =
          count_crossings_graphviz(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
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
        }
        cur_cross = best_cross
      }
      let mut trying = 0
      let mut iter = 0
      while iter < max_this_pass {
        if trying >= min_quit || cur_cross == 0 {
          break
        }
        trying = trying + 1
        let reverse = iter % 4 < 2
        if iter % 2 == 0 {
          let mut idx = 1
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired = compute_desired_positions_graphviz(
                names,
                median_parents,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
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
              let desired = compute_desired_positions_graphviz(
                names,
                median_children,
                order_positions,
              )
              ordered[rank] = reorder_by_medians(
                names,
                desired,
                reverse,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
              )
              order_positions = order_positions_from_groups(ordered)
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = transpose_rank_groups_graphviz(
            rank_keys,
            ordered,
            node_ranks,
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
          )
          order_positions = order_positions_from_groups(ordered)
        }
        cur_cross =
          count_crossings_graphviz(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
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
    }
    if best_cross > 0 && !has_port_order {
      let _ = transpose_rank_groups_graphviz(
        rank_keys,
        ordered,
        node_ranks,
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
              let desired = compute_desired_positions_graphviz(
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
              )
              order_positions = order_positions_from_groups(ordered)
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
              let desired = compute_desired_positions_graphviz(
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
              )
              order_positions = order_positions_from_groups(ordered)
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if !has_port_order {
          let _ = transpose_rank_groups_graphviz(
            rank_keys,
            ordered,
            node_ranks,
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
          )
          order_positions = order_positions_from_groups(ordered)
        }
        let cross =
          count_crossings_graphviz(
            ordered,
            node_ranks,
            edges,
            edge_tail,
            edge_head,
            edge_tail_port_x=edge_tail_port_x,
            edge_head_port_x=edge_head_port_x,
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
