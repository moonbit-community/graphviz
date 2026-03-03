///|
/// Ordering domain: clustered ReMincross vnode-group rebuild helpers used by
/// Stage C cleanup dispatch when seeded groups are not reused.

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
/// Graphviz parity: intercluster trailing-vnode checks use inclusive overlap
/// over each cluster's min/max rank bounds with min-rank fallback.
fn cluster_rank_ranges_overlap(
  tail_cluster : String,
  head_cluster : String,
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Bool {
  let tail_min = cluster_min_rank.get(tail_cluster).unwrap_or_default()
  let tail_max = cluster_max_rank.get(tail_cluster).unwrap_or(tail_min)
  let head_min = cluster_min_rank.get(head_cluster).unwrap_or_default()
  let head_max = cluster_max_rank.get(head_cluster).unwrap_or(head_min)
  tail_min <= head_max && head_min <= tail_max
}

///|
/// Graphviz parity: trailing-vnode candidate set comes from intercluster edge
/// vnode chains on edges that satisfy the rank-range overlap gate.
fn collect_remincross_trailing(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_vnodes : Map[String, Array[String]],
  remincross_cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_vnodes : Map[String, Bool] = Map::new()
  for edge_idx, edge in edges {
    let (tail, head) =
      edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    let tail_cluster = remincross_cluster_keys.get(tail).unwrap_or_default()
    let head_cluster = remincross_cluster_keys.get(head).unwrap_or_default()
    // Graphviz parity: trailing-vnode tagging applies only to non-internal,
    // non-root, cross-cluster edges whose cluster rank ranges do not overlap.
    let internal =
      tail_cluster != "" && head_cluster != "" &&
      edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
    if internal ||
      tail_cluster == head_cluster ||
      tail_cluster == "" ||
      head_cluster == "" {
      continue
    }
    if cluster_rank_ranges_overlap(
      tail_cluster,
      head_cluster,
      cluster_min_rank,
      cluster_max_rank,
    ) {
      continue
    }
    let vnodes =
      edge_vnodes.get(@shared.edge_vnode_key(edge)).unwrap_or_default()
    for vnode in vnodes {
      intercluster_vnodes[vnode] = true
    }
  }
  intercluster_vnodes
}

///|
/// Graphviz parity: trailing intercluster vnodes are floored behind real-node
/// positions on their rank using stable sequence offsets.
fn apply_remincross_floor(
  keys : Map[String, Double],
  intercluster_vnodes : Map[String, Bool],
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Unit {
  if intercluster_vnodes.length() == 0 {
    return ()
  }
  // Graphviz parity: trailing-vnode floor uses maximum real-node order per
  // rank from the current ReMincross base order index.
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
  let mut seq = 0
  for vnode, _ in intercluster_vnodes {
    let rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let max_order = max_order_by_rank.get(rank).unwrap_or(-1)
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

///|
/// Graphviz parity: clustered ReMincross vnode-group rebuild inputs keep the
/// base groups and cluster/vnode context unchanged before vnode merge replay.
pub(all) struct ReMincrossVnodeGroupInputs {
  final_groups : Map[Int, Array[String]]
  order_with_vnodes : Bool
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  ranks : Map[String, Int]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
}

///|
/// Graphviz parity: ReMincross vnode order keys come from base vnode-order
/// scoring plus trailing-vnode floor adjustments for selected intercluster
/// vnode chains.
fn build_remincross_vnode_keys(
  inputs : ReMincrossVnodeGroupInputs,
  rem_base_order_index : Map[String, Int],
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
) -> Map[String, Double] {
  let remincross_cluster_keys : Map[String, String] = Map::new()
  for name, key in inputs.intercluster_keys {
    remincross_cluster_keys[name] = key
  }
  let intercluster_vnodes =
    collect_remincross_trailing(
      inputs.edges,
      inputs.edge_tail,
      inputs.edge_head,
      inputs.edge_vnodes,
      remincross_cluster_keys,
      inputs.cluster_parents,
      inputs.cluster_min_rank,
      inputs.cluster_max_rank,
    )
  let keys = build_vnode_order_keys(
    inputs.edges,
    inputs.edge_tail,
    inputs.edge_head,
    inputs.edge_reversed,
    inputs.ranks,
    rem_base_order_index,
    remincross_cluster_keys,
    inputs.cluster_parents,
    inputs.edge_vnodes,
    inputs.vnode_ranks,
  )
  apply_remincross_floor(
    keys,
    intercluster_vnodes,
    rem_base_order_index,
    inputs.ranks,
    inputs.vnode_ranks,
  )
  keys
}

///|
/// Graphviz parity: ReMincross rank groups start from real-node groups and
/// optionally inject edge-vnodes using vnode order keys from cluster-aware
/// trailing-vnode adjustments.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_vnode_groups(
  inputs : ReMincrossVnodeGroupInputs,
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
) -> Map[Int, Array[String]] {
  let rem_base_groups = clone_rank_groups(inputs.final_groups)
  let rem_base_order_index = build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    if !inputs.order_with_vnodes {
      Map::new()
    } else {
      build_remincross_vnode_keys(
        inputs,
        rem_base_order_index,
        build_vnode_order_keys,
      )
    }
  if inputs.order_with_vnodes {
    build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      inputs.vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
}
