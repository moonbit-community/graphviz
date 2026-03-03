///|
/// Ordering domain: clustered ReMincross tail-order replay helpers used to
/// rebuild GD_nlist from rematerialized creation/edge sequences.

///|
/// Graphviz parity: grouped ReMincross name buckets are replayed in stable
/// input order when merged into nlist/rank output vectors.
fn append_names_in_order(target : Array[String], names : Array[String]) -> Unit {
  for name in names {
    target.push(name)
  }
}

///|
/// Graphviz parity: ReMincross GD_nlist order is rebuilt from creation order
/// + vnode expansion + fast-graph edge insertion order (decompose parity).
/// Do not change behavior without updating fixtures/tests.
pub fn build_cluster_tail_order(
  rem_order_creation : Array[String],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  rem_edge_creation : Array[(String, String)],
  cluster_order_index : Map[String, Int],
  root_tail_order_override : Array[String]?,
) -> Array[String] {
  let cluster_tail_buckets =
    build_cluster_tail_buckets(rem_order_creation, rem_cluster_keys)
  let cluster_order_output =
    build_remincross_order(
      cluster_tail_buckets.cluster_order_seen,
      cluster_tail_buckets.cluster_first_seen,
      cluster_order_index,
    )
  let cluster_order = cluster_order_output.cluster_order
  let cluster_order_pos = cluster_order_output.cluster_order_pos
  let heads_by_tail =
    build_heads_by_tail_from_edge_creation(rem_edge_creation)
  let context =
    {
      rem_ranks,
      heads_by_tail,
      cluster_order_pos,
      cluster_order,
      rem_cluster_keys,
      root_tail_order_override,
    }
  let rem_nlist_order : Array[String] = []
  for cluster in cluster_order {
    // Graphviz parity: cluster buckets default to empty when absent from
    // grouped creation-order names.
    let names =
      cluster_tail_buckets.names_by_cluster.get(cluster).unwrap_or_default()
    let ordered_names =
      build_cluster_tail_names_for_cluster(cluster, names, context)
    append_names_in_order(rem_nlist_order, ordered_names)
  }
  rem_nlist_order
}

///|
/// Graphviz parity: clustered ReMincross groups names by cluster in
/// creation-order sequence and records first-seen cluster order.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterTailBuckets {
  cluster_order_seen : Array[String]
  names_by_cluster : Map[String, Array[String]]
  cluster_first_seen : Map[String, Int]
}

///|
/// Graphviz parity: cluster tail-order context keeps rematerialized rank and
/// tail->head adjacency snapshots for per-cluster ordered-name replay.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterTailOrderContext {
  rem_ranks : Map[String, Int]
  heads_by_tail : Map[String, Array[String]]
  cluster_order_pos : Map[String, Int]
  cluster_order : Array[String]
  rem_cluster_keys : Map[String, String]
  root_tail_order_override : Array[String]?
}

