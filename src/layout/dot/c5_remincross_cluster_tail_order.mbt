///|
/// Stage C Phase C5 split: remincross cluster tail order
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_tail_order(
  rem_order_creation : Array[String],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_edge_creation : Array[(String, String)],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let (cluster_order_seen, names_by_cluster, cluster_first_seen) =
    build_remincross_cluster_order_seen_and_names(
      rem_order_creation,
      rem_cluster_keys,
    )
  let (cluster_order, cluster_order_pos) =
    build_remincross_cluster_order_and_positions(
      cluster_order_seen,
      cluster_first_seen,
      cluster_order_index,
    )
  let heads_by_tail = build_remincross_heads_by_tail(rem_edge_creation)
  let rem_nlist_order : Array[String] = []
  for cluster in cluster_order {
    let names = match names_by_cluster.get(cluster) {
      Some(list) => list
      None => []
    }
    if cluster == "" {
      let root_names = match remincross_root_tail_order_override_snapshot.val {
        Some(override_names) =>
          reorder_rank_names_by_override(
            names,
            override_names,
          )
        None => names
      }
      for name in root_names {
        rem_nlist_order.push(name)
      }
      continue
    }
    let nonroot_rank_ordered =
      build_remincross_cluster_tail_order_nonroot_names(
        cluster,
        names,
        rem_ranks,
        heads_by_tail,
        cluster_order_pos,
        cluster_order,
        rem_cluster_keys,
      )
    for name in nonroot_rank_ordered {
      rem_nlist_order.push(name)
    }
  }
  rem_nlist_order
}

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

///|
/// Graphviz parity: clustered tail-order non-root phase preserves rank-key
/// collection, descending rank replay, and input-like category rebucketing.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_tail_order_nonroot_names(
  cluster : String,
  names : Array[String],
  rem_ranks : Map[String, Int],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let rank_keys : Array[Int] = []
  let rank_seen : Map[Int, Bool] = Map::new()
  for name in names {
    let rank = match rem_ranks.get(name) {
      Some(value) => value
      None => -1
    }
    if rank_seen.get(rank) is None {
      rank_seen[rank] = true
      rank_keys.push(rank)
    }
  }
  rank_keys.sort()
  let min_rank = {
    let mut candidate = -1
    for value in rank_keys {
      if value >= 0 {
        candidate = value
        break
      }
    }
    candidate
  }
  let cluster_rank_ordered : Array[String] = []
  let mut rank_idx = rank_keys.length()
  while rank_idx > 0 {
    rank_idx = rank_idx - 1
    let rank = rank_keys[rank_idx]
    let rank_names : Array[String] = []
    for name in names {
      let name_rank = match rem_ranks.get(name) {
        Some(value) => value
        None => -1
      }
      if name_rank == rank {
        rank_names.push(name)
      }
    }
    let rank_ordered =
      build_remincross_cluster_rank_ordered_names(
        cluster,
        rank_names,
        heads_by_tail,
      )
    let mut all_input_like = true
    for name in rank_ordered {
      if !name.has_prefix("i-") {
        all_input_like = false
        break
      }
    }
    if rank == min_rank && rank_ordered.length() > 1 && all_input_like {
      let reordered_rank =
        rebucket_remincross_input_like_rank_order(
          cluster,
          rank_ordered,
          heads_by_tail,
          cluster_order_pos,
          cluster_order,
          rem_cluster_keys,
        )
      let mut idx = 0
      while idx < reordered_rank.length() {
        rank_ordered[idx] = reordered_rank[idx]
        idx = idx + 1
      }
    }
    for name in rank_ordered {
      cluster_rank_ordered.push(name)
    }
  }
  cluster_rank_ordered
}

///|
/// Graphviz parity: clustered tail-order rank names remain forward when all
/// names have no outgoing edges in non-root cluster blocks; otherwise replayed
/// in reverse insertion order.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_rank_ordered_names(
  cluster : String,
  rank_names : Array[String],
  heads_by_tail : Map[String, Array[String]],
) -> Array[String] {
  let rank_ordered : Array[String] = []
  let mut all_without_outgoing = true
  for name in rank_names {
    if heads_by_tail.get(name) is Some(_) {
      all_without_outgoing = false
      break
    }
  }
  if cluster != "" && all_without_outgoing {
    for name in rank_names {
      rank_ordered.push(name)
    }
    return rank_ordered
  }
  let mut name_idx = rank_names.length()
  while name_idx > 0 {
    name_idx = name_idx - 1
    rank_ordered.push(rank_names[name_idx])
  }
  rank_ordered
}

///|
/// Graphviz parity: minimum-rank all-input-like clustered rank blocks are
/// rebucketed by outgoing cross-cluster direction and out-degree priority.
/// Do not change behavior without updating fixtures/tests.
fn rebucket_remincross_input_like_rank_order(
  cluster : String,
  rank_ordered : Array[String],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let current_cluster_pos = match cluster_order_pos.get(cluster) {
    Some(value) => value
    None => 0
  }
  let category0 : Array[String] = []
  let category1 : Array[String] = []
  let category2 : Array[String] = []
  let category3 : Array[String] = []
  for name in rank_ordered {
    let heads = match heads_by_tail.get(name) {
      Some(list) => list
      None => []
    }
    let mut has_later = false
    let mut has_earlier = false
    for head in heads {
      let head_cluster =
        cluster_key_for_remincross_tail_order_name(rem_cluster_keys, head)
      if head_cluster == cluster {
        continue
      }
      let head_pos = match cluster_order_pos.get(head_cluster) {
        Some(value) => value
        None => cluster_order.length()
      }
      if head_pos > current_cluster_pos {
        has_later = true
      } else if head_pos < current_cluster_pos {
        has_earlier = true
      }
    }
    let out_degree = heads.length()
    if !has_later && !has_earlier && out_degree > 1 {
      category0.push(name)
    } else if has_later {
      category1.push(name)
    } else if has_earlier {
      category2.push(name)
    } else {
      category3.push(name)
    }
  }
  let reordered_rank : Array[String] = []
  for name in category0 {
    reordered_rank.push(name)
  }
  for name in category1 {
    reordered_rank.push(name)
  }
  for name in category2 {
    reordered_rank.push(name)
  }
  for name in category3 {
    reordered_rank.push(name)
  }
  reordered_rank
}
