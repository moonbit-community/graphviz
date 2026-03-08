pub const CLUSTER_MARGIN_PT : Double = 8.0

///|
pub fn cluster_margin_pt(graph : @cgraph.Graph) -> Double {
  match graph.get_attr("margin") {
    Some(value) => {
      let margin = @numeric.parse_first_double(value, CLUSTER_MARGIN_PT)
      if margin < 0.0 {
        CLUSTER_MARGIN_PT
      } else {
        margin
      }
    }
    None => CLUSTER_MARGIN_PT
  }
}

pub(all) struct ClusterMembershipMaps {
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
}

///|
/// Graphviz parity: cluster membership maps mirror per-node outer/local
/// cluster ownership used across clustered ordering and compound-edge paths.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_membership_maps(
  nodes : Array[@cgraph.Node],
) -> ClusterMembershipMaps {
  let cluster_keys : Map[String, String] = Map::new()
  let intercluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    let name = node.name()
    cluster_keys[name] = node_cluster_key(node)
    intercluster_keys[name] = node_local_cluster_key(node)
  }
  { cluster_keys, intercluster_keys }
}

///|
pub(all) struct ClusterNodeRankBounds {
  min_rank : Map[String, Int]
  max_rank : Map[String, Int]
  first_order : Map[String, Int]
}

///|
/// Graphviz parity: cluster min/max rank and first order are collected from
/// member node rank snapshots before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn collect_cluster_rank_bounds(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
) -> ClusterNodeRankBounds {
  let cluster_min_rank : Map[String, Int] = Map::new()
  let cluster_max_rank : Map[String, Int] = Map::new()
  let cluster_first_order : Map[String, Int] = Map::new()
  for node in nodes {
    let name = node.name()
    let cluster = cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let rank = ranks.get(name).unwrap_or_default()
    match cluster_min_rank.get(cluster) {
      Some(current) => if rank < current { cluster_min_rank[cluster] = rank }
      None => cluster_min_rank[cluster] = rank
    }
    match cluster_max_rank.get(cluster) {
      Some(current) => if rank > current { cluster_max_rank[cluster] = rank }
      None => cluster_max_rank[cluster] = rank
    }
    if cluster_first_order.get(cluster) is None {
      cluster_first_order[cluster] = node_order.get(name).unwrap_or_default()
    }
  }
  {
    min_rank: cluster_min_rank,
    max_rank: cluster_max_rank,
    first_order: cluster_first_order,
  }
}

///|
/// Graphviz parity: initial cluster node order seeds follow GD_nlist traversal
/// with optional graphviz_flip reversal before clustered reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn seed_cluster_node_order(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  graphviz_flip : Bool,
  node_order : Map[String, Int],
) -> Unit {
  let total_nodes = nodes.length()
  for i, node in nodes {
    let name = node.name()
    let cluster = cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let base_order = i
    let order_value =
      if graphviz_flip {
        total_nodes - 1 - base_order
      } else {
        base_order
      }
    node_order[name] = order_value
  }
}

///|
/// Graphviz parity: each cluster contributes one skeleton node per rank
/// (first node encountered in rank order).
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_skeleton(
  groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[String, Bool] {
  let cluster_skeleton : Map[String, Bool] = Map::new()
  let cluster_rank_seen : Map[String, Bool] = Map::new()
  for rank, names in groups {
    for name in names {
      let cluster = cluster_keys.get(name).unwrap_or_default()
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
  cluster_skeleton
}

///|
/// Graphviz parity: optional cluster order base expansion follows the
/// DOT_CLUSTER_ORDER_BASE debug path used for deterministic cluster spacing.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_order_base(
  nodes : Array[@cgraph.Node],
  cluster_keys : Map[String, String],
  cluster_min_rank : Map[String, Int],
  cluster_first_order : Map[String, Int],
  node_order : Map[String, Int],
  cluster_order_base_enabled : Bool,
) -> Unit {
  let cluster_order_list : Array[(String, Int, Int)] = []
  for cluster, rank in cluster_min_rank {
    let order = cluster_first_order.get(cluster).unwrap_or_default()
    cluster_order_list.push((cluster, rank, order))
  }
  if cluster_order_list.length() <= 1 || !cluster_order_base_enabled {
    return
  }
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
  let cluster_order_base : Map[String, Int] = Map::new()
  let mut base = 0
  for entry in cluster_order_list {
    let (cluster, _rank, _order) = entry
    cluster_order_base[cluster] = base
    base = base + step
  }
  for node in nodes {
    let name = node.name()
    let cluster = cluster_keys.get(name).unwrap_or_default()
    if cluster == "" {
      continue
    }
    let base_order = cluster_order_base.get(cluster).unwrap_or_default()
    let inner = node_order.get(name).unwrap_or_default()
    node_order[name] = base_order + inner
  }
}

///|
/// Graphviz parity: cluster core metadata payload keeps cluster ownership,
/// rank bounds, traversal order, and parent mapping grouped for ordering setup.
pub(all) struct ClusterCoreOrderingMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
}

///|
/// Graphviz parity: cluster core metadata and node-order seeding/base expansion
/// are collected before clustered ordering dispatch with Graphviz order intact.
/// Do not change behavior without updating fixtures/tests.
pub fn build_cluster_core_metadata_for_ordering(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  groups : Map[Int, Array[String]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  graphviz_flip : Bool,
  cluster_order_base_enabled : Bool,
) -> ClusterCoreOrderingMetadata {
  let has_clusters = @cluster_graph.graph_has_cluster(graph)
  let cluster_membership = build_cluster_membership_maps(nodes)
  let cluster_keys = cluster_membership.cluster_keys
  let intercluster_keys = cluster_membership.intercluster_keys
  seed_cluster_node_order(nodes, cluster_keys, graphviz_flip, node_order)
  let cluster_skeleton = build_cluster_skeleton(groups, cluster_keys)
  let cluster_rank_bounds =
    collect_cluster_rank_bounds(nodes, cluster_keys, ranks, node_order)
  let cluster_min_rank = cluster_rank_bounds.min_rank
  let cluster_max_rank = cluster_rank_bounds.max_rank
  let cluster_first_order = cluster_rank_bounds.first_order
  let cluster_traversal_metadata = collect_cluster_traversal_metadata(graph)
  let cluster_order = cluster_traversal_metadata.cluster_order
  let cluster_parents = cluster_traversal_metadata.cluster_parents
  apply_cluster_order_base(
    nodes,
    cluster_keys,
    cluster_min_rank,
    cluster_first_order,
    node_order,
    cluster_order_base_enabled,
  )
  {
    has_clusters,
    cluster_keys,
    cluster_skeleton,
    cluster_min_rank,
    cluster_max_rank,
    cluster_order,
    cluster_parents,
    intercluster_keys,
  }
}

///|
