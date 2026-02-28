///|
/// Stage B Phase B3 split: cluster metadata preprocessing
/// and rank-same helper flow for clustered ordering inputs.

///|
/// Graphviz parity: optional cluster order base expansion follows the
/// DOT_CLUSTER_ORDER_BASE debug path used for deterministic cluster spacing.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_order_base_for_metadata(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_first_order : Map[String, Int],
  node_order : Map[String, Int],
) -> Unit {
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = match cluster_first_order.get(cluster) {
      Some(value) => value
      None => 0
    }
    cluster_order_list.push((cluster, rank, order))
  }
  let cluster_order_base : Map[String, Int] = Map::new()
  if cluster_order_list.length() > 1 &&
    @sys.get_env_var("DOT_CLUSTER_ORDER_BASE") is Some(_) {
    cluster_order_list.sort_by((a, b) => {
      let (_name_a, rank_a, order_a) = a
      let (_name_b, rank_b, order_b) = b
      if rank_a < rank_b {
        -1
      } else if rank_a > rank_b {
        1
      } else if order_a < order_b {
        -1
      } else if order_a > order_b {
        1
      } else {
        0
      }
    })
    let step = nodes.length() + 1
    let mut base = 0
    for entry in cluster_order_list {
      let (cluster, _rank, _order) = entry
      cluster_order_base[cluster] = base
      base = base + step
    }
    for node in nodes {
      let name = node.name()
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let base_order = match cluster_order_base.get(cluster) {
        Some(value) => value
        None => 0
      }
      let inner = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      node_order[name] = base_order + inner
    }
  }
}

///|
/// Graphviz parity: cluster metadata/order aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/compound.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_metadata(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  edge_tail : Array[String],
  edge_head : Array[String],
  graphviz_flip : Bool,
) -> ClusterMetadata {
  let has_clusters = @dot_shared.graph_has_cluster(graph)
  // Graphviz parity: cluster key map comes from per-node cluster ownership
  // used throughout clustered ordering and compound-edge setup.
  let cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    cluster_keys[node.name()] = node_cluster_key(node)
  }
  // Graphviz parity: cluster subgraph node order follows GD_nlist traversal
  // direction and rankdir flip behavior from dotgen cluster ordering.
  let creation_order : Map[String, Int] = Map::new()
  for i, node in nodes {
    creation_order[node.name()] = i
  }
  let total_nodes = nodes.length()
  for node in nodes {
    let name = node.name()
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    let base_order = match creation_order.get(name) {
      Some(value) => value
      None => 0
    }
    let order_value =
      if graphviz_flip {
        total_nodes - 1 - base_order
      } else {
        base_order
      }
    node_order[name] = order_value
  }
  // Graphviz parity: each cluster contributes one skeleton node per rank
  // (first node encountered in rank order).
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rank_seen : Map[String, Bool] = Map::new()
  for rank, names in groups {
    for name in names {
      let cluster = match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
      if cluster == "" {
        continue
      }
      let key = "\{cluster}@\{rank}"
      if cluster_rank_seen.get(key) is None {
        cluster_rank_seen[key] = true
        cluster_skeleton[name] = true
      }
    }
  }
  // Graphviz parity: cluster rank bounds are collected from member node rank
  // and first appearance order before cluster-order base expansion.
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
  // Graphviz parity: cluster min/max rank and first order are collected
  // from cluster member nodes before clustered reorder setup.
  for node in nodes {
    let name = node.name()
    let cluster = cluster_key_or_empty(cluster_keys, name)
    if cluster == "" {
      continue
    }
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    match cluster_max_rank.get(cluster) {
      Some(current) => if rank > current { cluster_max_rank[cluster] = rank }
      None => cluster_max_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      let order_value = match node_order.get(name) {
        Some(value) => value
        None => 0
      }
      cluster_first_order[cluster] = order_value
    }
  }
  // Graphviz parity: cluster order and parent map are collected from
  // Graphviz cluster traversal before clustered ordering stages.
  let cluster_order : Array[String] = []
  collect_cluster_names_order(graph, cluster_order)
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  @dot_shared.collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  apply_cluster_order_base_for_metadata(
    nodes,
    cluster_keys,
    cluster_min_rank,
    cluster_first_order,
    node_order,
  )
  // Graphviz parity: intercluster keys mirror local cluster membership
  // used by Graphviz compound edge ordering.
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    intercluster_keys[node.name()] = node_local_cluster_key(node)
  }
  // Graphviz parity: rank=same groups/order are collected once for clustered
  // ordering constraints, matching Graphviz same-rank preprocessing.
  let rank_same_groups : Map[String, Int] = Map::new()
  let rank_same_order : Map[String, Int] = Map::new()
  let _ = collect_rank_same_order(graph, rank_same_groups, rank_same_order, 0)
  // Graphviz parity: flat ordering constraints include Graphviz ordering attrs
  // plus same-rank edge constraints before clustered reorder dispatch.
  let (flat_constraints, ordering_set) = build_ordering_flat_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    cluster_keys,
  )
  // Graphviz parity: same-rank edges are promoted to flat ordering
  // constraints for clustered metadata reorder paths.
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    if edge_idx < edges.length() && !@dot_shared.edge_is_constraint(edges[edge_idx]) {
      edge_idx = edge_idx + 1
      continue
    }
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if tail != head {
      let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
      let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
      if tail_rank == head_rank {
        flat_constraints["\{tail}|\{head}"] = true
      }
    }
    edge_idx = edge_idx + 1
  }
  {
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    cluster_parents,
    intercluster_keys,
    rank_same_groups,
    rank_same_order,
    flat_constraints,
    ordering_set,
  }
}

///|
/// Graphviz parity: rank=same does not impose ordering constraints.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_same_constraints(
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let _ = rank_same_groups
  let _ = rank_same_order
  let _ = node_order
  let _ = port_edge_nodes
  let _ = ranks
  Map::new()
}
