///|
/// Ordering domain: clustered ReMincross cluster-key materialization helpers
/// used by Stage C cleanup reorder setup.

///|
/// Graphviz parity: assign intercluster virtual nodes to lowest common
/// ancestor cluster (mark_lowclusters + class2).
fn cluster_lca(
  left : String,
  right : String,
  cluster_parents : Map[String, String?],
) -> String {
  if left == "" || right == "" {
    return ""
  }
  if left == right {
    return left
  }
  let seen : Map[String, Bool] = Map::new()
  let walk_seen : Map[String, Bool] = Map::new()
  let mut current = left
  while current != "" {
    if walk_seen.get(current) is Some(_) {
      break
    }
    walk_seen[current] = true
    seen[current] = true
    let parent = match cluster_parents.get(current) {
      Some(value) => value
      None => (None : String?)
    }
    match parent {
      Some(value) => current = value
      None => current = ""
    }
  }
  let mut probe = right
  let probe_seen : Map[String, Bool] = Map::new()
  while probe != "" {
    if probe_seen.get(probe) is Some(_) {
      break
    }
    probe_seen[probe] = true
    if seen.get(probe) is Some(_) {
      return probe
    }
    let parent = match cluster_parents.get(probe) {
      Some(value) => value
      None => (None : String?)
    }
    match parent {
      Some(value) => probe = value
      None => probe = ""
    }
  }
  ""
}

///|
/// Graphviz parity: clustered ReMincross starts from a shallow clone of
/// intercluster keys before root remapping and vnode LCA assignments.
fn clone_remincross_cluster_keys(
  intercluster_keys : Map[String, String],
) -> Map[String, String] {
  let cloned : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    cloned[name] = key
  }
  cloned
}

///|
/// Graphviz parity: mark_lowclusters assigns ReMincross edge-vnodes to the
/// lowest common ancestor cluster (or root cluster when LCA is empty).
fn assign_remincross_clusters(
  rem_cluster_keys : Map[String, String],
  root_cluster : String,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_vnodes : Map[String, Array[String]],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
) -> Unit {
  for edge_idx, edge in edges {
    let vnodes =
      edge_vnodes.get(@shared.edge_vnode_key(edge)).unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let (tail, head) =
      edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    let tail_cluster = intercluster_keys.get(tail).unwrap_or_default()
    let head_cluster = intercluster_keys.get(head).unwrap_or_default()
    let vnode_cluster =
      cluster_lca(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
  }
}

///|
/// Graphviz parity: clustered ReMincross cluster-key materialization inputs
/// capture intercluster keys and vnode-edge context before cleanup reorder.
pub(all) struct ReMincrossClusterKeyInputs {
  root_cluster : String
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_vnodes : Map[String, Array[String]]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: ReMincross cluster-key map starts from intercluster keys,
/// rewrites empty keys to root graph key, then applies vnode LCA assignments.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_cluster_keys(
  inputs : ReMincrossClusterKeyInputs,
) -> Map[String, String] {
  let rem_cluster_keys =
    clone_remincross_cluster_keys(inputs.intercluster_keys)
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = inputs.root_cluster
    }
  }
  if inputs.order_with_vnodes {
    assign_remincross_clusters(
      rem_cluster_keys,
      inputs.root_cluster,
      inputs.edges,
      inputs.edge_tail,
      inputs.edge_head,
      inputs.edge_vnodes,
      inputs.intercluster_keys,
      inputs.cluster_parents,
    )
  }
  rem_cluster_keys
}

///|
/// Graphviz parity: clustered ReMincross flat-constraint inputs combine
/// cluster-local and rank=same constraint snapshots before cleanup reorder.
pub(all) struct ReMincrossFlatConstraintInputs {
  order_with_clusters : Bool
  cluster_flat_constraints : Map[String, Bool]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: ReMincross flat constraints combine cluster flat locks and
/// rank=same constraints only for non-cluster reorder path.
/// Do not change behavior without updating fixtures/tests.
pub fn build_remincross_flat_constraints(
  inputs : ReMincrossFlatConstraintInputs,
) -> Map[String, Bool] {
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  // Graphviz parity: ReMincross flat constraints combine existing same-rank
  // constraints with local intra-cluster adjacency locks for non-intercluster
  // real-node pairs (flat.c cluster-local reorder guard).
  if !inputs.order_with_clusters {
    for key, value in inputs.cluster_flat_constraints {
      rem_flat_constraints[key] = value
    }
    for key, _ in inputs.rank_same_constraints {
      rem_flat_constraints[key] = true
    }
  }
  rem_flat_constraints
}
