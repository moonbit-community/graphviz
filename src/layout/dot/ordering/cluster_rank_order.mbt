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
/// Graphviz parity: local cluster ordering uses minrank + first node order
/// before deterministic cluster-name tie-breaks (cluster.c).
/// Do not change behavior without updating fixtures/tests.
pub fn build_local_cluster_order(
  nodes : Array[@cgraph.Node],
  local_cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> Map[String, Int] {
  let min_rank : Map[String, Int] = Map::new()
  let first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = local_cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let rank = ranks.get(name).unwrap_or_default()
    match min_rank.get(cluster) {
      Some(current) => if rank < current { min_rank[cluster] = rank }
      None => min_rank[cluster] = rank
    }
    if first_order.get(cluster) is None {
      first_order[cluster] = node_order.get(name).unwrap_or_default()
    }
  }
  let entries : Array[(String, Int, Int)] = []
  for cluster, rank in min_rank {
    entries.push((cluster, rank, first_order.get(cluster).unwrap_or_default()))
  }
  entries.sort_by((a, b) => {
    let (name_a, rank_a, order_a) = a
    let (name_b, rank_b, order_b) = b
    if rank_a < rank_b {
      -1
    } else if rank_a > rank_b {
      1
    } else if order_a < order_b {
      -1
    } else if order_a > order_b {
      1
    } else if name_a < name_b {
      -1
    } else if name_a > name_b {
      1
    } else {
      0
    }
  })
  let order_map : Map[String, Int] = Map::new()
  let mut idx = 0
  for entry in entries {
    let (cluster, _rank, _order) = entry
    if order_map.get(cluster) is None {
      order_map[cluster] = idx
      idx = idx + 1
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
      let outer = cluster_key_or_empty(outer_cluster_keys, name)
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
        let local_key = cluster_key_or_empty(local_cluster_keys, name)
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
fn reorder_groups_by_cluster(
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
      if cluster_key_or_empty(cluster_keys, name) != "" {
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
  let should_skip_cluster_rank_reorder =
    should_skip_cluster_rank_bucket_reorder(
      cluster_rank_order,
      cleaned_groups,
      cluster_keys,
    )
  let final_groups =
    if should_skip_cluster_rank_reorder {
      cleaned_groups
    } else {
      reorder_groups_by_cluster(
        cleaned_groups,
        cluster_rank_order,
        cluster_keys,
      )
    }
  reorder_groups_by_local_cluster(
    final_groups,
    cluster_keys,
    local_cluster_keys,
    local_cluster_order,
  )
  final_groups
}
