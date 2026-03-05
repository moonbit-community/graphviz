///|
/// Stage C Phase C3 split: cluster-local reorder context builders.

///|
/// Graphviz parity: cluster-local reorder context keeps filtered cluster nodes,
/// seeded local rank groups, and fixed-slot exclusions in one bundle.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderContext {
  cluster_node_set : Map[String, Bool]
  cluster_nodes : Array[String]
  cluster_node_order : Map[String, Int]
  cluster_groups : Map[Int, Array[String]]
  cluster_rank_keys : Array[Int]
  cluster_fixed_positions : Map[String, Double]
}

///|
/// Graphviz parity: cluster-local reorder node-order context keeps filtered
/// cluster members and deterministic local node indices built from node_order.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterNodeOrderContext {
  cluster_nodes : Array[String]
  cluster_node_order : Map[String, Int]
}

///|
/// Graphviz parity: cluster-local reorder node set keeps cluster members that
/// are present in rank groups, plus local vnodes when enabled.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_node_set_for_reorder(
  cluster : String,
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  vnode_clusters : Map[String, String],
  order_with_vnodes : Bool,
) -> Map[String, Bool] {
  let cluster_nodes_set : Map[String, Bool] = Map::new()
  for node in cluster_graph.nodes() {
    cluster_nodes_set[node.name()] = true
  }
  if order_with_vnodes {
    for vnode, vnode_cluster in vnode_clusters {
      if vnode_cluster == cluster {
        cluster_nodes_set[vnode] = true
      }
    }
  }
  let cluster_node_set : Map[String, Bool] = Map::new()
  for _rank, names in groups {
    for name in names {
      if cluster_nodes_set.get(name) is Some(_) {
        cluster_node_set[name] = true
      }
    }
  }
  cluster_node_set
}

///|
/// Graphviz parity: cluster-local node-order context uses global node_order as
/// deterministic seed before assigning contiguous local order ids.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_node_order_context(
  cluster_node_set : Map[String, Bool],
  node_order : Map[String, Int],
) -> ClusterNodeOrderContext {
  let cluster_nodes : Array[String] = []
  for name, _ in cluster_node_set {
    cluster_nodes.push(name)
  }
  let cluster_node_order : Map[String, Int] = Map::new()
  let cluster_ordered_nodes = cluster_nodes.copy()
  if cluster_ordered_nodes.length() > 1 {
    cluster_ordered_nodes.sort_by((a, b) => {
      @ordering.compare_by_order_then_name(node_order, a, b)
    })
  }
  let mut order_idx = 0
  for name in cluster_ordered_nodes {
    cluster_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  { cluster_nodes, cluster_node_order }
}

///|
/// Graphviz parity: cluster-local reorder preserves fixed slots outside the
/// active cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_fixed_positions(
  fixed_positions : Map[String, Double],
  cluster_node_set : Map[String, Bool],
) -> Map[String, Double] {
  let cluster_fixed_positions : Map[String, Double] = Map::new()
  for name, value in fixed_positions {
    if cluster_node_set.get(name) is None {
      cluster_fixed_positions[name] = value
    }
  }
  cluster_fixed_positions
}

///|
/// Graphviz parity: cluster-local reorder only considers nodes that are
/// present in rank groups and belong to the current cluster (plus local
/// virtual nodes when enabled).
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderContextBuildInputs {
  cluster : String
  cluster_graph : @cgraph.Graph
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  source_out_neighbors : Map[String, Array[String]]
  vnode_clusters : Map[String, String]
  fixed_positions : Map[String, Double]
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: cluster-local reorder only considers nodes that are
/// present in rank groups and belong to the current cluster (plus local
/// virtual nodes when enabled).
fn build_cluster_local_reorder_context(
  inputs : ClusterLocalReorderContextBuildInputs,
) -> ClusterLocalReorderContext? {
  let cluster_node_set =
    build_cluster_node_set_for_reorder(
      inputs.cluster,
      inputs.cluster_graph,
      inputs.groups,
      inputs.vnode_clusters,
      inputs.order_with_vnodes,
    )
  if cluster_node_set.length() <= 1 {
    return None
  }
  let node_order_context =
    build_cluster_node_order_context(
      cluster_node_set,
      inputs.node_order,
    )
  let cluster_nodes = node_order_context.cluster_nodes
  let cluster_node_order = node_order_context.cluster_node_order
  let cluster_groups = @ordering.build_local_rank_groups(
    inputs.groups,
    cluster_node_set,
    cluster_node_order,
    inputs.source_out_neighbors,
  )
  let cluster_rank_keys = @ordering.collect_rank_keys(cluster_groups)
  let cluster_fixed_positions =
    build_cluster_fixed_positions(inputs.fixed_positions, cluster_node_set)
  Some({
    cluster_node_set,
    cluster_nodes,
    cluster_node_order,
    cluster_groups,
    cluster_rank_keys,
    cluster_fixed_positions,
  })
}
