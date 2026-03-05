///|
/// Ordering domain: cluster graph ordering and local rank-group seeding
/// helpers used by Stage C clustered local replay.

fn cluster_depth_for_order_inner(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
  memo : Map[String, Int],
  visiting : Map[String, Bool],
) -> Int {
  match memo.get(cluster) {
    Some(value) => value
    None => {
      if visiting.get(cluster) is Some(_) {
        return 0
      }
      visiting[cluster] = true
      // Graphviz parity: cluster parent lookup prefers explicit traversal hints
      // and falls back to collected parent graph edges.
      let candidate : String? = match parents.get(cluster) {
        Some(value) => value
        None =>
          match fallback_parents.get(cluster) {
            Some(value) => value
            None => None
          }
      }
      let parent_opt : String? =
        match candidate {
          Some(value) =>
            if value == "" || value == cluster {
              None
            } else {
              Some(value)
            }
          None => None
        }
      let depth = match parent_opt {
        Some(parent) =>
          cluster_depth_for_order_inner(
            parent,
            parents,
            fallback_parents,
            memo,
            visiting,
          ) + 1
        None => 0
      }
      memo[cluster] = depth
      depth
    }
  }
}

///|
fn cluster_depth_for_order(
  cluster : String,
  parents : Map[String, String?],
  fallback_parents : Map[String, String?],
  memo : Map[String, Int],
) -> Int {
  cluster_depth_for_order_inner(
    cluster,
    parents,
    fallback_parents,
    memo,
    Map::new(),
  )
}

///|
fn cluster_order_index_or_end(
  cluster_index : Map[String, Int],
  name : String,
) -> Int {
  match cluster_index.get(name) {
    Some(value) => value
    None => cluster_index.length() + 1
  }
}

///|
/// Graphviz parity: cluster-local pass iterates cluster subgraphs in
/// depth-first parent order with cluster_order tie-breaking (cluster.c path).
/// Do not change behavior without updating fixtures/tests.
pub(all) struct LocalClusterGraphOrderOutput {
  cluster_graphs : Map[String, @cgraph.Graph]
  cluster_names : Array[String]
}

///|
/// Graphviz parity: cluster-local pass iterates cluster subgraphs in
/// depth-first parent order with cluster_order tie-breaking (cluster.c path).
/// Do not change behavior without updating fixtures/tests.
pub fn build_cluster_graph_order(
  graph : @cgraph.Graph,
  cluster_order : Array[String],
  cluster_parents_hint : Map[String, String?],
) -> LocalClusterGraphOrderOutput {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  @shared.collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  let cluster_names : Array[String] = []
  for name, _ in cluster_graphs {
    cluster_names.push(name)
  }
  if cluster_graphs.length() == 0 {
    return { cluster_graphs, cluster_names }
  }
  let cluster_index = build_cluster_order_index(cluster_order)
  let cluster_depth : Map[String, Int] = Map::new()
  for name in cluster_names {
    let _ = cluster_depth_for_order(
      name,
      cluster_parents_hint,
      cluster_parents,
      cluster_depth,
    )
  }
  if cluster_names.length() > 1 {
    cluster_names.sort_by((a, b) => {
      let a_depth = cluster_depth.get(a).unwrap_or_default()
      let b_depth = cluster_depth.get(b).unwrap_or_default()
      if a_depth < b_depth {
        -1
      } else if a_depth > b_depth {
        1
      } else {
        let a_idx = cluster_order_index_or_end(cluster_index, a)
        let b_idx = cluster_order_index_or_end(cluster_index, b)
        if a_idx < b_idx {
          -1
        } else if a_idx > b_idx {
          1
        } else {
          0
        }
      }
    })
  }
  { cluster_graphs, cluster_names }
}

///|
/// Graphviz parity: local-cluster stable sorts compare seed order first and
/// break ties by node name to keep deterministic fixture ordering.
pub fn compare_by_order_then_name(
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
fn build_rank_group_name_set(names : Array[String]) -> Map[String, Bool] {
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
  let real_set = build_rank_group_name_set(real_nodes)
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
pub fn build_local_rank_groups(
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
  let cluster_rank_keys = collect_rank_keys(cluster_groups)
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
