// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Ordering domain: clustered finalize rank-group cleanup and cluster-bucket
/// replay helpers used by the ReMincross owner package.
///
/// Graphviz parity: this file owns the post-root cleanup that drops non-real
/// nodes, replays root-derived cluster bucket order, and reapplies
/// local-cluster order before clustered ReMincross.

///|
/// Graphviz parity: final rank groups drop non-real nodes after root ordering,
/// preserving rank iteration order and per-rank sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_real_only_rank_groups(
  rank_keys : Array[Int],
  ordered : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  let cleaned_groups : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    let names = ordered.get(rank).unwrap_or_default()
    let cleaned : Array[String] = []
    for name in names {
      if real_nodes.get(name) is Some(_) {
        cleaned.push(name)
      }
    }
    if cleaned.length() > 0 {
      cleaned_groups[rank] = cleaned
    }
  }
  cleaned_groups
}

///|
/// Graphviz parity: within each outer-cluster rank bucket, local subclusters
/// are ordered by local-cluster rank order with stable in-rank tie-breaks.
/// Do not change behavior without updating fixtures/tests.
fn reorder_groups_by_local_cluster(
  groups : Map[Int, Array[String]],
  outer_cluster_keys : Map[String, String],
  local_cluster_keys : Map[String, String],
  local_cluster_order : Map[String, Int],
) -> Unit {
  if local_cluster_order.length() == 0 {
    return ()
  }
  for _rank, names in groups {
    if names.length() <= 1 {
      continue
    }
    let positions_by_outer : Map[String, Array[Int]] = Map::new()
    let nodes_by_outer : Map[String, Array[String]] = Map::new()
    for i in 0..<names.length() {
      let name = names[i]
      let outer = @order_graph.cluster_key_or_empty(outer_cluster_keys, name)
      if outer == "" {
        continue
      }
      match positions_by_outer.get(outer) {
        Some(list) => list.push(i)
        None => positions_by_outer[outer] = [i]
      }
      match nodes_by_outer.get(outer) {
        Some(list) => list.push(name)
        None => nodes_by_outer[outer] = [name]
      }
    }
    for outer, positions in positions_by_outer {
      let outer_nodes = nodes_by_outer.get(outer).unwrap_or_default()
      if outer_nodes.length() <= 1 {
        continue
      }
      let local_groups : Map[String, Array[String]] = Map::new()
      let local_seen : Map[String, Bool] = Map::new()
      let local_order_in_rank : Array[String] = []
      let local_order_index : Map[String, Int] = Map::new()
      for name in outer_nodes {
        let local_key = @order_graph.cluster_key_or_empty(
          local_cluster_keys, name,
        )
        if local_key == "" {
          continue
        }
        if local_seen.get(local_key) is None {
          local_seen[local_key] = true
          local_order_in_rank.push(local_key)
          local_order_index[local_key] = local_order_in_rank.length() - 1
          local_groups[local_key] = []
        }
        match local_groups.get(local_key) {
          Some(list) => list.push(name)
          None => local_groups[local_key] = [name]
        }
      }
      if local_groups.length() <= 1 {
        continue
      }
      let local_sorted = local_order_in_rank.copy()
      local_sorted.sort_by((a, b) => {
        let a_order = local_cluster_order.get(a).unwrap_or_default()
        let b_order = local_cluster_order.get(b).unwrap_or_default()
        if a_order < b_order {
          -1
        } else if a_order > b_order {
          1
        } else {
          let a_idx = local_order_index.get(a).unwrap_or_default()
          let b_idx = local_order_index.get(b).unwrap_or_default()
          if a_idx < b_idx {
            -1
          } else if a_idx > b_idx {
            1
          } else {
            0
          }
        }
      })
      let merged : Array[String] = []
      for key in local_sorted {
        let list = local_groups.get(key).unwrap_or_default()
        for name in list {
          merged.push(name)
        }
      }
      let pos_sorted = positions.copy()
      pos_sorted.sort()
      let mut idx = 0
      while idx < pos_sorted.length() && idx < merged.length() {
        names[pos_sorted[idx]] = merged[idx]
        idx = idx + 1
      }
    }
  }
}

