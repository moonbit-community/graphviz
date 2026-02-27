///|
/// Stage C Phase C5 split: remincross vnode order
/// helpers for creation/order-key projection.

///|
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
