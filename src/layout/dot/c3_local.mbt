///|
/// Stage C Phase C3 split: cluster-local reorder/build-ranks
/// helpers isolated from other Stage C phases.

///|
/// Graphviz parity: local-cluster stable sorts compare seed order first and
/// break ties by node name to keep deterministic fixture ordering.
fn compare_by_order_then_name(
  order_map : Map[String, Int],
  a : String,
  b : String,
) -> Int {
  let a_idx = order_map.get(a).unwrap_or_default()
  let b_idx = order_map.get(b).unwrap_or_default()
  if a_idx < b_idx {
    -1
  } else if a_idx > b_idx {
    1
  } else if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// Graphviz parity: rank-local real-node rewrites preserve vnode slots and only
/// replace non-vnode positions in left-to-right sequence.
fn rewrite_rank_real_slots(
  list : Array[String],
  reordered_real_nodes : Array[String],
) -> Unit {
  let mut real_idx = 0
  for i in 0..<list.length() {
    if is_edge_vnode_name(list[i]) {
      continue
    }
    list[i] = reordered_real_nodes[real_idx]
    real_idx = real_idx + 1
  }
}

///|
fn collect_rank_real_nodes(list : Array[String]) -> Array[String] {
  let real_nodes : Array[String] = []
  for name in list {
    if !is_edge_vnode_name(name) {
      real_nodes.push(name)
    }
  }
  real_nodes
}

///|
fn build_name_set(names : Array[String]) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map::new()
  for name in names {
    out[name] = true
  }
  out
}

///|
/// Graphviz parity: each rank list normalizes real-node order by seeded
/// cluster node order before previous-rank reachability seeding.
fn normalize_rank_real_nodes(
  list : Array[String],
  cluster_node_order : Map[String, Int],
) -> Unit {
  if list.length() <= 1 {
    return ()
  }
  let real_nodes = collect_rank_real_nodes(list)
  if real_nodes.length() <= 1 {
    return ()
  }
  real_nodes.sort_by((a, b) => {
    compare_by_order_then_name(cluster_node_order, a, b)
  })
  rewrite_rank_real_slots(list, real_nodes)
}

///|
/// Graphviz parity: local ND_out reachability is restricted to cluster members
/// before previous-rank seeded ordering.
fn build_cluster_out_heads_by_tail(
  cluster_node_set : Map[String, Bool],
  source_graphviz_out_neighbors : Map[String, Array[String]],
) -> Map[String, Array[String]] {
  let out_heads_by_tail : Map[String, Array[String]] = Map::new()
  for tail, _ in cluster_node_set {
    let heads = source_graphviz_out_neighbors.get(tail).unwrap_or_default()
    let filtered : Array[String] = []
    for head in heads {
      if cluster_node_set.get(head) is Some(_) {
        filtered.push(head)
      }
    }
    if filtered.length() > 0 {
      out_heads_by_tail[tail] = filtered
    }
  }
  out_heads_by_tail
}

///|
/// Graphviz parity: rank real-node seeding prefers reachable heads from the
/// previous rank, then appends remaining nodes by seeded node order.
fn seed_rank_real_nodes_from_previous_rank(
  list : Array[String],
  prev_names : Array[String],
  out_heads_by_tail : Map[String, Array[String]],
  cluster_node_order : Map[String, Int],
) -> Unit {
  if list.length() <= 1 {
    return ()
  }
  let real_nodes = collect_rank_real_nodes(list)
  let real_set = build_name_set(real_nodes)
  if real_nodes.length() <= 1 {
    return ()
  }
  let seeded_real_nodes : Array[String] = []
  let seeded_seen : Map[String, Bool] = Map::new()
  for tail in prev_names {
    let heads = out_heads_by_tail.get(tail).unwrap_or_default()
    for head in heads {
      if real_set.get(head) is Some(_) && seeded_seen.get(head) is None {
        seeded_real_nodes.push(head)
        seeded_seen[head] = true
      }
    }
  }
  let fallback_real_nodes = real_nodes.copy()
  fallback_real_nodes.sort_by((a, b) => {
    compare_by_order_then_name(cluster_node_order, a, b)
  })
  for name in fallback_real_nodes {
    if seeded_seen.get(name) is None {
      seeded_real_nodes.push(name)
      seeded_seen[name] = true
    }
  }
  rewrite_rank_real_slots(list, seeded_real_nodes)
}

///|
/// Graphviz parity: local cluster rank groups include only cluster members and
/// seed each rank from previous-rank ND_out reachability before seed-order
/// fallback.
/// Do not change behavior without updating fixtures/tests.
fn build_local_rank_groups(
  groups : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
  cluster_node_order : Map[String, Int],
  source_graphviz_out_neighbors : Map[String, Array[String]],
) -> Map[Int, Array[String]] {
  let cluster_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in groups {
    let list : Array[String] = []
    for name in names {
      if cluster_node_set.get(name) is Some(_) {
        list.push(name)
      }
    }
    normalize_rank_real_nodes(list, cluster_node_order)
    if list.length() > 0 {
      cluster_groups[rank] = list
    }
  }
  let out_heads_by_tail =
    build_cluster_out_heads_by_tail(
      cluster_node_set,
      source_graphviz_out_neighbors,
    )
  let cluster_rank_keys = @ordering.collect_rank_keys(cluster_groups)
  for rank in cluster_rank_keys {
    let list = match cluster_groups.get(rank) {
      Some(value) => value
      None => continue
    }
    let prev_names = cluster_groups.get(rank - 1).unwrap_or_default()
    seed_rank_real_nodes_from_previous_rank(
      list,
      prev_names,
      out_heads_by_tail,
      cluster_node_order,
    )
  }
  cluster_groups
}


