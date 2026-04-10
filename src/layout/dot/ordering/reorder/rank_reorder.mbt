// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
type NodeSize = @node_primitives.NodeSize

///|
priv struct RankConstraintLookup {
  cluster_ids : Array[Int]
  skeletons : Array[Bool]
  name_index : Map[String, Int]
  flat_left_to_right : Array[Map[Int, Bool]]
  has_clusters : Bool
  has_flat_constraints : Bool
}

///|
priv struct ParsedFlatConstraints {
  heads_by_tail : Map[String, Array[String]]
  has_enabled_constraints : Bool
}

///|
priv struct RankConstraintState {
  node_indices : Array[Int]
}

///|
priv struct RankDesiredState {
  has_values : Array[Bool]
  values : Array[Double]
}

///|
fn build_parsed_flat_constraints(
  flat_constraints : Map[String, Bool],
) -> ParsedFlatConstraints {
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  let mut has_enabled_constraints = false
  for key, enabled in flat_constraints {
    if !enabled {
      continue
    }
    match @rank_constraints.parse_flat_constraint_key(key) {
      Some((tail, head)) if tail != "" && head != "" => {
        match heads_by_tail.get(tail) {
          Some(heads) => heads.push(head)
          None => heads_by_tail[tail] = [head]
        }
        has_enabled_constraints = true
      }
      _ => ()
    }
  }
  { heads_by_tail, has_enabled_constraints }
}

///|
fn build_rank_constraint_lookup(
  names : Array[String],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : ParsedFlatConstraints,
) -> RankConstraintLookup {
  let cluster_ids : Array[Int] = []
  let skeletons : Array[Bool] = []
  let name_index : Map[String, Int] = Map::new()
  let flat_left_to_right : Array[Map[Int, Bool]] = []
  let cluster_id_by_name : Map[String, Int] = Map::new()
  let build_flat_lookup = flat_constraints.has_enabled_constraints
  let mut has_clusters = false
  let mut next_cluster_id = 1
  for i, name in names {
    let cluster = cluster_keys.get(name).unwrap_or_default()
    if cluster != "" {
      has_clusters = true
      let cluster_id = match cluster_id_by_name.get(cluster) {
        Some(id) => id
        None => {
          let id = next_cluster_id
          next_cluster_id += 1
          cluster_id_by_name[cluster] = id
          id
        }
      }
      cluster_ids.push(cluster_id)
      skeletons.push(cluster_skeleton.get(name) == Some(true))
    } else {
      cluster_ids.push(0)
      skeletons.push(false)
    }
    if build_flat_lookup {
      name_index[name] = i
    }
    flat_left_to_right.push(Map::new())
  }
  let mut has_flat_constraints = false
  if build_flat_lookup {
    for tail, heads in flat_constraints.heads_by_tail {
      match name_index.get(tail) {
        Some(tail_idx) => {
          let constrained = flat_left_to_right[tail_idx]
          for head in heads {
            match name_index.get(head) {
              Some(head_idx) => {
                constrained[head_idx] = true
                has_flat_constraints = true
              }
              None => ()
            }
          }
        }
        None => ()
      }
    }
  }
  {
    cluster_ids,
    skeletons,
    name_index,
    flat_left_to_right,
    has_clusters,
    has_flat_constraints,
  }
}

///|
fn build_rank_constraint_state(
  names : Array[String],
  constraint_lookup : RankConstraintLookup,
) -> RankConstraintState {
  let node_indices : Array[Int] = []
  if !constraint_lookup.has_flat_constraints {
    for i in 0..<names.length() {
      node_indices.push(i)
    }
    return { node_indices, }
  }
  for name in names {
    match constraint_lookup.name_index.get(name) {
      Some(index) => node_indices.push(index)
      None => node_indices.push(-1)
    }
  }
  { node_indices, }
}

///|
fn rank_left2right_constraint_resolved(
  constraint_lookup : RankConstraintLookup,
  constraint_state : RankConstraintState,
  left_pos : Int,
  right_pos : Int,
  remincross_mode : Bool,
) -> Bool {
  if !constraint_lookup.has_clusters && !constraint_lookup.has_flat_constraints {
    return false
  }
  let left_idx = constraint_state.node_indices[left_pos]
  let right_idx = constraint_state.node_indices[right_pos]
  if left_idx < 0 || right_idx < 0 {
    return false
  }
  if constraint_lookup.has_clusters {
    let left_cluster = constraint_lookup.cluster_ids[left_idx]
    let right_cluster = constraint_lookup.cluster_ids[right_idx]
    if remincross_mode {
      // Graphviz parity: in ReMincross, nodes in different buckets are pinned.
      if left_cluster != right_cluster {
        return true
      }
    }
    if left_cluster != 0 && right_cluster != 0 && left_cluster != right_cluster {
      let left_skel = constraint_lookup.skeletons[left_idx]
      let right_skel = constraint_lookup.skeletons[right_idx]
      if !left_skel && !right_skel {
        return true
      }
    }
  }
  if !constraint_lookup.has_flat_constraints {
    return false
  }
  constraint_lookup.flat_left_to_right[left_idx].get(right_idx) == Some(true)
}

///|
fn build_rank_desired_state(
  names : Array[String],
  desired : Map[String, Double],
) -> RankDesiredState {
  let has_values : Array[Bool] = []
  let values : Array[Double] = []
  for name in names {
    match desired.get(name) {
      Some(value) => {
        has_values.push(true)
        values.push(value)
      }
      None => {
        has_values.push(false)
        values.push(-1.0)
      }
    }
  }
  { has_values, values }
}

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
          let keep_order = if reverse_ties {
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
      edge_pair_order, port_order_positions, reverse_ties,
    )
    for name in ordered_group {
      result.push(name)
    }
  }
  result
}

///|
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
  let parsed_flat_constraints = build_parsed_flat_constraints(flat_constraints)
  let constraint_lookup = build_rank_constraint_lookup(
    names,
    cluster_keys,
    cluster_skeleton,
    parsed_flat_constraints,
  )
  reorder_by_medians_with_lookup(
    names,
    desired,
    reverse,
    hasfixed,
    constraint_lookup,
    remincross_mode~,
  )
}

