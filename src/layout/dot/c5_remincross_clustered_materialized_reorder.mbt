///|
/// Stage C Phase C5 split: clustered materialized-edge
/// reorder/input orchestration helpers.

///|
/// Graphviz parity: nested intercluster merge-chain bonuses are applied to the
/// first representative coalesced edge entry for each merge key.
fn apply_remincross_intercluster_bonus(
  order_edges_by_tail_coalesced : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  intercluster_bonus : Map[String, Int],
) -> Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] {
  if intercluster_bonus.length() == 0 {
    return order_edges_by_tail_coalesced
  }
  let remaining_bonus : Map[String, Int] = Map::new()
  for key, value in intercluster_bonus {
    remaining_bonus[key] = value
  }
  let adjusted : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]] =
    Map::new()
  for tail_name, entries in order_edges_by_tail_coalesced {
    let adjusted_entries : Array[(String, String, Int, Bool, Double, Double, Double, Double)] = []
    for entry in entries {
      let (tail, head, penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order) =
        entry
      let key =
        order_edge_merge_key(
          tail,
          head,
          constraint,
          tail_port_order,
          head_port_order,
        )
      let mut adjusted_penalty = penalty
      match remaining_bonus.get(key) {
        Some(extra) =>
          if extra > 0 {
            adjusted_penalty = adjusted_penalty + extra
            remaining_bonus[key] = 0
          }
        None => ()
      }
      adjusted_entries.push(
        (tail, head, adjusted_penalty, constraint, tail_port_x, head_port_x, tail_port_order, head_port_order),
      )
    }
    adjusted[tail_name] = adjusted_entries
  }
  adjusted
}

///|
/// Graphviz parity: rematerialized ReMincross edge-creation replay walks each
/// tail bucket in creation-order sequence and preserves per-tail ND_out order.
fn build_remincross_edge_creation(
  creation_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Array[(String, String)] {
  let rem_edge_creation : Array[(String, String)] = []
  for tail_name in creation_order {
    let entries = order_edges_by_tail.get(tail_name).unwrap_or_default()
    for entry in entries {
      let (tail, head, _, _, _, _, _, _) = entry
      rem_edge_creation.push((tail, head))
    }
  }
  rem_edge_creation
}

///|
/// Graphviz parity: clustered ReMincross rematerialized-order-edge tuple keeps
/// bonus-adjusted tail buckets, vnode creation, and edge creation replay order.
type ReMincrossMaterializedOrderEdges = (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
)

///|
/// Graphviz parity: clustered ReMincross materialized-edge tuple keeps node
/// order plus rematerialized edge arrays in fixed return ordering.
type ReMincrossMaterializedEdgeArrays = (
  Map[String, Int],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
)

///|
/// Graphviz parity: clustered ReMincross order-edge rematerialization applies
/// ND_out expansion, coalescing, intercluster bonus, then tail-order replay.
fn build_remincross_materialized_order_edges(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
) -> ReMincrossMaterializedOrderEdges {
  let (rem_order_edges_by_tail_raw, rem_vnode_creation, _rem_edge_creation_raw) =
    build_order_edges_by_tail(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      false,
      false,
      edges_by_tail,
      cluster_order_index=cluster_order_index,
    )
  let rem_order_edges_by_tail_coalesced =
    coalesce_order_edges_by_tail(rem_order_edges_by_tail_raw)
  let intercluster_bonus =
    collect_intercluster_vnode_tail_bonus(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      edges_by_tail,
      cluster_keys,
    )
  let rem_order_edges_by_tail =
    apply_remincross_intercluster_bonus(
      rem_order_edges_by_tail_coalesced,
      intercluster_bonus,
    )
  let rem_edge_creation =
    build_remincross_edge_creation(
      creation_order,
      rem_order_edges_by_tail,
    )
  (rem_order_edges_by_tail, rem_vnode_creation, rem_edge_creation)
}

///|
/// Graphviz parity: ReMincross order-graph materialization rebuilds GD_nlist,
/// seeds node order, then materializes edge arrays in nlist tail order.
fn build_remincross_materialized_edge_arrays(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
) -> ReMincrossMaterializedEdgeArrays {
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nlist_order =
    build_remincross_nlist_order(
      creation_order,
      rem_vnode_creation,
      rem_edge_creation,
      rem_ranks,
      cluster_keys,
      cluster_order_index,
    )
  let rem_node_order = build_order_index(rem_groups)
  let (
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  ) =
    collect_order_edges_for_tail_sequence(
      rem_nlist_order,
      rem_order_edges_by_tail,
      rem_graph,
      rem_node_map,
    )
  (
    rem_node_order,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
  )
}

///|
/// Graphviz parity: clustered ReMincross materializes remapped order edges
/// from ND_out chains, then rebuilds GD_nlist-seeded edge arrays.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_remincross_materialized_edges(
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  order_with_clusters : Bool,
  edges_by_tail : Map[String, Array[Int]],
  cluster_order_index : Map[String, Int],
  rem_graph : @cgraph.Graph,
  rem_node_map : Map[String, @cgraph.Node],
  rem_groups : Map[Int, Array[String]],
) -> ReMincrossMaterializedEdgeArrays {
  let (
    rem_order_edges_by_tail,
    rem_vnode_creation,
    rem_edge_creation,
  ) =
    build_remincross_materialized_order_edges(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      edges_by_tail,
      cluster_order_index,
    )
  build_remincross_materialized_edge_arrays(
    creation_order,
    rem_vnode_creation,
    rem_edge_creation,
    rem_order_edges_by_tail,
    rem_graph,
    rem_node_map,
    rem_groups,
    cluster_keys,
    cluster_order_index,
  )
}