///|
/// Graphviz parity: clustered-block bounds are the first/last clustered-name
/// positions in the rank, with (-1, -1) when no clustered names exist.
priv struct ClusterBlockBounds {
  first_cluster : Int
  last_cluster : Int
}

///|
/// Graphviz parity: clustered-block bounds are the first/last clustered-name
/// positions in the rank, with (-1, -1) when no clustered names exist.
fn find_cluster_block_bounds(
  names : Array[String],
  cluster_keys : Map[String, String],
) -> ClusterBlockBounds {
  let mut first_cluster = -1
  let mut last_cluster = -1
  for i in 0..<names.length() {
    let cluster = @order_graph.cluster_key_or_empty(cluster_keys, names[i])
    if cluster != "" {
      if first_cluster < 0 {
        first_cluster = i
      }
      last_cluster = i
    }
  }
  { first_cluster, last_cluster }
}

///|
/// Graphviz parity: root/non-cluster presence checks on one side of clustered
/// blocks scan rank names in-order and stop at first root bucket member.
fn has_root_node_in_range(
  names : Array[String],
  cluster_keys : Map[String, String],
  start_idx : Int,
  end_idx : Int,
) -> Bool {
  let mut i = start_idx
  while i < end_idx {
    if @order_graph.cluster_key_or_empty(cluster_keys, names[i]) == "" {
      return true
    }
    i = i + 1
  }
  false
}

///|
/// Graphviz parity: cluster-rank-order guard keeps original rank order when
/// root nodes appear on both sides of the clustered node block in one rank.
fn has_root_nodes_on_both_sides(
  names : Array[String],
  cluster_keys : Map[String, String],
) -> Bool {
  if names.length() <= 2 {
    return false
  }
  let cluster_block_bounds = find_cluster_block_bounds(names, cluster_keys)
  let first_cluster = cluster_block_bounds.first_cluster
  if first_cluster < 0 {
    return false
  }
  let root_before = has_root_node_in_range(
    names, cluster_keys, 0, first_cluster,
  )
  let root_after = if cluster_block_bounds.last_cluster + 1 >= names.length() {
    false
  } else {
    has_root_node_in_range(
      names,
      cluster_keys,
      cluster_block_bounds.last_cluster + 1,
      names.length(),
    )
  }
  root_before && root_after
}

///|
priv struct ClusterOrderBucket {
  order : Int
  seq_idx : Int
  cluster : String
}

///|
/// Graphviz parity: cluster bucket grouping keeps first-seen cluster sequence,
/// orders buckets by root rank-order map, and preserves intra-bucket order.
/// Do not change behavior without updating fixtures/tests.
fn order_rank_names_by_cluster_buckets(
  names : Array[String],
  order_map : Map[String, Int],
  cluster_keys : Map[String, String],
) -> Array[String] {
  let cluster_nodes : Map[String, Array[String]] = Map::new()
  let cluster_seq : Array[String] = []
  for name in names {
    let cluster = @order_graph.cluster_key_or_empty(cluster_keys, name)
    match cluster_nodes.get(cluster) {
      Some(list) => list.push(name)
      None => {
        cluster_nodes[cluster] = [name]
        cluster_seq.push(cluster)
      }
    }
  }
  let cluster_ordered : Array[ClusterOrderBucket] = []
  for idx, cluster in cluster_seq {
    let base = order_map.get(cluster).unwrap_or(order_map.length() + idx)
    cluster_ordered.push({ order: base, seq_idx: idx, cluster })
  }
  if cluster_ordered.length() > 1 {
    cluster_ordered.sort_by((a, b) => {
      if a.order < b.order {
        -1
      } else if a.order > b.order {
        1
      } else if a.seq_idx < b.seq_idx {
        -1
      } else if a.seq_idx > b.seq_idx {
        1
      } else {
        0
      }
    })
  }
  let ordered_names : Array[String] = []
  for entry in cluster_ordered {
    let nodes_in_cluster = cluster_nodes.get(entry.cluster).unwrap_or_default()
    for name in nodes_in_cluster {
      ordered_names.push(name)
    }
  }
  ordered_names
}