///|
fn reorder_by_medians_with_lookup(
  names : Array[String],
  desired : Map[String, Double],
  reverse : Bool,
  hasfixed : Bool,
  constraint_lookup : RankConstraintLookup,
  remincross_mode? : Bool = false,
) -> Array[String] {
  let sorted = names.copy()
  if sorted.length() < 2 {
    return sorted
  }
  let desired_state = build_rank_desired_state(sorted, desired)
  if !constraint_lookup.has_clusters && !constraint_lookup.has_flat_constraints {
    return reorder_by_medians_unconstrained(
      sorted,
      desired_state,
      reverse,
      hasfixed,
    )
  }
  let constraint_state = build_rank_constraint_state(sorted, constraint_lookup)
  reorder_by_medians_constrained(
    sorted,
    desired_state,
    reverse,
    hasfixed,
    constraint_lookup,
    constraint_state,
    remincross_mode~,
  )
}

///|
fn reorder_by_medians_unconstrained(
  sorted : Array[String],
  desired_state : RankDesiredState,
  reverse : Bool,
  hasfixed : Bool,
) -> Array[String] {
  // Hot path: loop guards keep indices within the original rank length.
  let has_values = desired_state.has_values
  let values = desired_state.values
  let mut all_have_values = true
  for has_value in has_values {
    if !has_value {
      all_have_values = false
      break
    }
  }
  if all_have_values {
    let mut ep = sorted.length()
    let mut nelt = sorted.length() - 1
    while nelt >= 0 {
      let mut swapped = false
      let mut lp = 0
      while lp + 1 < ep {
        let rp = lp + 1
        let p1 = Array::unsafe_get(values, lp)
        let p2 = Array::unsafe_get(values, rp)
        if p1 > p2 || (p1 >= p2 && reverse) {
          let tmp = Array::unsafe_get(sorted, lp)
          Array::unsafe_set(sorted, lp, Array::unsafe_get(sorted, rp))
          Array::unsafe_set(sorted, rp, tmp)
          let tmp_value = Array::unsafe_get(values, lp)
          Array::unsafe_set(values, lp, Array::unsafe_get(values, rp))
          Array::unsafe_set(values, rp, tmp_value)
          swapped = true
        }
        lp = rp
      }
      if !swapped {
        break
      }
      if !hasfixed && !reverse {
        ep = ep - 1
      }
      nelt = nelt - 1
    }
    return sorted
  }
  let mut ep = sorted.length()
  let mut nelt = sorted.length() - 1
  while nelt >= 0 {
    let mut swapped = false
    let mut lp = 0
    while lp < ep {
      while lp < ep && !Array::unsafe_get(has_values, lp) {
        lp = lp + 1
      }
      if lp >= ep {
        break
      }
      let mut rp = lp + 1
      while rp < ep && !Array::unsafe_get(has_values, rp) {
        rp = rp + 1
      }
      if rp >= ep {
        break
      }
      let p1 = Array::unsafe_get(values, lp)
      let p2 = Array::unsafe_get(values, rp)
      if p1 > p2 || (p1 >= p2 && reverse) {
        let tmp = Array::unsafe_get(sorted, lp)
        Array::unsafe_set(sorted, lp, Array::unsafe_get(sorted, rp))
        Array::unsafe_set(sorted, rp, tmp)
        let tmp_has_value = Array::unsafe_get(has_values, lp)
        Array::unsafe_set(has_values, lp, Array::unsafe_get(has_values, rp))
        Array::unsafe_set(has_values, rp, tmp_has_value)
        let tmp_value = Array::unsafe_get(values, lp)
        Array::unsafe_set(values, lp, Array::unsafe_get(values, rp))
        Array::unsafe_set(values, rp, tmp_value)
        swapped = true
      }
      lp = rp
    }
    if !swapped {
      break
    }
    if !hasfixed && !reverse {
      ep = ep - 1
    }
    nelt = nelt - 1
  }
  sorted
}

///|
fn reorder_by_medians_constrained(
  sorted : Array[String],
  desired_state : RankDesiredState,
  reverse : Bool,
  hasfixed : Bool,
  constraint_lookup : RankConstraintLookup,
  constraint_state : RankConstraintState,
  remincross_mode? : Bool = false,
) -> Array[String] {
  // Hot path: loop guards and stored node indices keep accesses in bounds.
  let has_values = desired_state.has_values
  let values = desired_state.values
  let node_indices = constraint_state.node_indices
  let cluster_ids = constraint_lookup.cluster_ids
  let mut ep = sorted.length()
  let mut nelt = sorted.length() - 1
  while nelt >= 0 {
    let mut swapped = false
    let mut lp = 0
    while lp < ep {
      while lp < ep && !Array::unsafe_get(has_values, lp) {
        lp = lp + 1
      }
      if lp >= ep {
        break
      }
      let mut rp = lp + 1
      let mut muststay = false
      let mut sawclust = false
      while rp < ep {
        let rp_idx = Array::unsafe_get(node_indices, rp)
        let rp_cluster = if rp_idx >= 0 {
          Array::unsafe_get(cluster_ids, rp_idx)
        } else {
          0
        }
        if sawclust && rp_cluster != 0 {
          rp = rp + 1
          continue
        }
        if rank_left2right_constraint_resolved(
            constraint_lookup,
            constraint_state,
            lp,
            rp,
            remincross_mode,
          ) {
          muststay = true
          break
        }
        if Array::unsafe_get(has_values, rp) {
          break
        }
        if rp_cluster != 0 {
          sawclust = true
        }
        rp = rp + 1
      }
      if rp >= ep {
        break
      }
      if !muststay {
        let p1 = Array::unsafe_get(values, lp)
        let p2 = Array::unsafe_get(values, rp)
        if p1 > p2 || (p1 >= p2 && reverse) {
          let tmp = Array::unsafe_get(sorted, lp)
          Array::unsafe_set(sorted, lp, Array::unsafe_get(sorted, rp))
          Array::unsafe_set(sorted, rp, tmp)
          let tmp_node_index = Array::unsafe_get(node_indices, lp)
          Array::unsafe_set(node_indices, lp, Array::unsafe_get(node_indices, rp))
          Array::unsafe_set(node_indices, rp, tmp_node_index)
          let tmp_has_value = Array::unsafe_get(has_values, lp)
          Array::unsafe_set(has_values, lp, Array::unsafe_get(has_values, rp))
          Array::unsafe_set(has_values, rp, tmp_has_value)
          let tmp_value = Array::unsafe_get(values, lp)
          Array::unsafe_set(values, lp, Array::unsafe_get(values, rp))
          Array::unsafe_set(values, rp, tmp_value)
          swapped = true
        }
      }
      lp = rp
    }
    if !swapped {
      break
    }
    if !hasfixed && !reverse {
      ep = ep - 1
    }
    nelt = nelt - 1
  }
  sorted
}

