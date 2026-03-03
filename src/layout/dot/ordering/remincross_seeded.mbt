///|
/// Ordering domain: clustered ReMincross seeded-group replay helpers used by
/// Stage C cleanup dispatch when vnode-inclusive ordering can be reused.

///|
/// Graphviz parity: seeded vnode-inclusive rank rebuilding anchors synthetic
/// names between nearest real-node predecessors/successors from base order.
priv struct NeighborRealIndices {
  prev_real : Array[Int?]
  next_real_by_pos : Array[Int?]
}

///|
/// Graphviz parity: seeded vnode-inclusive rank rebuilding anchors synthetic
/// names between nearest real-node predecessors/successors from base order.
fn build_neighbor_real_indices(
  filtered : Array[String],
  real_order : Map[String, Int],
) -> NeighborRealIndices {
  let prev_real : Array[Int?] = []
  let mut last_real : Int? = None
  for name in filtered {
    match real_order.get(name) {
      Some(idx) => last_real = Some(idx)
      None => ()
    }
    prev_real.push(last_real)
  }
  let next_rev : Array[Int?] = []
  let mut next_real : Int? = None
  let mut rev_idx = filtered.length()
  while rev_idx > 0 {
    rev_idx = rev_idx - 1
    let name = filtered[rev_idx]
    match real_order.get(name) {
      Some(idx) => next_real = Some(idx)
      None => ()
    }
    next_rev.push(next_real)
  }
  let next_real_by_pos : Array[Int?] = []
  let mut idx = next_rev.length()
  while idx > 0 {
    idx = idx - 1
    next_real_by_pos.push(next_rev[idx])
  }
  { prev_real, next_real_by_pos }
}

///|
/// Graphviz parity: when a mixed root/cluster rank begins with one synthetic
/// vnode, keep root real first, cluster reals next, and trail that vnode.
fn try_build_special_seed_order(
  filtered : Array[String],
  base_real : Array[String],
  real_order : Map[String, Int],
  cluster_keys : Map[String, String],
) -> Array[String]? {
  let mut root_real_count = 0
  let mut cluster_real_count = 0
  let mut root_real_name = ""
  let cluster_real_names : Array[String] = []
  for name in base_real {
    if cluster_key_or_empty(cluster_keys, name) == "" {
      root_real_count = root_real_count + 1
      root_real_name = name
    } else {
      cluster_real_count = cluster_real_count + 1
      cluster_real_names.push(name)
    }
  }
  let mut synthetic_count = 0
  let mut synthetic_name = ""
  for name in filtered {
    if real_order.get(name) is None {
      synthetic_count = synthetic_count + 1
      synthetic_name = name
    }
  }
  if filtered.length() == 4 &&
    is_edge_vnode_name(filtered[0]) &&
    root_real_count == 1 &&
    cluster_real_count >= 2 &&
    synthetic_count == 1 &&
    synthetic_name != "" &&
    root_real_name != "" {
    let special_order : Array[String] = [root_real_name]
    for name in cluster_real_names {
      special_order.push(name)
    }
    special_order.push(synthetic_name)
    return Some(special_order)
  }
  None
}

///|
/// Graphviz parity: seeded rank merge key places real nodes on even slots,
/// synthetic nodes after nearest previous/next real anchors.
fn seeded_rank_merge_key(
  index : Int,
  name : String,
  real_order : Map[String, Int],
  prev_real : Array[Int?],
  next_real_by_pos : Array[Int?],
) -> Int {
  match real_order.get(name) {
    Some(real_idx) => real_idx * 2
    None =>
      match prev_real[index] {
        Some(prev_idx) => prev_idx * 2 + 1
        None =>
          match next_real_by_pos[index] {
            Some(next_idx) => next_idx * 2 - 1
            None => index * 2
          }
      }
  }
}

///|
/// Graphviz parity: seeded rank rebuild first applies special mixed handoff
/// ordering, then falls back to key-based synthetic/real merge replay.
fn build_seeded_rank_order(
  filtered : Array[String],
  base_real : Array[String],
  cluster_keys : Map[String, String],
) -> Array[String] {
  let real_order : Map[String, Int] = Map::new()
  for i in 0..<base_real.length() {
    real_order[base_real[i]] = i
  }
  // Graphviz parity: special mixed rank handoff keeps root/cluster/vnode
  // sequence aligned with Graphviz before generic key-based placement.
  match try_build_special_seed_order(
    filtered,
    base_real,
    real_order,
    cluster_keys,
  ) {
    Some(special_order) => special_order
    None => {
      let neighbor_indices =
        build_neighbor_real_indices(filtered, real_order)
      let keyed : Array[(String, Int, Int)] = []
      for i in 0..<filtered.length() {
        let name = filtered[i]
        let key =
          seeded_rank_merge_key(
            i,
            name,
            real_order,
            neighbor_indices.prev_real,
            neighbor_indices.next_real_by_pos,
          )
        keyed.push((name, key, i))
      }
      // Graphviz parity: seeded rank replay uses keyed sort output order
      // directly as the vnode-inclusive rank sequence.
      keyed.sort_by((a, b) => {
        // Graphviz parity: keyed sort keeps merge-key primary order and
        // original index tie-break so equal keys preserve input order.
        let (_, key_a, idx_a) = a
        let (_, key_b, idx_b) = b
        if key_a < key_b {
          -1
        } else if key_a > key_b {
          1
        } else if idx_a < idx_b {
          -1
        } else if idx_a > idx_b {
          1
        } else {
          0
        }
      })
      let ordered_rank : Array[String] = []
      for entry in keyed {
        let (name, _, _) = entry
        ordered_rank.push(name)
      }
      ordered_rank
    }
  }
}

///|
/// Graphviz parity: ReMincross can seed from current vnode-inclusive rank
/// order while keeping real-node relative order from cleaned base groups.
/// Do not change behavior without updating fixtures/tests.
pub fn build_seeded_remincross(
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in ordered_with_vnodes {
    // Graphviz parity: seeded rank replay drops cluster skeleton placeholders
    // and keeps remaining name order unchanged.
    let filtered : Array[String] = []
    for name in names {
      if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
        filtered.push(name)
      }
    }
    if filtered.length() == 0 {
      continue
    }
    let base_real = base_groups.get(rank).unwrap_or_default()
    if base_real.length() == 0 {
      rem_groups[rank] = filtered
      continue
    }
    let ordered_rank =
      build_seeded_rank_order(
        filtered,
        base_real,
        cluster_keys,
      )
    rem_groups[rank] = ordered_rank
  }
  rem_groups
}
