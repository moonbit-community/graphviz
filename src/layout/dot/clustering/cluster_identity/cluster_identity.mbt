///|
/// Cluster skeleton and boundary-node naming helpers shared by clustering,
/// ordering, and positioning stages.

///|
pub const CLUSTER_SKELETON_PREFIX : String = "_mbt_cluster_skel_"

///|
pub const CLUSTER_LN_PREFIX : String = "_mbt_cluster_ln_"

///|
pub const CLUSTER_RN_PREFIX : String = "_mbt_cluster_rn_"

///|
/// Graphviz parity: cluster skeleton node names encode the cluster key.
pub fn is_cluster_skeleton_name(name : String) -> Bool {
  name.has_prefix(CLUSTER_SKELETON_PREFIX)
}

///|
/// Graphviz parity: cluster skeleton node names encode "<cluster>@<rank>".
pub fn cluster_skeleton_name(cluster : String, rank : Int) -> String {
  "\{CLUSTER_SKELETON_PREFIX}\{cluster}@\{rank}"
}

///|
/// Graphviz parity: cluster boundary slack nodes use dedicated ln/rn prefixes.
pub fn cluster_left_boundary_name(cluster : String) -> String {
  "\{CLUSTER_LN_PREFIX}\{cluster}"
}

///|
/// Graphviz parity: cluster boundary slack nodes use dedicated ln/rn prefixes.
pub fn cluster_right_boundary_name(cluster : String) -> String {
  "\{CLUSTER_RN_PREFIX}\{cluster}"
}

///|
/// Graphviz parity: boundary node identifiers must stay unique if cluster
/// names collide with existing graph nodes.
pub fn unique_cluster_boundary_name(
  base_name : String,
  existing : Map[String, Bool],
) -> String {
  let mut candidate = base_name
  if existing.get(candidate) is None {
    existing[candidate] = true
    return candidate
  }
  let mut i = 1
  while true {
    candidate = "\{base_name}_\{i}"
    if existing.get(candidate) is None {
      existing[candidate] = true
      return candidate
    }
    i = i + 1
  }
  ""
}

///|
/// Graphviz parity: cluster boundary slack nodes are identified by ln/rn
/// prefixes in xpos constraint graphs.
pub fn is_cluster_boundary_name(name : String) -> Bool {
  name.has_prefix(CLUSTER_LN_PREFIX) ||
  name.has_prefix(CLUSTER_RN_PREFIX)
}

///|
/// Graphviz parity: left boundary nodes use the ln prefix.
pub fn is_cluster_left_boundary_name(name : String) -> Bool {
  name.has_prefix(CLUSTER_LN_PREFIX)
}

///|
/// Graphviz parity: boundary node names map back to cluster keys via longest
/// matching cluster-prefix fallback to preserve suffix-disambiguated names.
pub fn cluster_key_from_boundary(
  name : String,
  cluster_names : Map[String, Bool],
) -> String? {
  let mut rest : String? = None
  if name.has_prefix(CLUSTER_LN_PREFIX) {
    rest = Some(
      name.unsafe_substring(
        start=CLUSTER_LN_PREFIX.length(),
        end=name.length(),
      ),
    )
  } else if name.has_prefix(CLUSTER_RN_PREFIX) {
    rest = Some(
      name.unsafe_substring(
        start=CLUSTER_RN_PREFIX.length(),
        end=name.length(),
      ),
    )
  }
  let rest = match rest {
    Some(value) => value
    None => return None
  }
  match cluster_names.get(rest) {
    Some(_) => return Some(rest)
    None => ()
  }
  let mut best : String? = None
  let mut best_len = -1
  for cluster, _ in cluster_names {
    if !rest.has_prefix(cluster) {
      continue
    }
    let suffix = rest.unsafe_substring(
      start=cluster.length(),
      end=rest.length(),
    )
    if suffix == "" {
      if cluster.length() > best_len {
        best = Some(cluster)
        best_len = cluster.length()
      }
      continue
    }
    if !suffix.has_prefix("_") {
      continue
    }
    let digits = suffix.unsafe_substring(start=1, end=suffix.length())
    if digits == "" {
      continue
    }
    let mut all_digits = true
    for ch in digits {
      if ch < '0' || ch > '9' {
        all_digits = false
        break
      }
    }
    if all_digits && cluster.length() > best_len {
      best = Some(cluster)
      best_len = cluster.length()
    }
  }
  best
}

///|
/// Graphviz parity: cluster skeleton node names encode the cluster key.
pub fn cluster_key_from_skeleton(name : String) -> String? {
  if !is_cluster_skeleton_name(name) {
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