///|
/// Graphviz parity: clustered ReMincross creation order starts from tail
/// creation order and appends per-tail vnode sequences with stable dedupe.
fn build_remincross_order_creation(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
) -> Array[String] {
  let rem_order_creation : Array[String] = []
  let rem_seen : Map[String, Bool] = Map::new()
  for tail_name in creation_order {
    append_order_creation_name_if_absent(
      rem_order_creation,
      rem_seen,
      tail_name,
    )
    let vnodes = rem_vnode_creation.get(tail_name).unwrap_or_default()
    for vnode in vnodes {
      append_order_creation_name_if_absent(
        rem_order_creation,
        rem_seen,
        vnode,
      )
    }
  }
  rem_order_creation
}

///|
/// Graphviz parity: clustered ReMincross tail->head adjacency keeps rematerialized
/// edge-creation order for downstream rank/block replay.
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
/// Graphviz parity: grouped ReMincross name buckets are replayed in stable
/// input order when merged into nlist/rank output vectors.
fn append_names_in_order(target : Array[String], names : Array[String]) -> Unit {
  for name in names {
    target.push(name)
  }
}

///|
/// Graphviz parity: ReMincross GD_nlist order keeps cluster-local blocks in
/// first-seen cluster sequence and replays each cluster block by rank-desc
/// reverse-order before root-cluster nodes.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_nlist_order(
  creation_order : Array[String],
  rem_vnode_creation : Map[String, Array[String]],
  rem_edge_creation : Array[(String, String)],
  rem_ranks : Map[String, Int],
  rem_cluster_keys : Map[String, String],
  cluster_order_index : Map[String, Int],
) -> Array[String] {
  let rem_order_creation =
    build_remincross_order_creation(
      creation_order,
      rem_vnode_creation,
    )
  let rem_nlist_order =
    if cluster_order_index.length() <= 2 {
      // Graphviz parity: single-cluster/root-only remincross materialization
      // replays tails in reverse rem_order_creation sequence.
      let reversed : Array[String] = []
      let mut idx = rem_order_creation.length()
      while idx > 0 {
        idx = idx - 1
        reversed.push(rem_order_creation[idx])
      }
      reversed
    } else {
      build_remincross_cluster_tail_order(
        rem_order_creation,
        rem_ranks,
        rem_cluster_keys,
        rem_edge_creation,
        cluster_order_index,
      )
    }
  if rem_nlist_order.length() < rem_order_creation.length() {
    let seen : Map[String, Bool] = Map::new()
    for name in rem_nlist_order {
      seen[name] = true
    }
    for name in rem_order_creation {
      append_order_creation_name_if_absent(rem_nlist_order, seen, name)
    }
  }
  rem_nlist_order
}

