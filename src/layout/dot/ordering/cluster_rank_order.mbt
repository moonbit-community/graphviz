///|
/// Ordering domain: cluster-rank-order replay and rank-group filtering
/// helpers shared by clustered Stage C root/finalize phases.

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
  let left_anchor = match select_root_left_anchor(
    order_map,
    previous_order_map,
  ) {
    Some(value) => value
    None => return ()
  }
  let sorted_clusters = build_sorted_non_root_clusters(order_map)
  if sorted_clusters.length() == 0 {
    return ()
  }
  let reordered_clusters =
    build_root_anchor_reordered_clusters(sorted_clusters, left_anchor)
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
      let cluster = cluster_key_or_empty(order_cluster_keys, name)
      if cluster != "" && order_map.get(cluster) is None {
        order_map[cluster] = idx
        idx = idx + 1
      }
      continue
    }
    if real_nodes.get(name) is Some(_) {
      let cluster = cluster_key_or_empty(order_cluster_keys, name)
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
pub fn build_cluster_order_from_root(
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
    let order_map =
      build_rank_cluster_bucket_order_map(
        names,
        order_cluster_keys,
        order_cluster_skeleton,
        real_nodes,
      )
    anchor_root_bucket(
      order_map,
      previous_order_map,
    )
    if order_map.length() > 0 {
      cluster_rank_order[rank] = order_map
      previous_order_map = Some(order_map)
    }
  }
  cluster_rank_order
}

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
    let cluster = cluster_key_or_empty(cluster_keys, names[i])
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
    if cluster_key_or_empty(cluster_keys, names[i]) == "" {
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
  let cluster_block_bounds =
    find_cluster_block_bounds(names, cluster_keys)
  let first_cluster = cluster_block_bounds.first_cluster
  if first_cluster < 0 {
    return false
  }
  let root_before =
    has_root_node_in_range(
      names,
      cluster_keys,
      0,
      first_cluster,
    )
  let root_after =
    if cluster_block_bounds.last_cluster + 1 >= names.length() {
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
    let cluster = cluster_key_or_empty(cluster_keys, name)
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
    Some(value) => {
      // Graphviz parity: per-rank cluster-rank-order replay preserves original
      // rank order when root nodes straddle clustered block.
      if has_root_nodes_on_both_sides(names, cluster_keys) {
        names
      } else {
        order_rank_names_by_cluster_buckets(
          names,
          value,
          cluster_keys,
        )
      }
    }
  }
}

///|
/// Graphviz parity: cluster-phase reorder keeps intra-cluster node order, then
/// reorders cluster buckets by root mincross rank map with stable tie-breaks.
/// Do not change behavior without updating fixtures/tests.
pub fn reorder_groups_by_cluster(
  final_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let ordered_by_cluster : Map[Int, Array[String]] = Map::new()
  for rank, names in final_groups {
    ordered_by_cluster[rank] =
      reorder_rank_group_by_cluster_order(
        names,
        cluster_rank_order.get(rank),
        cluster_keys,
      )
  }
  ordered_by_cluster
}
