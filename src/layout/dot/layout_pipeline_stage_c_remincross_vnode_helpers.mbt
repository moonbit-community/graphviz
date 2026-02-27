///|
/// Extracted from layout_pipeline_remincross_helpers.mbt to keep Stage C
/// intercluster-vnode and ReMincross seed-order helpers isolated.

///|
/// Graphviz parity: trailing-vnode marking applies only to non-internal,
/// cross-cluster edges whose endpoint cluster rank ranges do not overlap.
/// Do not change behavior without updating fixtures/tests.
fn should_trail_intercluster_vnodes_for_edge(
  tail_cluster : String,
  head_cluster : String,
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Bool {
  let internal =
    tail_cluster != "" && head_cluster != "" &&
    edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
  if internal || tail_cluster == head_cluster {
    return false
  }
  if tail_cluster == "" || head_cluster == "" {
    return false
  }
  let tail_min = match cluster_min_rank.get(tail_cluster) {
    Some(value) => value
    None => 0
  }
  let tail_max = match cluster_max_rank.get(tail_cluster) {
    Some(value) => value
    None => tail_min
  }
  let head_min = match cluster_min_rank.get(head_cluster) {
    Some(value) => value
    None => 0
  }
  let head_max = match cluster_max_rank.get(head_cluster) {
    Some(value) => value
    None => head_min
  }
  let overlap = tail_min <= head_max && head_min <= tail_max
  !overlap
}

///|
/// Graphviz parity: ReMincross trailing vnode set marks intercluster edge
/// vnodes whose endpoint cluster rank ranges do not overlap.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_trailing_vnodes(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, Bool] {
  let intercluster_vnodes : Map[String, Bool] = Map::new()
  if !order_with_vnodes {
    return intercluster_vnodes
  }
  let mut edge_idx = 0
  for edge in edges {
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = match cluster_keys.get(tail) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match cluster_keys.get(head) {
      Some(value) => value
      None => ""
    }
    if should_trail_intercluster_vnodes_for_edge(
      tail_cluster,
      head_cluster,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
    ) {
      let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
        Some(list) => list
        None => []
      }
      for vnode in vnodes {
        intercluster_vnodes[vnode] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  intercluster_vnodes
}

///|
/// Graphviz parity: trailing-vnode floor uses the maximum real-node order seen
/// per rank from the current ReMincross base order index.
/// Do not change behavior without updating fixtures/tests.
fn collect_max_real_order_by_rank_for_intercluster_floor(
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
) -> Map[Int, Int] {
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in rem_base_order_index {
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
  max_order_by_rank
}

///|
/// Graphviz parity: trailing intercluster vnodes get a minimum order key just
/// after the max real-node order on their rank (stable tiny seq offset).
/// Do not change behavior without updating fixtures/tests.
fn apply_intercluster_vnode_order_key_floor(
  keys : Map[String, Double],
  intercluster_vnodes : Map[String, Bool],
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Unit {
  if intercluster_vnodes.length() == 0 {
    return
  }
  let max_order_by_rank =
    collect_max_real_order_by_rank_for_intercluster_floor(
      rem_base_order_index,
      ranks,
    )
  let mut seq = 0
  for vnode, _ in intercluster_vnodes {
    let rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let max_order = match max_order_by_rank.get(rank) {
      Some(value) => value
      None => -1
    }
    let base = Double::from_int(max_order + 1)
    let offset = Double::from_int(seq) * 0.000001
    let min_key = base + offset
    match keys.get(vnode) {
      Some(current) =>
        if current < min_key {
          keys[vnode] = min_key
        }
      None => keys[vnode] = min_key
    }
    seq = seq + 1
  }
}

/// Graphviz parity: ReMincross creation order starts from tail creation order
/// then appends each tail vnode sequence once (stable dedupe).
/// Do not change behavior without updating fixtures/tests.
fn build_rem_order_creation_sequence(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
) -> Array[String] {
  let rem_order_creation : Array[String] = []
  let rem_seen : Map[String, Bool] = Map::new()
  for tail_name in creation_order {
    if rem_seen.get(tail_name) is None {
      rem_seen[tail_name] = true
      rem_order_creation.push(tail_name)
    }
    let vnodes = match rem_vnode_creation.get(tail_name) {
      Some(list) => list
      None => []
    }
    for vnode in vnodes {
      if rem_seen.get(vnode) is None {
        rem_seen[vnode] = true
        rem_order_creation.push(vnode)
      }
    }
  }
  rem_order_creation
}

///|
/// Graphviz parity: ReMincross vnode order keys follow vnodes_by_rank keys
/// with trailing intercluster vnode floor adjustment before rank merge.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_vnode_order_keys(
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  rem_base_order_index : Map[String, Int],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  if !order_with_vnodes {
    return Map::new()
  }
  let remincross_cluster_keys : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    remincross_cluster_keys[name] = key
  }
  let intercluster_vnodes =
    collect_intercluster_trailing_vnodes(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      remincross_cluster_keys,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
      edge_vnodes,
    )
  let keys = build_vnode_order_keys(
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    rem_base_order_index,
    remincross_cluster_keys,
    cluster_parents,
    edge_vnodes,
    vnode_ranks,
  )
  apply_intercluster_vnode_order_key_floor(
    keys,
    intercluster_vnodes,
    rem_base_order_index,
    ranks,
    vnode_ranks,
  )
  keys
}

///|
/// Graphviz parity: ReMincross rank groups start from real-node groups and
/// optionally inject edge-vnodes using vnode order keys from cluster-aware
/// trailing-vnode adjustments.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_groups_with_optional_vnodes(
  final_groups : Map[Int, Array[String]],
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let rem_base_groups = clone_rank_groups(final_groups)
  let rem_base_order_index = build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    build_remincross_vnode_order_keys(
      order_with_vnodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      rem_base_order_index,
      intercluster_keys,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
      edge_vnodes,
      vnode_ranks,
    )
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
}