///|
/// Stage C Phase C5 split: remincross cluster tail order
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross groups names by cluster in
/// rem_order_creation order and records first-seen cluster sequence.
fn build_remincross_cluster_grouping(
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
/// Graphviz parity: clustered tail-order cluster buckets default to empty
/// name lists for clusters absent from grouping output.
fn remincross_cluster_names_or_empty(
  names_by_cluster : Map[String, Array[String]],
  cluster : String,
) -> Array[String] {
  names_by_cluster.get(cluster).unwrap_or_default()
}

///|
/// Graphviz parity: root cluster tail order can apply a temporary override
/// snapshot before replaying root names into rematerialized GD_nlist order.
fn build_remincross_root_tail_names(names : Array[String]) -> Array[String] {
  match remincross_root_tail_order_override_snapshot.val {
    Some(override_names) =>
      reorder_rank_names_by_override(
        names,
        override_names,
      )
    None => names
  }
}

///|
/// Graphviz parity: clustered tail-order per-cluster replay uses root override
/// snapshot for root cluster and non-root rank replay for other clusters.
fn build_remincross_cluster_tail_names_for_cluster(
  cluster : String,
  names : Array[String],
  rem_ranks : Map[String, Int],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  if cluster == "" {
    build_remincross_root_tail_names(names)
  } else {
    build_remincross_cluster_tail_order_nonroot_names(
      cluster,
      names,
      rem_ranks,
      heads_by_tail,
      cluster_order_pos,
      cluster_order,
      rem_cluster_keys,
    )
  }
}

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
    build_remincross_cluster_grouping(
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
    let names = remincross_cluster_names_or_empty(names_by_cluster, cluster)
    let ordered_names =
      build_remincross_cluster_tail_names_for_cluster(
        cluster,
        names,
        rem_ranks,
        heads_by_tail,
        cluster_order_pos,
        cluster_order,
        rem_cluster_keys,
      )
    append_names_in_order(rem_nlist_order, ordered_names)
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
/// Graphviz parity: clustered tail-order split keeps first-seen non-root
/// cluster sequence and tracks whether root cluster is present.
fn split_remincross_seen_clusters_root_and_nonroot(
  cluster_order_seen : Array[String],
) -> (Array[String], Bool) {
  let cluster_order_non_root : Array[String] = []
  let mut has_root_cluster = false
  for cluster in cluster_order_seen {
    if cluster == "" {
      has_root_cluster = true
    } else {
      cluster_order_non_root.push(cluster)
    }
  }
  (cluster_order_non_root, has_root_cluster)
}

///|
/// Graphviz parity: clustered tail-order position map records cluster index in
/// final cluster-order sequence for downstream cross-cluster comparisons.
fn build_remincross_cluster_order_positions(
  cluster_order : Array[String],
) -> Map[String, Int] {
  let cluster_order_pos : Map[String, Int] = Map::new()
  for idx, cluster in cluster_order {
    cluster_order_pos[cluster] = idx
  }
  cluster_order_pos
}

///|
/// Graphviz parity: clustered tail-order non-root cluster comparator uses
/// descending Graphviz cluster-order index (-1 fallback) then first-seen
/// tie-break (0 fallback).
fn compare_remincross_nonroot_clusters_for_tail_order(
  a : String,
  b : String,
  cluster_order_index : Map[String, Int],
  cluster_first_seen : Map[String, Int],
) -> Int {
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
  let a_seen = cluster_first_seen.get(a).unwrap_or_default()
  let b_seen = cluster_first_seen.get(b).unwrap_or_default()
  if a_seen < b_seen {
    -1
  } else if a_seen > b_seen {
    1
  } else {
    0
  }
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
  let (cluster_order_non_root, has_root_cluster) =
    split_remincross_seen_clusters_root_and_nonroot(cluster_order_seen)
  cluster_order_non_root.sort_by((a, b) =>
    compare_remincross_nonroot_clusters_for_tail_order(
      a,
      b,
      cluster_order_index,
      cluster_first_seen,
    ))
  let cluster_order = cluster_order_non_root
  if has_root_cluster {
    cluster_order.push("")
  }
  let cluster_order_pos =
    build_remincross_cluster_order_positions(cluster_order)
  (cluster_order, cluster_order_pos)
}

///|
/// Graphviz parity: clustered ReMincross rank lookups use -1 fallback for
/// names missing from the rematerialized rank map.
fn remincross_rank_or_missing(
  rem_ranks : Map[String, Int],
  name : String,
) -> Int {
  match rem_ranks.get(name) {
    Some(value) => value
    None => -1
  }
}

///|
/// Graphviz parity: clustered tail-order rank buckets keep first-seen unique
/// rank keys in cluster-name order, then sort ascending for reverse replay.
fn collect_remincross_rank_keys_for_cluster_names(
  names : Array[String],
  rem_ranks : Map[String, Int],
) -> Array[Int] {
  let rank_keys : Array[Int] = []
  let rank_seen : Map[Int, Bool] = Map::new()
  for name in names {
    let rank = remincross_rank_or_missing(rem_ranks, name)
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
/// rematerialized rank value (including -1 fallback bucket).
fn collect_remincross_names_at_rank(
  names : Array[String],
  rem_ranks : Map[String, Int],
  rank : Int,
) -> Array[String] {
  let rank_names : Array[String] = []
  for name in names {
    let name_rank = remincross_rank_or_missing(rem_ranks, name)
    if name_rank == rank {
      rank_names.push(name)
    }
  }
  rank_names
}

///|
/// Graphviz parity: minimum replay rank for input-like rebucketing ignores
/// missing-name (-1) buckets and falls back to -1 when absent.
fn remincross_min_nonnegative_rank_or_missing(rank_keys : Array[Int]) -> Int {
  let mut candidate = -1
  for value in rank_keys {
    if value >= 0 {
      candidate = value
      break
    }
  }
  candidate
}

///|
/// Graphviz parity: clustered non-root rank replay preserves forward rank order
/// only when every tail has no outgoing edge in the rematerialized graph.
fn remincross_rank_names_all_without_outgoing(
  rank_names : Array[String],
  heads_by_tail : Map[String, Array[String]],
) -> Bool {
  for name in rank_names {
    if heads_by_tail.get(name) is Some(_) {
      return false
    }
  }
  true
}

///|
/// Graphviz parity: clustered non-root rank replay is forward for no-outgoing
/// blocks and reverse insertion order otherwise.
fn build_remincross_nonroot_rank_ordered_names(
  rank_names : Array[String],
  heads_by_tail : Map[String, Array[String]],
) -> Array[String] {
  let rank_ordered : Array[String] = []
  if remincross_rank_names_all_without_outgoing(rank_names, heads_by_tail) {
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
/// Graphviz parity: minimum-rank rebucketing applies only to all-input-like
/// rank names (the Graphviz 'i-' synthetic input class).
fn remincross_names_all_input_like(names : Array[String]) -> Bool {
  for name in names {
    if !name.has_prefix("i-") {
      return false
    }
  }
  true
}

///|
/// Graphviz parity: minimum-rank input-like rebucketing runs only on ranks
/// that satisfy Graphviz's rank+shape preconditions.
fn maybe_rebucket_remincross_input_like_rank_order(
  cluster : String,
  rank : Int,
  min_rank : Int,
  rank_ordered : Array[String],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  if rank == min_rank &&
    rank_ordered.length() > 1 &&
    remincross_names_all_input_like(rank_ordered) {
    return rebucket_remincross_input_like_rank_order(
      cluster,
      rank_ordered,
      heads_by_tail,
      cluster_order_pos,
      cluster_order,
      rem_cluster_keys,
    )
  }
  rank_ordered
}

///|
/// Graphviz parity: clustered non-root rank replay composes rank extraction,
/// directional replay, and minimum-rank input-like rebucketing.
fn build_remincross_nonroot_rank_replay_names(
  cluster : String,
  rank : Int,
  min_rank : Int,
  names : Array[String],
  rem_ranks : Map[String, Int],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let rank_names = collect_remincross_names_at_rank(names, rem_ranks, rank)
  let rank_ordered =
    build_remincross_nonroot_rank_ordered_names(rank_names, heads_by_tail)
  maybe_rebucket_remincross_input_like_rank_order(
    cluster,
    rank,
    min_rank,
    rank_ordered,
    heads_by_tail,
    cluster_order_pos,
    cluster_order,
    rem_cluster_keys,
  )
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
  let rank_keys = collect_remincross_rank_keys_for_cluster_names(names, rem_ranks)
  let min_rank = remincross_min_nonnegative_rank_or_missing(rank_keys)
  let cluster_rank_ordered : Array[String] = []
  let mut rank_idx = rank_keys.length()
  while rank_idx > 0 {
    rank_idx = rank_idx - 1
    let rank = rank_keys[rank_idx]
    let rank_ordered =
      build_remincross_nonroot_rank_replay_names(
        cluster,
        rank,
        min_rank,
        names,
        rem_ranks,
        heads_by_tail,
        cluster_order_pos,
        cluster_order,
        rem_cluster_keys,
      )
    append_names_in_order(cluster_rank_ordered, rank_ordered)
  }
  cluster_rank_ordered
}

///|
/// Graphviz parity: input-like rebucketing classifies names by outgoing
/// cross-cluster direction and out-degree priority.
fn classify_remincross_input_like_name_bucket(
  cluster : String,
  name : String,
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_end_pos : Int,
  current_cluster_pos : Int,
  rem_cluster_keys : Map[String, String],
) -> Int {
  let heads = heads_by_tail.get(name).unwrap_or_default()
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
      None => cluster_end_pos
    }
    if head_pos > current_cluster_pos {
      has_later = true
    } else if head_pos < current_cluster_pos {
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
fn rebucket_remincross_input_like_rank_order(
  cluster : String,
  rank_ordered : Array[String],
  heads_by_tail : Map[String, Array[String]],
  cluster_order_pos : Map[String, Int],
  cluster_order : Array[String],
  rem_cluster_keys : Map[String, String],
) -> Array[String] {
  let current_cluster_pos = cluster_order_pos.get(cluster).unwrap_or_default()
  let cluster_end_pos = cluster_order.length()
  let category0 : Array[String] = []
  let category1 : Array[String] = []
  let category2 : Array[String] = []
  let category3 : Array[String] = []
  for name in rank_ordered {
    match classify_remincross_input_like_name_bucket(
      cluster,
      name,
      heads_by_tail,
      cluster_order_pos,
      cluster_end_pos,
      current_cluster_pos,
      rem_cluster_keys,
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
