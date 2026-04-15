// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
pub(all) struct PortAwareCrossingInputs {
  edge_penalty : Array[Int]
  edge_in : Map[String, Array[Int]]
  edge_out : Map[String, Array[Int]]
  edge_tail_rank : Array[Int]
  edge_head_rank : Array[Int]
}

///|
fn build_port_aware_crossing_inputs(
  groups : Map[Int, Array[String]],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks? : Map[String, Int] = Map::new(),
) -> PortAwareCrossingInputs {
  let edge_out : Map[String, Array[Int]] = Map::new()
  let edge_in : Map[String, Array[Int]] = Map::new()
  for _rank, names in groups {
    for name in names {
      edge_out[name] = []
      edge_in[name] = []
    }
  }
  let edge_penalty : Array[Int] = []
  let edge_tail_rank : Array[Int] = []
  let edge_head_rank : Array[Int] = []
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let penalty = @edge_semantics.edge_xpenalty(edge)
    edge_penalty.push(penalty)
    edge_tail_rank.push(ranks.get(edge_tail[edge_idx]).unwrap_or(-1))
    edge_head_rank.push(ranks.get(edge_head[edge_idx]).unwrap_or(-1))
    if !@edge_semantics.edge_is_constraint(edge) || penalty <= 0 {
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
  { edge_penalty, edge_in, edge_out, edge_tail_rank, edge_head_rank }
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
  let order = @rank_groups.build_order_index(groups)
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
fn count_local_port_crossings(items : Array[(Int, Double, Int)]) -> Int {
  let len = items.length()
  if len < 2 {
    return 0
  }
  let mut cross = 0
  let mut i = 0
  while i + 1 < len {
    let (order_i, port_i, pen_i) = Array::unsafe_get(items, i)
    let mut j = i + 1
    while j < len {
      let (order_j, port_j, pen_j) = Array::unsafe_get(items, j)
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
fn count_crossings_port_aware_with_inputs(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  inputs : PortAwareCrossingInputs,
  edge_tail_port_x? : Array[Double] = [],
  edge_head_port_x? : Array[Double] = [],
  fixed_order? : Map[String, Int] = Map::new(),
) -> Int {
  let _ = ranks
  let _ = edge_tail
  let order = @rank_groups.build_order_index(groups)
  if rank_keys.length() == 0 {
    return 0
  }
  let include_tail_ports = edge_tail_port_x.length() > 0
  let include_head_ports = edge_head_port_x.length() > 0
  let include_ports = include_tail_ports || include_head_ports
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
    // Graphviz parity with fixed external slots: local rank slices may carry
    // sparse slot indices, so the counting array must follow max slot.
    let count = Array::make(next_nodes.length() + 1, 0)
    let local_in_by_bottom : Array[Array[(Int, Double, Int)]] = []
    if include_head_ports {
      for _ in next_nodes {
        local_in_by_bottom.push([])
      }
    }
    let mut max_order = 0
    for top_idx, top in top_nodes {
      let projected_slots : Array[(Int, Int)] = []
      let local_out_items : Array[(Int, Double, Int)] = []
      for edge_idx in inputs.edge_out.get(top).unwrap_or_default() {
        if Array::unsafe_get(inputs.edge_head_rank, edge_idx) != next_rank {
          continue
        }
        let penalty = Array::unsafe_get(inputs.edge_penalty, edge_idx)
        if penalty <= 0 {
          continue
        }
        let head = Array::unsafe_get(edge_head, edge_idx)
        let in_rank_slot = order.get(head)
        let slot = match in_rank_slot {
          Some(head_order) => head_order
          None =>
            match fixed_order.get(head) {
              Some(value) if value >= 0 => value
              _ => continue
            }
        }
        if slot >= count.length() {
          count.resize(slot + 1, 0)
        }
        projected_slots.push((slot, penalty))
        if include_tail_ports && in_rank_slot is Some(_) {
          let tail_port_x = if edge_idx < edge_tail_port_x.length() {
            Array::unsafe_get(edge_tail_port_x, edge_idx)
          } else {
            0.0
          }
          local_out_items.push((slot, tail_port_x, penalty))
        }
        if include_head_ports && in_rank_slot is Some(_) {
          let head_port_x = if edge_idx < edge_head_port_x.length() {
            Array::unsafe_get(edge_head_port_x, edge_idx)
          } else {
            0.0
          }
          Array::unsafe_get(local_in_by_bottom, slot).push(
            (top_idx, head_port_x, penalty),
          )
        }
      }
      if max_order > 0 {
        for projected_slot in projected_slots {
          let (inv, penalty) = projected_slot
          let mut k = inv + 1
          while k <= max_order {
            rank_cross = rank_cross + Array::unsafe_get(count, k) * penalty
            k = k + 1
          }
        }
      }
      for projected_slot in projected_slots {
        let (inv, penalty) = projected_slot
        if inv > max_order {
          max_order = inv
        }
        Array::unsafe_set(count, inv, Array::unsafe_get(count, inv) + penalty)
      }
      if include_tail_ports {
        rank_cross = rank_cross + count_local_port_crossings(local_out_items)
      }
    }
    if include_ports && include_head_ports {
      for local_in_items in local_in_by_bottom {
        rank_cross = rank_cross + count_local_port_crossings(local_in_items)
      }
    }
    crossings = crossings + rank_cross
    idx = idx + 1
  }
  crossings
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
  let rank_keys : Array[Int] = []
  for rank, _ in groups {
    rank_keys.push(rank)
  }
  rank_keys.sort()
  let inputs = build_port_aware_crossing_inputs(
    groups,
    edges,
    edge_tail,
    edge_head,
    ranks~,
  )
  count_crossings_port_aware_with_inputs(
    rank_keys,
    groups,
    ranks,
    edge_tail,
    edge_head,
    inputs,
    edge_tail_port_x~,
    edge_head_port_x~,
    fixed_order~,
  )
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