///|
/// Graphviz parity: cluster-local reorder context keeps filtered cluster nodes,
/// seeded local rank groups, and fixed-slot exclusions in one bundle.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderContext {
  cluster_node_set : Map[String, Bool]
  cluster_nodes : Array[String]
  cluster_node_order : Map[String, Int]
  cluster_groups : Map[Int, Array[String]]
  cluster_rank_keys : Array[Int]
  cluster_fixed_positions : Map[String, Double]
}

///|
/// Graphviz parity: cluster-local reorder node-order context keeps filtered
/// cluster members and deterministic local node indices built from node_order.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterNodeOrderContext {
  cluster_nodes : Array[String]
  cluster_node_order : Map[String, Int]
}

///|
/// Graphviz parity: cluster-local reorder node set keeps cluster members that
/// are present in rank groups, plus local vnodes when enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_node_set_for_reorder(
  cluster : String,
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  vnode_clusters : Map[String, String],
  order_with_vnodes : Bool,
) -> Map[String, Bool] {
  let cluster_nodes_set : Map[String, Bool] = Map::new()
  for node in cluster_graph.nodes() {
    cluster_nodes_set[node.name()] = true
  }
  if order_with_vnodes {
    for vnode, vnode_cluster in vnode_clusters {
      if vnode_cluster == cluster {
        cluster_nodes_set[vnode] = true
      }
    }
  }
  let cluster_node_set : Map[String, Bool] = Map::new()
  for _rank, names in groups {
    for name in names {
      if cluster_nodes_set.get(name) is Some(_) {
        cluster_node_set[name] = true
      }
    }
  }
  cluster_node_set
}

///|
/// Graphviz parity: cluster-local node-order context uses global node_order as
/// deterministic seed before assigning contiguous local order ids.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_node_order_context(
  cluster_node_set : Map[String, Bool],
  node_order : Map[String, Int],
) -> ClusterNodeOrderContext {
  let cluster_nodes : Array[String] = []
  for name, _ in cluster_node_set {
    cluster_nodes.push(name)
  }
  let cluster_node_order : Map[String, Int] = Map::new()
  let cluster_ordered_nodes = cluster_nodes.copy()
  if cluster_ordered_nodes.length() > 1 {
    cluster_ordered_nodes.sort_by((a, b) => {
      compare_by_order_then_name(node_order, a, b)
    })
  }
  let mut order_idx = 0
  for name in cluster_ordered_nodes {
    cluster_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  { cluster_nodes, cluster_node_order }
}

///|
/// Graphviz parity: cluster-local reorder preserves fixed slots outside the
/// active cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_fixed_positions(
  fixed_positions : Map[String, Double],
  cluster_node_set : Map[String, Bool],
) -> Map[String, Double] {
  let cluster_fixed_positions : Map[String, Double] = Map::new()
  for name, value in fixed_positions {
    if cluster_node_set.get(name) is None {
      cluster_fixed_positions[name] = value
    }
  }
  cluster_fixed_positions
}

///|
/// Graphviz parity: cluster-local reorder only considers nodes that are
/// present in rank groups and belong to the current cluster (plus local
/// virtual nodes when enabled).
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderContextBuildInputs {
  cluster : String
  cluster_graph : @cgraph.Graph
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  source_out_neighbors : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
  fixed_positions : Map[String, Double]
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: cluster-local reorder only considers nodes that are
/// present in rank groups and belong to the current cluster (plus local
/// virtual nodes when enabled).
fn build_cluster_local_reorder_context(
  inputs : ClusterLocalReorderContextBuildInputs,
) -> ClusterLocalReorderContext? {
  let cluster_node_set =
    build_cluster_node_set_for_reorder(
      inputs.cluster,
      inputs.cluster_graph,
      inputs.groups,
      inputs.vnode_clusters,
      inputs.order_with_vnodes,
    )
  if cluster_node_set.length() <= 1 {
    return None
  }
  let node_order_context =
    build_cluster_node_order_context(
      cluster_node_set,
      inputs.node_order,
    )
  let cluster_nodes = node_order_context.cluster_nodes
  let cluster_node_order = node_order_context.cluster_node_order
  let cluster_groups = build_local_rank_groups(
    inputs.groups,
    cluster_node_set,
    cluster_node_order,
    inputs.source_out_neighbors,
  )
  let cluster_rank_keys = @ordering.collect_rank_keys(cluster_groups)
  let cluster_fixed_positions =
    build_cluster_fixed_positions(inputs.fixed_positions, cluster_node_set)
  Some({
    cluster_node_set,
    cluster_nodes,
    cluster_node_order,
    cluster_groups,
    cluster_rank_keys,
    cluster_fixed_positions,
  })
}
