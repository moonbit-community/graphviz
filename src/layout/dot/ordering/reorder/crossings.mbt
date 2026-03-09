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
        if next < n {
          next
        } else {
          n
        }
      }
      let right = {
        let next = i + size + size
        if next < n {
          next
        } else {
          n
        }
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
pub fn count_crossings(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Int {
  let order = @ordering.build_order_index(groups)
  let edge_groups : Map[(Int, Int), Array[(Int, Int)]] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    if !@edge_semantics.edge_is_constraint(edge) {
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
      if a0 == b0 {
        a1 - b1
      } else {
        a0 - b0
      }
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
    let penalty = if edge_idx < edge_penalty.length() {
      edge_penalty[edge_idx]
    } else {
      0
    }
    if penalty <= 0 {
      continue
    }
    let port_x = if edge_idx < edge_tail_port_x.length() {
      edge_tail_port_x[edge_idx]
    } else {
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
    let penalty = if edge_idx < edge_penalty.length() {
      edge_penalty[edge_idx]
    } else {
      0
    }
    if penalty <= 0 {
      continue
    }
    let port_x = if edge_idx < edge_head_port_x.length() {
      edge_head_port_x[edge_idx]
    } else {
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
pub fn count_crossings_port_aware(
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x? : Array[Double] = [],
  edge_head_port_x? : Array[Double] = [],
  fixed_order? : Map[String, Int] = Map::new(),
) -> Int {
  let order = @ordering.build_order_index(groups)
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
    let penalty = @edge_semantics.edge_xpenalty(edge)
    edge_penalty.push(penalty)
    if !@edge_semantics.edge_is_constraint(edge) {
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
  let include_ports = edge_tail_port_x.length() > 0 ||
    edge_head_port_x.length() > 0
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
        let inv = match order.get(head) {
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
          let inv = match order.get(head) {
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
        let inv = match order.get(head) {
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
        rank_cross = rank_cross +
          local_cross_out_port_aware(
            top, next_rank, ranks, order, edge_out, edge_head, edge_tail_port_x,
            edge_penalty,
          )
      }
      for bottom in next_nodes {
        rank_cross = rank_cross +
          local_cross_in_port_aware(
            bottom, rank, ranks, order, edge_in, edge_tail, edge_head_port_x, edge_penalty,
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
pub fn build_neighbor_order_index(
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
pub fn crossing_for_pair(
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
