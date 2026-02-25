///|
fn unique_virtual_node_name(
  prefix : String,
  edge_index : Int,
  rank : Int,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = "\{prefix}\{edge_index}_\{rank}"
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{prefix}\{edge_index}_\{rank}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}

///|
fn is_edge_vnode_name(name : String) -> Bool {
  name.has_prefix(EDGE_VNODE_PREFIX)
}

fn edge_vnode_edge_index(name : String) -> Int? {
  if !name.has_prefix(EDGE_VNODE_PREFIX) {
    return None
  }
  let rest =
    name.unsafe_substring(start=EDGE_VNODE_PREFIX.length(), end=name.length())
  parse_int_prefix(rest)
}

///|
fn cluster_contains(
  ancestor : String,
  target : String,
  cluster_parents : Map[String, String?],
) -> Bool {
  if ancestor == "" {
    return true
  }
  if target == "" {
    return false
  }
  let mut current : String? = Some(target)
  let seen : Map[String, Bool] = Map::new()
  while current is Some(name) {
    if seen.get(name) is Some(_) {
      return false
    }
    seen[name] = true
    if name == ancestor {
      return true
    }
    let parent = match cluster_parents.get(name) {
      Some(value) => value
      None => None
    }
    current = parent
  }
  false
}

///|
fn edge_internal_to_cluster(
  tail_cluster : String,
  head_cluster : String,
  cluster_parents : Map[String, String?],
) -> Bool {
  if tail_cluster == head_cluster {
    return true
  }
  if cluster_contains(tail_cluster, head_cluster, cluster_parents) {
    return true
  }
  if cluster_contains(head_cluster, tail_cluster, cluster_parents) {
    return true
  }
  false
}

///|
/// Graphviz parity: keep vnode order stable for edges sharing a tail.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_tail_constraints(
  vnodes_by_rank : Map[Int, Array[String]],
  edge_tail : Array[String],
) -> Map[String, Bool] {
  let constraints : Map[String, Bool] = Map::new()
  for _rank, names in vnodes_by_rank {
    if names.length() <= 1 {
      continue
    }
    let by_tail : Map[String, Array[(Int, String)]] = Map::new()
    for name in names {
      if !name.has_prefix(EDGE_VNODE_PREFIX) {
        continue
      }
      match edge_vnode_edge_index(name) {
        Some(edge_idx) =>
          if edge_idx >= 0 && edge_idx < edge_tail.length() {
            let tail = edge_tail[edge_idx]
            match by_tail.get(tail) {
              Some(list) => list.push((edge_idx, name))
              None => by_tail[tail] = [(edge_idx, name)]
            }
          }
        None => ()
      }
    }
    for _tail, entries in by_tail {
      if entries.length() <= 1 {
        continue
      }
      let sorted = entries.copy()
      sorted.sort_by((a, b) => {
        let (idx_a, _name_a) = a
        let (idx_b, _name_b) = b
        if idx_a < idx_b {
          -1
        } else if idx_a > idx_b {
          1
        } else {
          0
        }
      })
      let mut i = 1
      while i < sorted.length() {
        let (_idx_prev, prev_name) = sorted[i - 1]
        let (_idx_curr, curr_name) = sorted[i]
        if prev_name != curr_name {
          constraints["\{prev_name}|\{curr_name}"] = true
        }
        i = i + 1
      }
    }
  }
  constraints
}
///|
/// Graphviz parity: vnode order keys interpolate tail/head orders (class2/build_ranks).
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_keys(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  let keys : Map[String, Double] = Map::new()
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in order_index {
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    match max_order_by_rank.get(rank) {
      Some(current) =>
        if order > current {
          max_order_by_rank[rank] = order
        }
      None => max_order_by_rank[rank] = order
    }
  }
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = if current_idx < edge_tail.length() { edge_tail[current_idx] } else {
      edge.tail().name()
    }
    let head = if current_idx < edge_head.length() { edge_head[current_idx] } else {
      edge.head().name()
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    let tail_order = match order_index.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_order = match order_index.get(head) {
      Some(value) => value
      None => 0
    }
    let (low_rank, high_rank, low_order, high_order) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_order, head_order)
    } else {
      (head_rank, tail_rank, head_order, tail_order)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    let low_order_f = Double::from_int(low_order)
    let high_order_f = Double::from_int(high_order)
    let same_order = low_order == high_order
    let internal =
      tail_cluster != "" && head_cluster != "" &&
      edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
    let trail_external =
      !internal &&
      ((tail_cluster == "" && head_cluster != "") ||
        (tail_cluster != "" && head_cluster == ""))
    let edge_offset = Double::from_int(current_idx) * 0.001
    let mut vnode_seq = 0
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let mut base_key =
        if same_order {
          // Graphviz parity: when tail/head orders match, vnodes precede
          // nodes with that order in the intermediate ranks.
          low_order_f - (1.0 - t)
        } else {
          low_order_f + (high_order_f - low_order_f) * t
        }
      if trail_external {
        // Graphviz parity: edges crossing cluster boundaries from/to root
        // place vnodes after real nodes on the rank.
        let max_order = match max_order_by_rank.get(vnode_rank) {
          Some(value) => value
          None => -1
        }
        let min_key = Double::from_int(max_order + 1)
        let vnode_offset = Double::from_int(vnode_seq) * 0.000001
        if base_key < min_key {
          base_key = min_key + edge_offset + vnode_offset
        } else {
          base_key = base_key + edge_offset + vnode_offset
        }
      }
      keys[vnode] = base_key
      vnode_seq = vnode_seq + 1
    }
  }
  keys
}

