///|
/// Ordering domain: root-rank override replay helpers used by clustered
/// Stage C root passes when replaying root-mincross override groups.

///|
/// Graphviz parity: rank-level override reorders only names present in the
/// current rank while preserving the relative order of unmatched names.
/// Do not change behavior without updating fixtures/tests.
pub fn reorder_names_by_override(
  names : Array[String],
  override_names : Array[String],
) -> Array[String] {
  let present : Map[String, Bool] = Map::new()
  for name in names {
    present[name] = true
  }
  let reordered : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in override_names {
    if present.get(name) is Some(_) && seen.get(name) is None {
      reordered.push(name)
      seen[name] = true
    }
  }
  for name in names {
    if seen.get(name) is None {
      reordered.push(name)
      seen[name] = true
    }
  }
  reordered
}

///|
/// Graphviz parity: cluster skeleton node names encode the cluster key.
fn cluster_key_from_skeleton_name(name : String) -> String? {
  if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
    return None
  }
  let rest = name.unsafe_substring(
    start=CLUSTER_SKELETON_PREFIX.length(),
    end=name.length(),
  )
  for part in rest.split("@") {
    let value = part.to_string()
    if value != "" {
      return Some(value)
    }
  }
  None
}

///|
/// Graphviz parity: root-override graphviz_flip replay keeps skeleton names in
/// rank order, reattaches same-cluster names after skeletons, and preserves any
/// unmatched names as final fallback in original rank order.
fn rebuild_root_override_names(
  rank_names : Array[String],
  cluster_keys : Map[String, String],
) -> Array[String] {
  // Graphviz parity: root-override skeleton checks treat non-skeleton names as
  // empty cluster keys when rebuilding attached-cluster bundles.
  let skeleton_cluster_or_empty = (name : String) =>
    cluster_key_from_skeleton_name(name).unwrap_or_default()
  // Graphviz parity: any parsed skeleton cluster key is a skeleton marker.
  let is_root_override_skeleton_name = (name : String) =>
    skeleton_cluster_or_empty(name) != ""
  let skeleton_for_cluster =
    build_skeleton_for_clusters(
      rank_names,
      skeleton_cluster_or_empty,
    )
  let attached_by_skeleton =
    build_attached_by_skeleton(
      rank_names,
      cluster_keys,
      skeleton_for_cluster,
      is_root_override_skeleton_name,
    )
  let next_names : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for name in rank_names {
    if seen.get(name) is Some(_) {
      continue
    }
    let is_skeleton = is_root_override_skeleton_name(name)
    if is_skeleton {
      next_names.push(name)
      seen[name] = true
      append_attached_by_skeleton(
        next_names,
        seen,
        attached_by_skeleton,
        name,
      )
      continue
    }
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster != "" && skeleton_for_cluster.get(cluster) is Some(_) {
      continue
    }
    next_names.push(name)
    seen[name] = true
  }
  for name in rank_names {
    if seen.get(name) is None {
      next_names.push(name)
      seen[name] = true
    }
  }
  next_names
}

///|
/// Graphviz parity: rank-level root override first applies explicit override
/// order, then replays cluster-attached skeleton ordering only in flip mode.
/// Do not change behavior without updating fixtures/tests.
fn build_root_override_rank_names(
  names : Array[String],
  override_names : Array[String],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Array[String] {
  let rank_names =
    reorder_names_by_override(
      names,
      override_names,
    )
  if !graphviz_flip {
    return rank_names
  }
  rebuild_root_override_names(rank_names, cluster_keys)
}

///|
/// Graphviz parity: root phase can apply a rank-order override from root
/// mincross output before local cluster passes.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_root_groups_override(
  groups : Map[Int, Array[String]],
  override_groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  let reordered = clone_rank_groups(groups)
  for rank, override_names in override_groups {
    match reordered.get(rank) {
      Some(names) =>
        reordered[rank] =
          build_root_override_rank_names(
            names,
            override_names,
            cluster_keys,
            graphviz_flip,
          )
      None => ()
    }
  }
  reordered
}