///|
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
  let parent_orders = build_neighbor_order_index(
    names,
    parents,
    ranks,
    order,
    rank - 1,
  )
  let child_orders = build_neighbor_order_index(
    names,
    children,
    ranks,
    order,
    rank + 1,
  )
  let mut i = 0
  while i + 1 < names.length() {
    let left = names[i]
    let right = names[i + 1]
    let c0 = crossing_for_pair(left, right, parent_orders, child_orders)
    let c1 = crossing_for_pair(right, left, parent_orders, child_orders)
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
    let order = @rank_groups.build_order_index(ordered)
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
priv struct PortTiebreakOrders {
  in_orders : Array[Array[(Int, Double, Int)]]
  out_orders : Array[Array[(Int, Double, Int)]]
}

///|
priv struct RankIncidentEdgeLists {
  in_edges : Array[Array[Int]]
  out_edges : Array[Array[Int]]
}

///|
priv struct PortIncidentEdge {
  edge_idx : Int
  port_x : Double
  penalty : Int
}

///|
priv struct RankPortIncidentEdgeLists {
  in_edges : Array[Array[PortIncidentEdge]]
  out_edges : Array[Array[PortIncidentEdge]]
}

///|
priv struct ActiveIncidentEdgeMaps {
  in_edges : Map[String, Array[Int]]
  out_edges : Map[String, Array[Int]]
}

///|
priv struct EdgeEndpointOrders {
  tail_orders : Array[Int]
  head_orders : Array[Int]
}

///|
priv struct CrossPairCounts {
  forward : Int
  reverse : Int
}

///|
fn resolve_port_tiebreak_order(
  name : String,
  order : Map[String, Int],
  fixed_order : Map[String, Int],
) -> Int {
  match order.get(name) {
    Some(value) => value
    None => fixed_order.get(name).unwrap_or_default()
  }
}

///|
fn build_edge_endpoint_orders(
  edge_tail : Array[String],
  edge_head : Array[String],
  order : Map[String, Int],
  fixed_order : Map[String, Int],
) -> EdgeEndpointOrders {
  let tail_orders : Array[Int] = []
  for tail in edge_tail {
    tail_orders.push(resolve_port_tiebreak_order(tail, order, fixed_order))
  }
  let head_orders : Array[Int] = []
  for head in edge_head {
    head_orders.push(resolve_port_tiebreak_order(head, order, fixed_order))
  }
  { tail_orders, head_orders }
}

fn build_active_incident_edge_maps(
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_penalty : Array[Int],
) -> ActiveIncidentEdgeMaps {
  let active_in_edges : Map[String, Array[Int]] = Map::new()
  let active_out_edges : Map[String, Array[Int]] = Map::new()
  for name, incident in edge_in {
    let filtered : Array[Int] = []
    for edge_idx in incident {
      if edge_penalty[edge_idx] > 0 {
        filtered.push(edge_idx)
      }
    }
    active_in_edges[name] = filtered
  }
  for name, incident in edge_out {
    let filtered : Array[Int] = []
    for edge_idx in incident {
      if edge_penalty[edge_idx] > 0 {
        filtered.push(edge_idx)
      }
    }
    active_out_edges[name] = filtered
  }
  { in_edges: active_in_edges, out_edges: active_out_edges }
}

///|
fn build_rank_incident_edge_lists(
  names : Array[String],
  active_incident_edges : ActiveIncidentEdgeMaps,
) -> RankIncidentEdgeLists {
  let in_edges : Array[Array[Int]] = []
  let out_edges : Array[Array[Int]] = []
  for name in names {
    in_edges.push(active_incident_edges.in_edges.get(name).unwrap_or_default())
    out_edges.push(active_incident_edges.out_edges.get(name).unwrap_or_default())
  }
  { in_edges, out_edges }
}

fn build_rank_port_incident_edge_lists(
  names : Array[String],
  edge_in : Map[String, Array[Int]],
  edge_out : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> RankPortIncidentEdgeLists {
  let in_edges : Array[Array[PortIncidentEdge]] = []
  let out_edges : Array[Array[PortIncidentEdge]] = []
  for name in names {
    let incoming : Array[PortIncidentEdge] = []
    for edge_idx in edge_in.get(name).unwrap_or_default() {
      let penalty = edge_penalty[edge_idx]
      if penalty <= 0 {
        continue
      }
      incoming.push({
        edge_idx,
        port_x: if edge_idx < edge_tail_port_x.length() {
          edge_tail_port_x[edge_idx]
        } else {
          0.0
        },
        penalty,
      })
    }
    in_edges.push(incoming)
    let outgoing : Array[PortIncidentEdge] = []
    for edge_idx in edge_out.get(name).unwrap_or_default() {
      let penalty = edge_penalty[edge_idx]
      if penalty <= 0 {
        continue
      }
      outgoing.push({
        edge_idx,
        port_x: if edge_idx < edge_head_port_x.length() {
          edge_head_port_x[edge_idx]
        } else {
          0.0
        },
        penalty,
      })
    }
    out_edges.push(outgoing)
  }
  { in_edges, out_edges }
}

///|
fn build_rank_port_tiebreak_orders(
  incident_edges : RankIncidentEdgeLists,
  edge_endpoint_orders : EdgeEndpointOrders,
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_penalty : Array[Int],
) -> PortTiebreakOrders {
  let in_orders : Array[Array[(Int, Double, Int)]] = []
  let out_orders : Array[Array[(Int, Double, Int)]] = []
  for edge_indices in incident_edges.in_edges {
    let incoming : Array[(Int, Double, Int)] = []
    for edge_idx in edge_indices {
      let penalty = edge_penalty[edge_idx]
      if penalty <= 0 {
        continue
      }
      incoming.push((
        edge_endpoint_orders.tail_orders[edge_idx],
        if edge_idx < edge_tail_port_x.length() {
          edge_tail_port_x[edge_idx]
        } else {
          0.0
        },
        penalty,
      ))
    }
    in_orders.push(incoming)
  }
  for edge_indices in incident_edges.out_edges {
    let outgoing : Array[(Int, Double, Int)] = []
    for edge_idx in edge_indices {
      let penalty = edge_penalty[edge_idx]
      if penalty <= 0 {
        continue
      }
      outgoing.push((
        edge_endpoint_orders.head_orders[edge_idx],
        if edge_idx < edge_head_port_x.length() {
          edge_head_port_x[edge_idx]
        } else {
          0.0
        },
        penalty,
      ))
    }
    out_orders.push(outgoing)
  }
  { in_orders, out_orders }
}

///|
fn refresh_port_incident_edge_orders_for_node(
  incident_in : Array[PortIncidentEdge],
  incident_out : Array[PortIncidentEdge],
  new_order : Int,
  edge_endpoint_orders : EdgeEndpointOrders,
) -> Unit {
  for edge in incident_out {
    edge_endpoint_orders.tail_orders[edge.edge_idx] = new_order
  }
  for edge in incident_in {
    edge_endpoint_orders.head_orders[edge.edge_idx] = new_order
  }
}

///|
/// Graphviz parity: direct port x tie-break matches mincross.c in_cross.
fn in_cross_pair_tiebreak_live(
  left_in_edges : Array[PortIncidentEdge],
  right_in_edges : Array[PortIncidentEdge],
  edge_endpoint_orders : EdgeEndpointOrders,
) -> CrossPairCounts {
  if left_in_edges.length() == 0 || right_in_edges.length() == 0 {
    return { forward: 0, reverse: 0 }
  }
  let tail_orders = edge_endpoint_orders.tail_orders
  let mut forward = 0
  let mut reverse = 0
  let left_len = left_in_edges.length()
  let right_len = right_in_edges.length()
  let mut right_idx = 0
  while right_idx < right_len {
    let right_edge = Array::unsafe_get(right_in_edges, right_idx)
    let cnt = right_edge.penalty
    let inv = Array::unsafe_get(tail_orders, right_edge.edge_idx)
    let inv_port = right_edge.port_x
    let mut left_idx = 0
    while left_idx < left_len {
      let left_edge = Array::unsafe_get(left_in_edges, left_idx)
      let weight = left_edge.penalty
      let tail_order = Array::unsafe_get(tail_orders, left_edge.edge_idx)
      let tail_port = left_edge.port_x
      if tail_order > inv || (tail_order == inv && tail_port > inv_port) {
        forward = forward + weight * cnt
      } else if tail_order < inv || (tail_order == inv && tail_port < inv_port) {
        reverse = reverse + weight * cnt
      }
      left_idx = left_idx + 1
    }
    right_idx = right_idx + 1
  }
  { forward, reverse }
}

///|
/// Graphviz parity: port x tie-break matches mincross.c in_cross.
fn in_cross_port_tiebreak(
  left_in : Array[(Int, Double, Int)],
  right_in : Array[(Int, Double, Int)],
) -> Int {
  let mut cross = 0
  for right_entry in right_in {
    let (inv, inv_port, cnt) = right_entry
    for left_entry in left_in {
      let (tail_order, tail_port, weight) = left_entry
      let t = tail_order - inv
      if t > 0 || (t == 0 && tail_port > inv_port) {
        cross = cross + weight * cnt
      }
    }
  }
  cross
}

///|
/// Graphviz parity: direct port x tie-break matches mincross.c out_cross.
fn out_cross_pair_tiebreak_live(
  left_out_edges : Array[PortIncidentEdge],
  right_out_edges : Array[PortIncidentEdge],
  edge_endpoint_orders : EdgeEndpointOrders,
) -> CrossPairCounts {
  if left_out_edges.length() == 0 || right_out_edges.length() == 0 {
    return { forward: 0, reverse: 0 }
  }
  let head_orders = edge_endpoint_orders.head_orders
  let mut forward = 0
  let mut reverse = 0
  let left_len = left_out_edges.length()
  let right_len = right_out_edges.length()
  let mut right_idx = 0
  while right_idx < right_len {
    let right_edge = Array::unsafe_get(right_out_edges, right_idx)
    let cnt = right_edge.penalty
    let inv = Array::unsafe_get(head_orders, right_edge.edge_idx)
    let inv_port = right_edge.port_x
    let mut left_idx = 0
    while left_idx < left_len {
      let left_edge = Array::unsafe_get(left_out_edges, left_idx)
      let weight = left_edge.penalty
      let head_order = Array::unsafe_get(head_orders, left_edge.edge_idx)
      let head_port = left_edge.port_x
      if head_order > inv || (head_order == inv && head_port > inv_port) {
        forward = forward + weight * cnt
      } else if head_order < inv || (head_order == inv && head_port < inv_port) {
        reverse = reverse + weight * cnt
      }
      left_idx = left_idx + 1
    }
    right_idx = right_idx + 1
  }
  { forward, reverse }
}

///|
/// Graphviz parity: port x tie-break matches mincross.c out_cross.
fn out_cross_port_tiebreak(
  left_out : Array[(Int, Double, Int)],
  right_out : Array[(Int, Double, Int)],
) -> Int {
  let mut cross = 0
  for right_entry in right_out {
    let (inv, inv_port, cnt) = right_entry
    for left_entry in left_out {
      let (head_order, head_port, weight) = left_entry
      let t = head_order - inv
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
  let _ = rank
  let _ = ranks
  let order : Map[String, Int] = Map::new()
  for i, name in names {
    order[name] = i
  }
  let edge_endpoint_orders = build_edge_endpoint_orders(
    edge_tail,
    edge_head,
    order,
    fixed_order,
  )
  let active_incident_edges = build_active_incident_edge_maps(
    edge_in,
    edge_out,
    edge_penalty,
  )
  let incident_edges = build_rank_incident_edge_lists(
    names,
    active_incident_edges,
  )
  let port_orders = build_rank_port_tiebreak_orders(
    incident_edges,
    edge_endpoint_orders,
    edge_tail_port_x,
    edge_head_port_x,
    edge_penalty,
  )
  let mut cross = 0
  let mut left_idx = 0
  while left_idx + 1 < names.length() {
    let mut right_idx = left_idx + 1
    while right_idx < names.length() {
      cross = cross +
        in_cross_port_tiebreak(port_orders.in_orders[left_idx], port_orders.in_orders[right_idx])
      cross = cross +
        out_cross_port_tiebreak(port_orders.out_orders[left_idx], port_orders.out_orders[right_idx])
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
    let penalty = if edge_idx < edge_penalty.length() {
      edge_penalty[edge_idx]
    } else {
      0
    }
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
    if !@edge_identity.is_edge_vnode_name(other) &&
      !@cluster_identity.is_cluster_skeleton_name(other) {
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
      if !@edge_identity.is_edge_vnode_name(other) &&
        !@cluster_identity.is_cluster_skeleton_name(other) {
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
      if !@edge_identity.is_edge_vnode_name(other) &&
        !@cluster_identity.is_cluster_skeleton_name(other) {
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
  incident_edges : RankPortIncidentEdgeLists,
  edge_endpoint_orders : EdgeEndpointOrders,
  constraint_lookup : RankConstraintLookup,
  constraint_state : RankConstraintState,
  reverse : Bool,
  remincross_mode : Bool,
) -> TransposeRankResult {
  let _ = rank
  let _ = ranks
  let in_edges_by_node = incident_edges.in_edges
  let out_edges_by_node = incident_edges.out_edges
  let node_indices = constraint_state.node_indices
  let has_constraints = constraint_lookup.has_clusters ||
    constraint_lookup.has_flat_constraints
  let len = names.length()
  let mut changed = false
  let mut delta = 0
  let mut i = 0
  while i + 1 < len {
    let left = Array::unsafe_get(names, i)
    let right = Array::unsafe_get(names, i + 1)
    if has_constraints && rank_left2right_constraint_resolved(
        constraint_lookup,
        constraint_state,
        i,
        i + 1,
        remincross_mode,
      ) {
      i = i + 1
      continue
    }
    let mut c0 = 0
    let mut c1 = 0
    let left_incident_in = Array::unsafe_get(in_edges_by_node, i)
    let right_incident_in = Array::unsafe_get(in_edges_by_node, i + 1)
    let left_incident_out = Array::unsafe_get(out_edges_by_node, i)
    let right_incident_out = Array::unsafe_get(out_edges_by_node, i + 1)
    if left_incident_in.length() > 0 && right_incident_in.length() > 0 {
      let in_cross_pair = in_cross_pair_tiebreak_live(
        left_incident_in,
        right_incident_in,
        edge_endpoint_orders,
      )
      c0 = c0 + in_cross_pair.forward
      c1 = c1 + in_cross_pair.reverse
    }
    if left_incident_out.length() > 0 && right_incident_out.length() > 0 {
      let out_cross_pair = out_cross_pair_tiebreak_live(
        left_incident_out,
        right_incident_out,
        edge_endpoint_orders,
      )
      c0 = c0 + out_cross_pair.forward
      c1 = c1 + out_cross_pair.reverse
    }
    if c1 < c0 || (reverse && c1 == c0 && c0 > 0) {
      Array::unsafe_set(names, i, right)
      Array::unsafe_set(names, i + 1, left)
      Array::unsafe_set(in_edges_by_node, i, right_incident_in)
      Array::unsafe_set(in_edges_by_node, i + 1, left_incident_in)
      Array::unsafe_set(out_edges_by_node, i, right_incident_out)
      Array::unsafe_set(out_edges_by_node, i + 1, left_incident_out)
      if has_constraints {
        let tmp_node_index = Array::unsafe_get(node_indices, i)
        Array::unsafe_set(node_indices, i, Array::unsafe_get(node_indices, i + 1))
        Array::unsafe_set(node_indices, i + 1, tmp_node_index)
      }
      refresh_port_incident_edge_orders_for_node(
        left_incident_in,
        left_incident_out,
        i + 1,
        edge_endpoint_orders,
      )
      refresh_port_incident_edge_orders_for_node(
        right_incident_in,
        right_incident_out,
        i,
        edge_endpoint_orders,
      )
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
  let initial_order = @rank_groups.build_order_index(ordered)
  let parsed_flat_constraints = build_parsed_flat_constraints(flat_constraints)
  let edge_endpoint_orders = build_edge_endpoint_orders(
    edge_tail,
    edge_head,
    initial_order,
    fixed_order,
  )
  let rank_incident_edges : Array[RankPortIncidentEdgeLists] = []
  let rank_constraint_lookups : Array[RankConstraintLookup] = []
  let rank_constraint_states : Array[RankConstraintState] = []
  for rank in rank_keys {
    let names = match ordered.get(rank) {
      Some(list) => list
      None => []
    }
    rank_incident_edges.push(
      build_rank_port_incident_edge_lists(
        names,
        edge_in,
        edge_out,
        edge_tail_port_x,
        edge_head_port_x,
        edge_penalty,
      ),
    )
    let constraint_lookup = build_rank_constraint_lookup(
      names,
      cluster_keys,
      cluster_skeleton,
      parsed_flat_constraints,
    )
    rank_constraint_lookups.push(constraint_lookup)
    rank_constraint_states.push(
      build_rank_constraint_state(names, constraint_lookup),
    )
  }
  while true {
    if max_passes > 0 && passes >= max_passes {
      break
    }
    passes = passes + 1
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
        rank_incident_edges[idx],
        edge_endpoint_orders,
        rank_constraint_lookups[idx],
        rank_constraint_states[idx],
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
    match @rank_constraints.parse_flat_constraint_key(key) {
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
          Some(value) =>
            if value > 0.0 {
              desired[name] = value - mc_eps
              assigned = true
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
  let ordered = @rank_groups.clone_rank_groups(groups)
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
    match @rank_constraints.parse_flat_constraint_key(key) {
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
      let v = if graphviz_flip {
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
    let reordered : Array[String] = if graphviz_flip {
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
/// Graphviz parity: build_ranks seeding runs component-scoped ordering first,
/// then applies transpose when crossings remain (port-offset aware tie-breaks).
/// Do not change behavior without updating fixtures/tests.
pub(all) struct SeededReorderBuildContext {
  order_rank_keys : Array[Int]
  order_groups : Map[Int, Array[String]]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_ranks : Map[String, Int]
  order_node_order : Map[String, Int]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_flip : Bool
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  flat_rank_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: build_ranks seeding runs component-scoped ordering first,
/// then applies transpose when crossings remain (port-offset aware tie-breaks).
/// Do not change behavior without updating fixtures/tests.
pub fn build_seeded_reorder_groups(
  build_context : SeededReorderBuildContext,
) -> Map[Int, Array[String]] {
  // Graphviz parity: seed build_ranks from component-scoped walk,
  // matching decompose/install traversal used by remincross with
  // cluster-expanded flat constraints.
  let seed_pass = if @sys.get_env_var("DOT_SEED_PASS1") is Some(_) {
    1
  } else {
    0
  }
  let seeded_groups = build_component_rank_groups(
    build_context.order_rank_keys,
    build_context.order_groups,
    build_context.order_edge_tail_out,
    build_context.order_edge_head_out,
    build_context.order_ranks,
    build_context.order_node_order,
    build_context.order_cluster_keys,
    build_context.order_cluster_skeleton,
    seed_pass,
    build_context.order_flat_constraints,
    flip=build_context.graphviz_flip,
    graphviz_out_neighbors=build_context.graphviz_out_neighbors,
    graphviz_in_neighbors=build_context.graphviz_in_neighbors,
  )
  // Graphviz parity: build_ranks applies transpose if crossings remain;
  // crossing count uses endpoint port x offsets for tie-correct ordering.
  let seed_cross = count_crossings_port_aware(
    seeded_groups,
    build_context.order_ranks,
    build_context.order_edges_out,
    build_context.order_edge_tail_out,
    build_context.order_edge_head_out,
    edge_tail_port_x=build_context.order_edge_tail_port_x,
    edge_head_port_x=build_context.order_edge_head_port_x,
  )
  if seed_cross > 0 {
    let transpose_seed_maps = build_transpose_seed_maps(
      build_context.order_rank_keys,
      seeded_groups,
      build_context.order_edges_out,
      build_context.order_edge_tail_out,
      build_context.order_edge_head_out,
      build_context.order_ranks,
    )
    let _ = transpose_rank_groups_port(
      build_context.order_rank_keys,
      seeded_groups,
      build_context.order_ranks,
      transpose_seed_maps.edge_in,
      transpose_seed_maps.edge_out,
      build_context.order_edge_tail_out,
      build_context.order_edge_head_out,
      build_context.order_edge_tail_port_x,
      build_context.order_edge_head_port_x,
      transpose_seed_maps.edge_penalty,
      build_context.order_cluster_keys,
      build_context.order_cluster_skeleton,
      build_context.flat_rank_constraints,
      false,
      0,
    )
  }
  seeded_groups
}

///|
pub let capture_pass0_flat_seed_groups_enabled : Ref[Bool] = Ref::new(false)

///|
pub let capture_pass0_flat_seed_groups_value : Ref[Map[Int, Array[String]]?] = Ref::new(
  None,
)

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
/// Graphviz parity: root ReMincross pass0 capture wraps root rank-reorder and
/// resets shared capture state immediately after the phase call returns.
/// Do not change behavior without updating fixtures/tests.
pub fn[T] run_with_pass0_flat_seed_capture(run_phase : () -> T) -> T {
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  let result = run_phase()
  capture_pass0_flat_seed_groups_enabled.val = false
  capture_pass0_flat_seed_groups_value.val = None
  result
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
  let startpass = if startpass < 0 {
    0
  } else if startpass > 2 {
    2
  } else {
    startpass
  }
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
    let ported = @edge_identity.port_is_explicit(edge.tail_port()) ||
      @edge_identity.port_is_explicit(edge.head_port())
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
    let penalty = @edge_semantics.edge_xpenalty(edge)
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
  let node_ranks = @rank_groups.build_node_ranks(ordered)
  // Graphviz parity: cluster-local mincross uses merged rank map including
  // virtual nodes that may not be in the local rank groups.
  for name, rank in fixed_ranks {
    if node_ranks.get(name) is None {
      node_ranks[name] = rank
    }
  }
  let port_crossing_inputs = build_port_aware_crossing_inputs(
    ordered,
    edges,
    edge_tail,
    edge_head,
    ranks=node_ranks,
  )
  let mut best_ordered = @rank_groups.clone_rank_groups(ordered)
  let mut order_positions = @rank_groups.order_positions_from_groups(ordered)
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
  let sync_rank_positions = (names : Array[String]) => {
    @rank_groups.update_order_positions_for_rank(order_positions, names)
    merge_fixed_positions()
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
    if !@edge_identity.is_edge_vnode_name(name) {
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
    let base_penalty = @edge_semantics.edge_xpenalty(edge)
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    let mut penalty = base_penalty
    if coalesce_parallel_edges &&
      base_penalty > 0 &&
      @edge_semantics.edge_is_constraint(edge) {
      let tail_port_order = if edge_idx < edge_tail_port_order.length() {
        edge_tail_port_order[edge_idx]
      } else {
        0.5
      }
      let head_port_order = if edge_idx < edge_head_port_order.length() {
        edge_head_port_order[edge_idx]
      } else {
        0.5
      }
      let merge_key = "\{tail}|\{head}|\{tail_port_order.to_string()}|\{head_port_order.to_string()}"
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
    if penalty <= 0 || !@edge_semantics.edge_is_constraint(edge) {
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
      let tail_port_order = if edge_idx < edge_tail_port_order.length() {
        edge_tail_port_order[edge_idx]
      } else {
        0.5
      }
      let head_port_order = if edge_idx < edge_head_port_order.length() {
        edge_head_port_order[edge_idx]
      } else {
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
  let mut best_cross = if graphviz_style &&
    startpass > 1 &&
    startpass_init_infinite {
    2147483647
  } else if graphviz_style && startpass <= 1 {
    2147483647
  } else if graphviz_style {
    count_crossings_port_aware_with_inputs(
      rank_keys,
      ordered,
      node_ranks,
      edge_tail,
      edge_head,
      port_crossing_inputs,
      edge_tail_port_x~,
      edge_head_port_x~,
      fixed_order~,
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
      graphviz_out_neighbors~,
      graphviz_in_neighbors~,
    )
    ordered = flat_reorder_rank_groups(
      rank_keys, ordered, node_ranks, flat_constraints, graphviz_flip,
    )
    order_positions = @rank_groups.order_positions_from_groups(ordered)
    merge_fixed_positions()
    let seed_cross = count_crossings_port_aware(
      ordered, node_ranks, edges, edge_tail, edge_head, edge_tail_port_x~, edge_head_port_x~,
      fixed_order~,
    )
    if seed_cross > 0 {
      let _ = transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order~,
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
        remincross_mode~,
      )
      order_positions = @rank_groups.order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    best_ordered = @rank_groups.clone_rank_groups(ordered)
    best_cross = count_crossings(
      ordered, node_ranks, edges, edge_tail, edge_head,
    )
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
        single_names, edge_tail, edge_head, edge_penalty, graphviz_out_neighbors,
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
        rank, names, node_ranks, fixed_order, edge_in, edge_out, edge_tail, edge_head,
        edge_tail_port_x, edge_head_port_x, edge_penalty,
      )
    }
    let mut force_single_rank_probe = false
    if startpass > 1 {
      best_cross = compute_single_cross()
      best_ordered = @rank_groups.clone_rank_groups(ordered)
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
      let max_this_pass = if pass <= 1 {
        if max_iter < 4 {
          max_iter
        } else {
          4
        }
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
          graphviz_out_neighbors~,
          graphviz_in_neighbors~,
        )
        let seed_cross = compute_single_cross()
        if seed_cross > 0 {
          let _ = transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order~,
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
            remincross_mode~,
          )
        }
        ordered = flat_reorder_rank_groups(
          rank_keys, ordered, node_ranks, flat_constraints, graphviz_flip,
        )
        maybe_capture_seed_groups(pass, rank_keys, ordered)
        order_positions = @rank_groups.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = compute_single_cross()
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = @rank_groups.clone_rank_groups(ordered)
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
          order_positions = @rank_groups.order_positions_from_groups(ordered)
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
          let desired = if iter % 2 == 0 {
            compute_scaled_medians(names, median_parents, order_positions)
          } else {
            compute_scaled_medians(names, median_children, order_positions)
          }
          let hasfixed = apply_flat_mvals(
            names, desired, edge_in, edge_out, flat_constraints,
          )
          let reordered = reorder_by_medians(
            names,
            desired,
            reverse,
            hasfixed,
            cluster_keys,
            cluster_skeleton,
            flat_constraints,
            remincross_mode~,
          )
          ordered[rank] = reordered
          sync_rank_positions(reordered)
        }
        let _ = transpose_rank_groups_port(
          rank_keys,
          ordered,
          node_ranks,
          fixed_order~,
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
          remincross_mode~,
        )
        order_positions = @rank_groups.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = compute_single_cross()
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = @rank_groups.clone_rank_groups(ordered)
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
      order_positions = @rank_groups.order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    if best_cross > 0 {
      let _ = transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order~,
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
        remincross_mode~,
      )
    }
    return ordered
  }
  if graphviz_style && rank_keys.length() > 1 {
    let max_iter = 24
    let min_quit = 8
    let convergence = 0.995
    let mut force_graphviz_probe = false
    if startpass > 1 &&
      rank_keys.length() <= 3 &&
      best_cross == 0 &&
      has_graphviz_neighbor_hints {
      // Graphviz parity: ND_in/ND_out medians may drive reorder despite a
      // zero local crossing baseline.
      force_graphviz_probe = true
      best_cross = 1
    }
    let mut cur_cross = best_cross
    let mut pass = startpass
    while pass <= 2 {
      let max_this_pass = if pass <= 1 {
        if max_iter < 4 {
          max_iter
        } else {
          4
        }
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
          graphviz_out_neighbors~,
          graphviz_in_neighbors~,
        )
        // Graphviz parity: seed transpose probe runs before flat reorder in
        // each graphviz-style pass, independent of port-order hints.
        let seed_cross = count_crossings_port_aware_with_inputs(
          rank_keys,
          ordered,
          node_ranks,
          edge_tail,
          edge_head,
          port_crossing_inputs,
          edge_tail_port_x~,
          edge_head_port_x~,
          fixed_order~,
        )
        if seed_cross > 0 {
          let _ = transpose_rank_groups_port(
            rank_keys,
            ordered,
            node_ranks,
            fixed_order~,
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
            remincross_mode~,
          )
        }
        ordered = flat_reorder_rank_groups(
          rank_keys, ordered, node_ranks, flat_constraints, graphviz_flip,
        )
        maybe_capture_seed_groups(pass, rank_keys, ordered)
        order_positions = @rank_groups.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = count_crossings_port_aware_with_inputs(
          rank_keys,
          ordered,
          node_ranks,
          edge_tail,
          edge_head,
          port_crossing_inputs,
          edge_tail_port_x~,
          edge_head_port_x~,
          fixed_order~,
        )
        if cur_cross <= best_cross {
          best_cross = cur_cross
          best_ordered = @rank_groups.clone_rank_groups(ordered)
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
          order_positions = @rank_groups.order_positions_from_groups(ordered)
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
        let use_sweep_snapshot = startpass > 1 &&
          pass > 1 &&
          has_graphviz_neighbor_hints &&
          iter % 2 == 0
        let sweep_positions = if use_sweep_snapshot {
          order_positions.copy()
        } else {
          order_positions
        }
        if iter % 2 == 0 {
          let mut idx = if include_min_rank { 0 } else { 1 }
          while idx < rank_keys.length() {
            let rank = rank_keys[idx]
            let names = match ordered.get(rank) {
              Some(list) => list
              None => []
            }
            if names.length() > 1 {
              let desired_positions = if use_sweep_snapshot {
                sweep_positions
              } else {
                order_positions
              }
              let desired = compute_scaled_medians(
                names, median_parents, desired_positions,
              )
              let hasfixed = apply_flat_mvals(
                names, desired, edge_in, edge_out, flat_constraints,
              )
              let reordered = reorder_by_medians(
                names,
                desired,
                reverse,
                hasfixed,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode~,
              )
              ordered[rank] = reordered
              if !use_sweep_snapshot {
                sync_rank_positions(reordered)
              }
            }
            idx = idx + 1
          }
        } else {
          let mut idx = if include_max_rank {
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
              let desired_positions = if use_sweep_snapshot {
                sweep_positions
              } else {
                order_positions
              }
              let desired = compute_scaled_medians(
                names, median_children, desired_positions,
              )
              let hasfixed = apply_flat_mvals(
                names, desired, edge_in, edge_out, flat_constraints,
              )
              let reordered = reorder_by_medians(
                names,
                desired,
                reverse,
                hasfixed,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode~,
              )
              ordered[rank] = reordered
              if !use_sweep_snapshot {
                sync_rank_positions(reordered)
              }
            }
            if idx == 0 {
              break
            }
            idx = idx - 1
          }
        }
        if use_sweep_snapshot {
          order_positions = @rank_groups.order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        // Graphviz parity: transpose remains active with port-order hints;
        // ties are resolved by in/out port x during crossing checks.
        let _ = transpose_rank_groups_port(
          rank_keys,
          ordered,
          node_ranks,
          fixed_order~,
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
          remincross_mode~,
        )
        order_positions = @rank_groups.order_positions_from_groups(ordered)
        merge_fixed_positions()
        cur_cross = count_crossings_port_aware_with_inputs(
          rank_keys,
          ordered,
          node_ranks,
          edge_tail,
          edge_head,
          port_crossing_inputs,
          edge_tail_port_x~,
          edge_head_port_x~,
          fixed_order~,
        )
        if cur_cross <= best_cross {
          let prev_best = best_cross
          best_cross = cur_cross
          best_ordered = @rank_groups.clone_rank_groups(ordered)
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
      order_positions = @rank_groups.order_positions_from_groups(ordered)
      merge_fixed_positions()
    }
    if best_cross > 0 {
      let _ = transpose_rank_groups_port(
        rank_keys,
        ordered,
        node_ranks,
        fixed_order~,
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
        remincross_mode~,
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
                names, median_parents, order_positions,
              )
              let reordered = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode~,
              )
              ordered[rank] = reordered
              sync_rank_positions(reordered)
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
                names, median_children, order_positions,
              )
              let reordered = reorder_by_medians(
                names,
                desired,
                reverse_ties,
                false,
                cluster_keys,
                cluster_skeleton,
                flat_constraints,
                remincross_mode~,
              )
              ordered[rank] = reordered
              sync_rank_positions(reordered)
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
            fixed_order~,
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
            remincross_mode~,
          )
          order_positions = @rank_groups.order_positions_from_groups(ordered)
          merge_fixed_positions()
        }
        let cross = count_crossings_port_aware_with_inputs(
          rank_keys,
          ordered,
          node_ranks,
          edge_tail,
          edge_head,
          port_crossing_inputs,
          edge_tail_port_x~,
          edge_head_port_x~,
          fixed_order~,
        )
        if cross <= best_cross {
          best_cross = cross
          best_ordered = @rank_groups.clone_rank_groups(ordered)
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
              names, parents, order_positions, port_order_contrib, preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys, rank_same_groups, rank_same_order, edge_order, node_order,
              port_edge_nodes, edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @rank_groups.order_positions_from_groups(ordered)
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
              names, parents, order_positions, port_order_contrib, preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, parents, children, node_penalty, parents,
              cluster_keys, rank_same_groups, rank_same_order, edge_order, node_order,
              port_edge_nodes, edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @rank_groups.order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
        }
        let down_cross = count_crossings(
          ordered, node_ranks, edges, edge_tail, edge_head,
        )
        if down_cross < best_cross {
          best_cross = down_cross
          best_ordered = @rank_groups.clone_rank_groups(ordered)
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
              names, children, order_positions, port_order_contrib, preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys, rank_same_groups, rank_same_order, edge_order, node_order,
              port_edge_nodes, edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @rank_groups.order_positions_from_groups(ordered)
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
              names, children, order_positions, port_order_contrib, preferred_positions,
            )
            ordered[rank] = order_rank_by_cluster(
              names, desired, order_positions, children, parents, node_penalty, parents,
              cluster_keys, rank_same_groups, rank_same_order, edge_order, node_order,
              port_edge_nodes, edge_pair_order, port_order_positions, reverse_ties,
            )
            order_positions = @rank_groups.order_positions_from_groups(ordered)
            merge_fixed_positions()
          }
        }
        let up_cross = count_crossings(
          ordered, node_ranks, edges, edge_tail, edge_head,
        )
        if up_cross < best_cross {
          best_cross = up_cross
          best_ordered = @rank_groups.clone_rank_groups(ordered)
        }
      }
      iter = iter + 1
    }
  }
  best_ordered
}