///|
/// Graphviz parity: seed vnode order from GD_nlist order within each rank.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_keys_from_nlist(
  ordered_groups : Map[Int, Array[String]],
  vnodes_by_rank : Map[Int, Array[String]],
  order_index : Map[String, Int],
  nlist_order_index : Map[String, Int],
  _intercluster_vnodes : Map[String, Bool],
  _has_clusters : Bool,
) -> Map[String, Double] {
  let keys : Map[String, Double] = Map::new()
  let rank_set : Map[Int, Bool] = Map::new()
  for rank, _ in ordered_groups {
    rank_set[rank] = true
  }
  for rank, _ in vnodes_by_rank {
    rank_set[rank] = true
  }
  let ranks : Array[Int] = []
  for rank, _ in rank_set {
    ranks.push(rank)
  }
  ranks.sort()
  let get_order = (name : String) => {
    match order_index.get(name) {
      Some(value) => value
      None => -1
    }
  }
  let get_nlist = (name : String) => {
    match nlist_order_index.get(name) {
      Some(value) => value
      None => 1_000_000_000
    }
  }
  let is_intercluster = (name : String) => {
    _has_clusters && _intercluster_vnodes.get(name) == Some(true)
  }
  // Graphviz parity: ignore cluster skeleton nodes when seeding vnode order keys.
  let is_skeleton = (name : String) => {
    name.has_prefix(CLUSTER_SKELETON_PREFIX)
  }
  let assign_interval = (
    vnodes : Array[String],
    left_key : Double,
    right_key : Double,
  ) => {
    let count = vnodes.length()
    if count == 0 {
      return ()
    }
    let span = right_key - left_key
    let denom = (count + 1).to_double()
    for i in 0..<count {
      let t = (i + 1).to_double() / denom
      keys[vnodes[i]] = left_key + span * t
    }
  }
  for rank in ranks {
    let real_names = match ordered_groups.get(rank) {
      Some(list) => list.filter(name => !is_skeleton(name))
      None => []
    }
    let vnodes = match vnodes_by_rank.get(rank) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let real_set : Map[String, Bool] = Map::new()
    for name in real_names {
      real_set[name] = true
    }
    let combined : Array[String] = []
    for name in real_names {
      combined.push(name)
    }
    for name in vnodes {
      combined.push(name)
    }
    combined.sort_by((a, b) => {
      let a_inter = is_intercluster(a)
      let b_inter = is_intercluster(b)
      if a_inter != b_inter {
        if a_inter {
          1
        } else {
          -1
        }
      } else {
        let a_idx = get_nlist(a)
        let b_idx = get_nlist(b)
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
    if real_names.length() == 0 {
      let mut idx = 0
      for name in combined {
        if real_set.get(name) is None {
          keys[name] = idx.to_double()
          idx = idx + 1
        }
      }
      continue
    }
    let interval : Array[String] = []
    let mut prev_order = -1
    let mut first_real_order : Int? = None
    for name in combined {
      if real_set.get(name) == Some(true) {
        let ord = get_order(name)
        if ord >= 0 && first_real_order is None {
          first_real_order = Some(ord)
        }
        let left_key =
          if prev_order >= 0 {
          prev_order.to_double()
        } else {
          let base = match first_real_order {
            Some(value) => value
            None => ord
          }
          (base - 1).to_double()
        }
        let right_key = ord.to_double()
        assign_interval(interval, left_key, right_key)
        interval.clear()
        prev_order = ord
      } else {
        interval.push(name)
      }
    }
    if interval.length() > 0 {
      let left_key = prev_order.to_double()
      let right_key = (prev_order + 1).to_double()
      assign_interval(interval, left_key, right_key)
    }
  }
  keys
}

///|
fn flat_label_adjacent(
  rank : Int,
  tail : String,
  head : String,
  ordered_groups : Map[Int, Array[String]],
) -> Bool {
  let names = match ordered_groups.get(rank) {
    Some(list) => list
    None => []
  }
  if names.length() == 0 {
    return false
  }
  let mut tail_idx = -1
  let mut head_idx = -1
  for i in 0..<names.length() {
    if names[i] == tail {
      tail_idx = i
    }
    if names[i] == head {
      head_idx = i
    }
  }
  if tail_idx < 0 || head_idx < 0 {
    return false
  }
  let diff = if tail_idx > head_idx {
    tail_idx - head_idx
  } else {
    head_idx - tail_idx
  }
  diff <= 1
}

///|
fn collect_vnode_out_heads(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out_heads : Map[String, Array[String]] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else { edge.tail().name() }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else { edge.head().name() }
    edge_idx = edge_idx + 1
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let path : Array[String] = []
    path.push(tail)
    if tail_rank <= head_rank {
      for vnode in vnodes {
        path.push(vnode)
      }
    } else {
      let mut idx = vnodes.length()
      while idx > 0 {
        idx = idx - 1
        path.push(vnodes[idx])
      }
    }
    path.push(head)
    let mut i = 0
    while i + 1 < path.length() {
      let from = path[i]
      let to = path[i + 1]
      if is_edge_vnode_name(from) {
        match out_heads.get(from) {
          Some(list) => list.push(to)
          None => out_heads[from] = [to]
        }
      }
      i = i + 1
    }
  }
  out_heads
}

///|
fn flat_limits(
  rank_nodes : Array[String],
  order_index : Map[String, Int],
  flat_label_nodes : Map[String, FlatLabelNodeInfo],
  vnode_out_heads : Map[String, Array[String]],
  tail : String,
  head : String,
) -> Int {
  let tail_pos = match order_index.get(tail) {
    Some(value) => value
    None => 0
  }
  let head_pos = match order_index.get(head) {
    Some(value) => value
    None => 0
  }
  let lpos = if tail_pos <= head_pos { tail_pos } else { head_pos }
  let rpos = if tail_pos <= head_pos { head_pos } else { tail_pos }
  let n = rank_nodes.length()
  if n == 0 {
    return 0
  }
  let mut lnode = 0
  let mut rnode = n - 1
  let bounds : Array[Int] = [lnode - 1, rnode + 1, lnode - 1, rnode + 1]
  let setbounds = (name : String) => {
    let is_flat = flat_label_nodes.get(name) is Some(_)
    if !is_flat && !is_edge_vnode_name(name) {
      return ()
    }
    let ord = match order_index.get(name) {
      Some(value) => value
      None => return ()
    }
    match flat_label_nodes.get(name) {
      Some(info) => {
        let tail_ord = match order_index.get(info.tail) {
          Some(value) => value
          None => return ()
        }
        let head_ord = match order_index.get(info.head) {
          Some(value) => value
          None => return ()
        }
        let left = if tail_ord <= head_ord { tail_ord } else { head_ord }
        let right = if tail_ord <= head_ord { head_ord } else { tail_ord }
        if right <= lpos {
          bounds[2] = ord
          bounds[0] = ord
        } else if left >= rpos {
          bounds[3] = ord
          bounds[1] = ord
        } else if left < lpos && right > rpos {
          ()
        } else {
          if left < lpos || (left == lpos && right < rpos) {
            bounds[2] = ord
          }
          if right > rpos || (right == rpos && left > lpos) {
            bounds[3] = ord
          }
        }
      }
      None => {
        let heads = match vnode_out_heads.get(name) {
          Some(list) => list
          None => []
        }
        let mut onleft = false
        let mut onright = false
        for head_name in heads {
          let head_ord = match order_index.get(head_name) {
            Some(value) => value
            None => continue
          }
          if head_ord <= lpos {
            onleft = true
          }
          if head_ord >= rpos {
            onright = true
          }
        }
        if onleft && !onright {
          bounds[0] = ord + 1
        }
        if onright && !onleft {
          bounds[1] = ord - 1
        }
      }
    }
  }
  while lnode <= rnode {
    setbounds(rank_nodes[lnode])
    if lnode != rnode {
      setbounds(rank_nodes[rnode])
    }
    lnode = lnode + 1
    rnode = rnode - 1
    if bounds[1] - bounds[0] <= 1 {
      break
    }
  }
  if bounds[0] <= bounds[1] {
    (bounds[0] + bounds[1] + 1) / 2
  } else {
    (bounds[2] + bounds[3] + 1) / 2
  }
}

///|
fn vnode_positions_from_endpoints(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  node_positions : Map[String, Double],
  rank_y : Map[Int, Double],
) -> Map[String, @geom.Point] {
  let positions : Map[String, @geom.Point] = Map::new()
  for edge in edges {
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_pos = match node_positions.get(tail) {
      Some(value) => value
      None => 0.0
    }
    let head_pos = match node_positions.get(head) {
      Some(value) => value
      None => 0.0
    }
    let (low_rank, high_rank, low_pos, high_pos) = if tail_rank <= head_rank {
      (tail_rank, head_rank, tail_pos, head_pos)
    } else {
      (head_rank, tail_rank, head_pos, tail_pos)
    }
    let span = high_rank - low_rank
    if span <= 0 {
      continue
    }
    let span_f = Double::from_int(span)
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let pos_x = low_pos + (high_pos - low_pos) * t
      let pos_y = match rank_y.get(vnode_rank) {
        Some(value) => value
        None => 0.0
      }
      positions[vnode] = { x: pos_x, y: pos_y }
    }
  }
  positions
}
