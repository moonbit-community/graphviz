///|
/// Stage C Phase C5 split: remincross cluster tail order phase
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered tail-order cluster lookup uses explicit
/// rem_cluster_keys with skeleton-name fallback parsing.
/// Do not change behavior without updating fixtures/tests.
fn cluster_key_for_remincross_tail_order_name(
  rem_cluster_keys : Map[String, String],
  name : String,
) -> String {
  let direct = match rem_cluster_keys.get(name) {
    Some(value) => value
    None => ""
  }
  if direct != "" {
    return direct
  }
  if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
    return ""
  }
  let prefix_len = CLUSTER_SKELETON_PREFIX.length()
  let len = name.length()
  if prefix_len >= len {
    return ""
  }
  let suffix = name.unsafe_substring(start=prefix_len, end=len)
  match suffix.find("@") {
    Some(pos) =>
      if pos > 0 { suffix.unsafe_substring(start=0, end=pos) } else { "" }
    None => ""
  }
}

///|
/// Graphviz parity: clustered tail-order setup preserves first-seen cluster
/// sequence while grouping rem_order_creation names by cluster key.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_order_seen_and_names(
  rem_order_creation : Array[String],
  rem_cluster_keys : Map[String, String],
) -> (Array[String], Map[String, Array[String]], Map[String, Int]) {
  let cluster_order_seen : Array[String] = []
  let cluster_seen : Map[String, Bool] = Map::new()
  let names_by_cluster : Map[String, Array[String]] = Map::new()
  for name in rem_order_creation {
    let cluster =
      cluster_key_for_remincross_tail_order_name(
        rem_cluster_keys,
        name,
      )
    if cluster_seen.get(cluster) is None {
      cluster_seen[cluster] = true
      cluster_order_seen.push(cluster)
    }
    match names_by_cluster.get(cluster) {
      Some(list) => list.push(name)
      None => names_by_cluster[cluster] = [name]
    }
  }
  let cluster_first_seen : Map[String, Int] = Map::new()
  for idx, cluster in cluster_order_seen {
    cluster_first_seen[cluster] = idx
  }
  (cluster_order_seen, names_by_cluster, cluster_first_seen)
}

///|
/// Graphviz parity: clustered tail-order cluster ordering sorts non-root
/// clusters by descending cluster_order_index, then by first-seen sequence.
/// Root cluster always remains last when present.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_order_and_positions(
  cluster_order_seen : Array[String],
  cluster_first_seen : Map[String, Int],
  cluster_order_index : Map[String, Int],
) -> (Array[String], Map[String, Int]) {
  let cluster_order_non_root : Array[String] = []
  let mut has_root_cluster = false
  for cluster in cluster_order_seen {
    if cluster == "" {
      has_root_cluster = true
    } else {
      cluster_order_non_root.push(cluster)
    }
  }
  cluster_order_non_root.sort_by((a, b) => {
    let a_idx = match cluster_order_index.get(a) {
      Some(value) => value
      None => -1
    }
    let b_idx = match cluster_order_index.get(b) {
      Some(value) => value
      None => -1
    }
    if a_idx > b_idx {
      return -1
    }
    if a_idx < b_idx {
      return 1
    }
    let a_seen = match cluster_first_seen.get(a) {
      Some(value) => value
      None => 0
    }
    let b_seen = match cluster_first_seen.get(b) {
      Some(value) => value
      None => 0
    }
    if a_seen < b_seen {
      -1
    } else if a_seen > b_seen {
      1
    } else {
      0
    }
  })
  let cluster_order = cluster_order_non_root
  if has_root_cluster {
    cluster_order.push("")
  }
  let cluster_order_pos : Map[String, Int] = Map::new()
  for idx, cluster in cluster_order {
    cluster_order_pos[cluster] = idx
  }
  (cluster_order, cluster_order_pos)
}

///|
/// Graphviz parity: clustered tail-order setup preserves rem_edge_creation
/// tail insertion order in heads_by_tail adjacency buckets.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_heads_by_tail(
  rem_edge_creation : Array[(String, String)],
) -> Map[String, Array[String]] {
  let heads_by_tail : Map[String, Array[String]] = Map::new()
  for edge in rem_edge_creation {
    let (tail, head) = edge
    match heads_by_tail.get(tail) {
      Some(list) => list.push(head)
      None => heads_by_tail[tail] = [head]
    }
  }
  heads_by_tail
}
