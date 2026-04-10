// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Ordering domain: root-phase cluster-rank-order replay helpers used by the
/// clustered Stage C root pass and its finalize replay callback.

///|
/// Graphviz parity: root-anchor transfer only applies on the single-left
/// cluster hand-off shape from the previous rank map.
fn select_root_left_anchor(
  order_map : Map[String, Int],
  previous_order_map : Map[String, Int]?,
) -> String? {
  let prev_map = match previous_order_map {
    Some(value) => value
    None => return None
  }
  let prev_root = match prev_map.get("") {
    Some(value) => value
    None => return None
  }
  let mut prev_cluster_count = 0
  let mut left_anchor : String? = None
  let mut left_order = 0
  let mut has_left = false
  let mut has_right = false
  for cluster, order in prev_map {
    if cluster == "" {
      continue
    }
    prev_cluster_count = prev_cluster_count + 1
    if order_map.get(cluster) is None {
      continue
    }
    if order < prev_root {
      if !has_left || order > left_order {
        left_anchor = Some(cluster)
        left_order = order
        has_left = true
      }
    } else if order > prev_root {
      has_right = true
    }
  }
  // Guardrail: only apply this on the simple single-left-anchor shape
  // seen in cluster hand-off ranks (e.g. clust5 rank transition).
  if prev_cluster_count != 1 || !has_left || has_right {
    return None
  }
  left_anchor
}

///|
/// Graphviz parity: cluster-rank sort keys are normalized into deterministic
/// non-root order by (order, cluster-name) before root-anchor transfer.
fn build_sorted_non_root_clusters(
  order_map : Map[String, Int],
) -> Array[String] {
  let entries : Array[(Int, String)] = []
  for cluster, order in order_map {
    if cluster == "" {
      continue
    }
    entries.push((order, cluster))
  }
  if entries.length() > 1 {
    entries.sort_by((a, b) => {
      let (a_order, a_cluster) = a
      let (b_order, b_cluster) = b
      if a_order < b_order {
        -1
      } else if a_order > b_order {
        1
      } else if a_cluster < b_cluster {
        -1
      } else if a_cluster > b_cluster {
        1
      } else {
        0
      }
    })
  }
  let sorted_clusters : Array[String] = []
  for entry in entries {
    let (_order, cluster) = entry
    sorted_clusters.push(cluster)
  }
  sorted_clusters
}

///|
/// Graphviz parity: root-anchor transfer inserts root bucket immediately
/// after the selected left-anchor cluster in sorted non-root order.
fn build_root_anchor_reordered_clusters(
  sorted_clusters : Array[String],
  left_anchor : String,
) -> Array[String] {
  let mut insert_idx = sorted_clusters.length()
  for i in 0..<sorted_clusters.length() {
    if sorted_clusters[i] == left_anchor {
      insert_idx = i + 1
      break
    }
  }
  let reordered : Array[String] = []
  for i in 0..<sorted_clusters.length() {
    if i == insert_idx {
      reordered.push("")
    }
    reordered.push(sorted_clusters[i])
  }
  if insert_idx >= sorted_clusters.length() {
    reordered.push("")
  }
  reordered
}

///|
fn rewrite_cluster_order_map(
  order_map : Map[String, Int],
  ordered_clusters : Array[String],
) -> Unit {
  let mut idx = 0
  for cluster in ordered_clusters {
    order_map[cluster] = idx
    idx = idx + 1
  }
}

///|
/// Graphviz parity: root real-node bucket keeps relative left/right anchor
/// continuity across adjacent ranks when both ranks expose root buckets.
/// Do not change behavior without updating fixtures/tests.
fn anchor_root_bucket(
  order_map : Map[String, Int],
  previous_order_map : Map[String, Int]?,
) -> Unit {
  if order_map.get("") is None {
    return ()
  }
  let left_anchor = match
    select_root_left_anchor(order_map, previous_order_map) {
    Some(value) => value
    None => return ()
  }
  let sorted_clusters = build_sorted_non_root_clusters(order_map)
  if sorted_clusters.length() == 0 {
    return ()
  }
  let reordered_clusters = build_root_anchor_reordered_clusters(
    sorted_clusters, left_anchor,
  )
  rewrite_cluster_order_map(order_map, reordered_clusters)
}

///|
/// Graphviz parity: root mincross rank map records first-seen cluster
/// skeleton buckets and one root-real bucket in rank-sequence order.
fn build_rank_cluster_bucket_order_map(
  names : Array[String],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  real_nodes : Map[String, Bool],
) -> Map[String, Int] {
  let order_map : Map[String, Int] = Map::new()
  let mut idx = 0
  for name in names {
    if order_cluster_skeleton.get(name) == Some(true) {
      let cluster = @order_graph.cluster_key_or_empty(order_cluster_keys, name)
      if cluster != "" && order_map.get(cluster) is None {
        order_map[cluster] = idx
        idx = idx + 1
      }
      continue
    }
    if real_nodes.get(name) is Some(_) {
      let cluster = @order_graph.cluster_key_or_empty(order_cluster_keys, name)
      if cluster == "" && order_map.get("") is None {
        order_map[""] = idx
        idx = idx + 1
      }
    }
  }
  order_map
}

///|
/// Graphviz parity: cluster-phase rank-order map records first-seen cluster
/// skeleton buckets (or root bucket) per rank, with root-anchor transfer
/// between adjacent ranks when anchor preconditions match.
fn build_cluster_order_from_root(
  root_rank_keys : Array[Int],
  ordered_root : Map[Int, Array[String]],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  real_nodes : Map[String, Bool],
) -> Map[Int, Map[String, Int]] {
  let cluster_rank_order : Map[Int, Map[String, Int]] = Map::new()
  let mut previous_order_map : Map[String, Int]? = None
  for rank in root_rank_keys {
    let names = ordered_root.get(rank).unwrap_or_default()
    let order_map = build_rank_cluster_bucket_order_map(
      names, order_cluster_keys, order_cluster_skeleton, real_nodes,
    )
    anchor_root_bucket(order_map, previous_order_map)
    if order_map.length() > 0 {
      cluster_rank_order[rank] = order_map
      previous_order_map = Some(order_map)
    }
  }
  cluster_rank_order
}