///|
/// Graphviz parity: per-rank cluster replay applies root rank-order only when
/// an order map exists and root nodes do not straddle clustered block bounds.
/// Do not change behavior without updating fixtures/tests.
fn reorder_rank_group_by_cluster_order(
  names : Array[String],
  order_map : Map[String, Int]?,
  cluster_keys : Map[String, String],
) -> Array[String] {
  match order_map {
    None => names
    Some(value) =>
      // Graphviz parity: per-rank cluster-rank-order replay preserves original
      // rank order when root nodes straddle clustered block.
      if has_root_nodes_on_both_sides(names, cluster_keys) {
        names
      } else {
        order_rank_names_by_cluster_buckets(names, value, cluster_keys)
      }
  }
}

///|
/// Graphviz parity: cluster-phase reorder keeps intra-cluster node order, then
/// reorders cluster buckets by root mincross rank map with stable tie-breaks.
/// Do not change behavior without updating fixtures/tests.
fn reorder_groups_by_cluster(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let ordered_by_cluster : Map[Int, Array[String]] = Map::new()
  for rank, names in final_groups {
    ordered_by_cluster[rank] = reorder_rank_group_by_cluster_order(
      names,
      cluster_rank_order.get(rank),
      cluster_keys,
    )
  }
  ordered_by_cluster
}

///|
/// Graphviz parity: cluster-rank reorder is skipped when root reorder exposes
/// a single-cluster single-anchor shape (one cluster bucket globally and at
/// most one clustered node per rank).
fn should_skip_cluster_rank_bucket_reorder(
  cluster_rank_order : Map[Int, Map[String, Int]],
  cleaned_groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Bool {
  let seen_clusters : Map[String, Bool] = Map::new()
  let mut has_single_cluster_rank_order_bucket = true
  for _rank, order_map in cluster_rank_order {
    if !has_single_cluster_rank_order_bucket {
      break
    }
    for cluster, _order in order_map {
      if cluster == "" {
        continue
      }
      seen_clusters[cluster] = true
      if seen_clusters.length() > 1 {
        has_single_cluster_rank_order_bucket = false
        break
      }
    }
  }
  if has_single_cluster_rank_order_bucket && seen_clusters.length() != 1 {
    return false
  }
  if !has_single_cluster_rank_order_bucket {
    return false
  }
  for _rank, names in cleaned_groups {
    let mut cluster_nodes = 0
    for name in names {
      if @order_graph.cluster_key_or_empty(cluster_keys, name) != "" {
        cluster_nodes = cluster_nodes + 1
        if cluster_nodes > 1 {
          return false
        }
      }
    }
  }
  true
}

///|
/// Graphviz parity: clustered finalize groups keep cleaned real-node ranks,
/// optionally apply cluster-rank bucket reorder, then apply local-cluster
/// ordering before final ReMincross.
/// Do not change behavior without updating fixtures/tests.
pub fn build_clustered_finalize_groups(
  cleaned_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
  local_cluster_keys : Map[String, String],
  local_cluster_order : Map[String, Int],
) -> Map[Int, Array[String]] {
  let should_skip_cluster_rank_reorder = should_skip_cluster_rank_bucket_reorder(
    cluster_rank_order, cleaned_groups, cluster_keys,
  )
  let final_groups = if should_skip_cluster_rank_reorder {
    cleaned_groups
  } else {
    reorder_groups_by_cluster(cleaned_groups, cluster_rank_order, cluster_keys)
  }
  reorder_groups_by_local_cluster(
    final_groups, cluster_keys, local_cluster_keys, local_cluster_order,
  )
  final_groups
}
