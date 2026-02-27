///|
/// Extracted from layout_pipeline_stage_c_phase_c5_remincross_materialize_helpers.mbt
/// to keep Stage C ReMincross cluster-key/intercluster-span helpers isolated.

///|
/// Graphviz parity: ReMincross base cluster keys copy intercluster keys and
/// map empty keys to a non-empty root ND_clust key (mark_lowclusters).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys_base(
  graph : @cgraph.Graph,
  intercluster_keys : Map[String, String],
) -> (Map[String, String], String) {
  let rem_cluster_keys : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    rem_cluster_keys[name] = key
  }
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  let root_cluster = match graph.name() {
    Some(value) => value
    None => "__root__"
  }
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = root_cluster
    }
  }
  (rem_cluster_keys, root_cluster)
}

///|
/// Graphviz parity: ReMincross virtual nodes take the LCA endpoint cluster
/// (or root fallback) from intercluster edge endpoints.
/// Do not change behavior without updating fixtures/tests.
fn assign_remincross_vnode_clusters_from_edges(
  rem_cluster_keys : Map[String, String],
  root_cluster : String,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Unit {
  let mut edge_idx = 0
  for edge in edges {
    let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      edge_idx = edge_idx + 1
      continue
    }
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
    let head_cluster = cluster_key_or_empty(intercluster_keys, head)
    // Graphviz parity: mark_lowclusters assigns virtual nodes to the
    // lowest common ancestor cluster for intercluster edges.
    let vnode_cluster =
      cluster_lowest_common_ancestor(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: ReMincross cluster keys start from intercluster keys,
/// map empty keys to the root graph key, and assign edge vnodes to the LCA
/// cluster (mark_lowclusters) for cluster-boundary swap guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, String] {
  let (rem_cluster_keys, root_cluster) =
    build_remincross_cluster_keys_base(graph, intercluster_keys)
  if !order_with_vnodes {
    return rem_cluster_keys
  }
  assign_remincross_vnode_clusters_from_edges(
    rem_cluster_keys,
    root_cluster,
    edges,
    edge_tail,
    edge_head,
    intercluster_keys,
    cluster_parents,
    edge_vnodes,
  )
  rem_cluster_keys
}

///|
/// Graphviz parity: intercluster short-span guard selects only edges crossing
/// cluster keys with absolute rank difference <= 1.
/// Do not change behavior without updating fixtures/tests.
fn edge_has_intercluster_short_span(
  tail : String,
  head : String,
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Bool {
  let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
  let head_cluster = cluster_key_or_empty(intercluster_keys, head)
  if tail_cluster == head_cluster {
    return false
  }
  let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
  let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
  let span = if tail_rank <= head_rank {
    head_rank - tail_rank
  } else {
    tail_rank - head_rank
  }
  span <= 1
}

///|
/// Graphviz parity: intercluster node guard marks real endpoints of
/// intercluster edges with rank span <= 1 for local-order relaxation.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_nodes_with_short_span(
  order_with_clusters : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_nodes : Map[String, Bool] = Map::new()
  if !order_with_clusters {
    return intercluster_nodes
  }
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if edge_has_intercluster_short_span(
      tail,
      head,
      intercluster_keys,
      ranks,
    ) {
      intercluster_nodes[tail] = true
      intercluster_nodes[head] = true
    }
    edge_idx = edge_idx + 1
  }
  intercluster_nodes
}
