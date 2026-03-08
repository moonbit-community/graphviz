///|
/// Ordering domain: vnode order-key derivation helpers shared by class2,
/// ReMincross cleanup, and Stage D x-seed preparation.

///|
/// Graphviz parity: cluster containment walk for intercluster vnode tagging.
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
/// Graphviz parity: edge is internal to a cluster when tail/head clusters are
/// equal or ancestor/descendant related.
pub fn edge_internal_to_cluster(
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
/// Graphviz parity: seed vnode order from GD_nlist order within each rank.
/// Do not change behavior without updating fixtures/tests.
pub fn build_vnode_keys_from_nlist(
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
    @cluster_identity.is_cluster_skeleton_name(name)
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
        let left_key = if prev_order >= 0 {
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
/// Graphviz parity: vnode order keys interpolate tail/head order values while
/// preserving cluster-internal edge treatment and trailing-root vnode placement.
/// Do not change behavior without updating fixtures/tests.
pub fn build_vnode_order_keys(
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
  let _ = edge_reversed
  let keys : Map[String, Double] = Map::new()
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in order_index {
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    match max_order_by_rank.get(rank) {
      Some(current) => if order > current { max_order_by_rank[rank] = order }
      None => max_order_by_rank[rank] = order
    }
  }
  let mut edge_idx = 0
  for edge in edges {
    let current_idx = edge_idx
    edge_idx = edge_idx + 1
    let vnodes = edge_vnodes
      .get(@edge_identity.edge_vnode_key(edge))
      .unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let (tail, head) = edge_endpoints_at(
      edge, current_idx, edge_tail, edge_head,
    )
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => continue
    }
    let tail_cluster = cluster_keys.get(tail).unwrap_or_default()
    let head_cluster = cluster_keys.get(head).unwrap_or_default()
    let tail_order = order_index.get(tail).unwrap_or_default()
    let head_order = order_index.get(head).unwrap_or_default()
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
    let internal = tail_cluster != "" &&
      head_cluster != "" &&
      edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
    let trail_external = !internal &&
      (
        (tail_cluster == "" && head_cluster != "") ||
        (tail_cluster != "" && head_cluster == "")
      )
    let edge_offset = Double::from_int(current_idx) * 0.001
    let mut vnode_seq = 0
    for vnode in vnodes {
      let vnode_rank = match vnode_ranks.get(vnode) {
        Some(value) => value
        None => continue
      }
      let t = Double::from_int(vnode_rank - low_rank) / span_f
      let mut base_key = if same_order {
        // Graphviz parity: when tail/head orders match, vnodes precede
        // nodes with that order in the intermediate ranks.
        low_order_f - (1.0 - t)
      } else {
        low_order_f + (high_order_f - low_order_f) * t
      }
      if trail_external {
        // Graphviz parity: edges crossing cluster boundaries from/to root
        // place vnodes after real nodes on the rank.
        let max_order = max_order_by_rank.get(vnode_rank).unwrap_or(-1)
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