///|
/// Graphviz parity: clustered ReMincross groups names by cluster in
/// creation-order sequence and records first-seen cluster order.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_tail_buckets(
  rem_order_creation : Array[String],
  rem_cluster_keys : Map[String, String],
) -> ClusterTailBuckets {
  // Graphviz parity: clustered ReMincross groups names by cluster in
  // rem_order_creation order and records first-seen cluster sequence.
  let cluster_order_seen : Array[String] = []
  let cluster_seen : Map[String, Bool] = Map::new()
  let names_by_cluster : Map[String, Array[String]] = Map::new()
  for name in rem_order_creation {
    let cluster =
      cluster_key_for_tail_name(
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
  { cluster_order_seen, names_by_cluster, cluster_first_seen }
}

///|
/// Graphviz parity: clustered ReMincross tail->head adjacency keeps
/// rematerialized edge-creation order for downstream rank/block replay.
/// Do not change behavior without updating fixtures/tests.
fn build_heads_by_tail_from_edge_creation(
  rem_edge_creation : Array[(String, String)],
) -> Map[String, Array[String]] {
  // Graphviz parity: clustered ReMincross tail->head adjacency keeps
  // rematerialized edge-creation order for downstream rank/block replay.
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
/// Graphviz parity: cluster-tail ordered-name replay keeps root override
/// behavior and non-root rank replay rules for one cluster bucket.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_tail_names_for_cluster(
  cluster : String,
  names : Array[String],
  context : ClusterTailOrderContext,
) -> Array[String] {
  if cluster == "" {
    // Graphviz parity: root cluster tail order can apply a temporary
    // override snapshot before replaying root names into GD_nlist.
    return match context.root_tail_order_override {
      Some(override_names) =>
        reorder_names_by_override(
          names,
          override_names,
        )
      None => names
    }
  }
  build_nonroot_tail_names(
    cluster,
    names,
    context.rem_ranks,
    context.heads_by_tail,
    context.cluster_order_pos,
    context.cluster_order,
    context.rem_cluster_keys,
  )
}

///|
/// Graphviz parity: clustered tail-order cluster lookup uses explicit
/// rem_cluster_keys with skeleton-name fallback parsing.
/// Do not change behavior without updating fixtures/tests.
fn cluster_key_for_tail_name(
  rem_cluster_keys : Map[String, String],
  name : String,
) -> String {
  let direct = rem_cluster_keys.get(name).unwrap_or_default()
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
/// Graphviz parity: clustered tail-order cluster ordering sorts non-root
/// clusters by descending cluster_order_index, then by first-seen sequence.
/// Root cluster always remains last when present.
/// Do not change behavior without updating fixtures/tests.
priv struct ReMincrossClusterOrder {
  cluster_order : Array[String]
  cluster_order_pos : Map[String, Int]
}

///|
/// Graphviz parity: clustered tail-order cluster ordering sorts non-root
/// clusters by descending cluster_order_index, then by first-seen sequence.
/// Root cluster always remains last when present.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_order(
  cluster_order_seen : Array[String],
  cluster_first_seen : Map[String, Int],
  cluster_order_index : Map[String, Int],
) -> ReMincrossClusterOrder {
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
    // Graphviz parity: non-root clusters sort by descending Graphviz
    // cluster-order index (-1 fallback), then first-seen tie-break.
    let a_idx = cluster_order_index.get(a).unwrap_or(-1)
    let b_idx = cluster_order_index.get(b).unwrap_or(-1)
    if a_idx > b_idx {
      return -1
    }
    if a_idx < b_idx {
      return 1
    }
    let a_seen = cluster_first_seen.get(a).unwrap_or_default()
    let b_seen = cluster_first_seen.get(b).unwrap_or_default()
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
  { cluster_order, cluster_order_pos }
}

///|
/// Graphviz parity: clustered non-root rank replay is forward for no-outgoing
/// blocks and reverse insertion order otherwise.
fn build_nonroot_ordered_names(
  rank_names : Array[String],
  heads_by_tail : Map[String, Array[String]],
) -> Array[String] {
  let rank_ordered : Array[String] = []
  // Graphviz parity: preserve forward rank order only when every tail has no
  // outgoing edge in the rematerialized graph.
  let mut all_without_outgoing = true
  for name in rank_names {
    if heads_by_tail.get(name) is Some(_) {
      all_without_outgoing = false
      break
    }
  }
  if all_without_outgoing {
    append_names_in_order(rank_ordered, rank_names)
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
/// Graphviz parity: clustered tail-order rank buckets keep first-seen unique
/// rank keys in cluster-name order, then sort ascending for reverse replay.
/// Do not change behavior without updating fixtures/tests.
fn collect_nonroot_tail_rank_keys(
  names : Array[String],
  rem_ranks : Map[String, Int],
) -> Array[Int] {
  let rank_keys : Array[Int] = []
  let rank_seen : Map[Int, Bool] = Map::new()
  for name in names {
    let rank = rem_ranks.get(name).unwrap_or(-1)
    if rank_seen.get(rank) is None {
      rank_seen[rank] = true
      rank_keys.push(rank)
    }
  }
  rank_keys.sort()
  rank_keys
}

///|
/// Graphviz parity: clustered tail-order rank replay groups names by exact
/// rematerialized rank value (including -1 fallback rank bucket).
/// Do not change behavior without updating fixtures/tests.
fn collect_nonroot_tail_rank_names(
  names : Array[String],
  rem_ranks : Map[String, Int],
  rank : Int,
) -> Array[String] {
  let rank_names : Array[String] = []
  for name in names {
    if rem_ranks.get(name).unwrap_or(-1) == rank {
      rank_names.push(name)
    }
  }
  rank_names
}

///|
/// Graphviz parity: clustered tail-order non-root phase preserves rank-key
/// collection, descending rank replay, and input-like category rebucketing.
/// Do not change behavior without updating fixtures/tests.
fn build_nonroot_tail_names(
  cluster : String,
  names : Array[String],
  rem_ranks : Map[String, Int],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let rank_keys =
    collect_nonroot_tail_rank_keys(names, rem_ranks)
  // Graphviz parity: minimum replay rank for input-like rebucketing ignores
  // missing-name (-1) buckets and falls back to -1 when absent.
  let mut min_rank = -1
  for value in rank_keys {
    if value >= 0 {
      min_rank = value
      break
    }
  }
  let cluster_rank_ordered : Array[String] = []
  let mut rank_idx = rank_keys.length()
  while rank_idx > 0 {
    rank_idx = rank_idx - 1
    let rank = rank_keys[rank_idx]
    let rank_names =
      collect_nonroot_tail_rank_names(
        names,
        rem_ranks,
        rank,
      )
    let rank_ordered_base =
      build_nonroot_ordered_names(rank_names, heads_by_tail)
    // Graphviz parity: minimum-rank input-like rebucketing runs only on ranks
    // that satisfy Graphviz's rank+shape preconditions.
    let mut all_input_like = true
    for name in rank_ordered_base {
      if !name.has_prefix("i-") {
        all_input_like = false
        break
      }
    }
    let rank_ordered =
      if rank == min_rank && rank_ordered_base.length() > 1 && all_input_like {
        rebucket_input_like_order(
          cluster,
          rank_ordered_base,
          heads_by_tail,
          cluster_order_pos,
          cluster_order,
          rem_cluster_keys,
        )
      } else {
        rank_ordered_base
      }
    append_names_in_order(cluster_rank_ordered, rank_ordered)
  }
  cluster_rank_ordered
}

///|
/// Graphviz parity: input-like category classification context keeps cluster
/// order positions and rematerialized edge lookups for one rank rebucket pass.
/// Do not change behavior without updating fixtures/tests.
priv struct InputLikeBucketContext {
  cluster : String
  heads_by_tail : Map[String, Array[String]]
  cluster_order_pos : Map[String, Int]
  cluster_end_pos : Int
  current_cluster_pos : Int
  rem_cluster_keys : Map[String, String]
}

///|
/// Graphviz parity: input-like rebucketing classifies names by outgoing
/// cross-cluster direction and out-degree priority.
fn classify_input_like_bucket(
  name : String,
  context : InputLikeBucketContext,
) -> Int {
  let heads = context.heads_by_tail.get(name).unwrap_or_default()
  let mut has_later = false
  let mut has_earlier = false
  for head in heads {
    let head_cluster =
      cluster_key_for_tail_name(context.rem_cluster_keys, head)
    if head_cluster == context.cluster {
      continue
    }
    let head_pos =
      context.cluster_order_pos.get(head_cluster).unwrap_or(context.cluster_end_pos)
    if head_pos > context.current_cluster_pos {
      has_later = true
    } else if head_pos < context.current_cluster_pos {
      has_earlier = true
    }
  }
  let out_degree = heads.length()
  if !has_later && !has_earlier && out_degree > 1 {
    return 0
  }
  if has_later {
    return 1
  }
  if has_earlier {
    return 2
  }
  3
}

///|
/// Graphviz parity: minimum-rank all-input-like clustered rank blocks are
/// rebucketed by outgoing cross-cluster direction and out-degree priority.
/// Do not change behavior without updating fixtures/tests.
fn rebucket_input_like_order(
  cluster : String,
  rank_ordered : Array[String],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let context =
    {
      cluster,
      heads_by_tail,
      cluster_order_pos,
      cluster_end_pos: cluster_order.length(),
      current_cluster_pos:
        cluster_order_pos.get(cluster).unwrap_or_default(),
      rem_cluster_keys,
    }
  let category0 : Array[String] = []
  let category1 : Array[String] = []
  let category2 : Array[String] = []
  let category3 : Array[String] = []
  for name in rank_ordered {
    match classify_input_like_bucket(
      name,
      context,
    ) {
      0 => category0.push(name)
      1 => category1.push(name)
      2 => category2.push(name)
      _ => category3.push(name)
    }
  }
  let reordered_rank : Array[String] = []
  append_names_in_order(reordered_rank, category0)
  append_names_in_order(reordered_rank, category1)
  append_names_in_order(reordered_rank, category2)
  append_names_in_order(reordered_rank, category3)
  reordered_rank
}
