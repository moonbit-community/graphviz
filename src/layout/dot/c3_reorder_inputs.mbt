///|
/// Stage C Phase C3 split: cluster-local reorder input assembly helpers.

///|
/// Graphviz parity: cluster-local reorder dispatch context keeps shared
/// arrays/maps together so each cluster pass reuses one immutable payload.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderDispatchContext {
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  neighbor_sources : @ordering.ClusterLocalNeighborSources
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  cluster_meta : ClusterMetadata
  vnode_info : @routing.EdgeVnodeInfo
  fixed_ranks : Map[String, Int]
  order_with_vnodes : Bool
}

///|
fn count_edge_vnodes(names : Array[String]) -> Int {
  let mut vnode_count = 0
  for name in names {
    if is_edge_vnode_name(name) {
      vnode_count = vnode_count + 1
    }
  }
  vnode_count
}

///|
/// Graphviz parity: shallow cluster-local reorder (<=2 ranks) keeps incoming
/// and outgoing crossing edges so median anchors see external slots.
/// Do not change behavior without updating fixtures/tests.
fn should_include_external_crossing_edges(
  cluster_rank_keys : Array[Int],
  cluster_graph_edge_count : Int,
  vnode_count : Int,
) -> Bool {
  if @sys.get_env_var("DOT_CAPTURE_ORDERING_FIXTURE_MODE") is Some(_) {
    return cluster_rank_keys.length() <= 2
  }
  if cluster_rank_keys.length() > 2 &&
    cluster_graph_edge_count == 0 &&
    vnode_count == 0 {
    return false
  }
  true
}

///|
fn build_cluster_sizes_for_reorder(
  cluster_node_set : Map[String, Bool],
  order_sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  // Graphviz parity: cluster-local reorder metadata keeps node sizes scoped to
  // the filtered cluster node subset.
  let cluster_sizes : Map[String, NodeSize] = Map::new()
  for name, _ in cluster_node_set {
    match order_sizes.get(name) {
      Some(size) => cluster_sizes[name] = size
      None =>
        match vnode_sizes.get(name) {
          Some(size) => cluster_sizes[name] = size
          None => ()
        }
    }
  }
  cluster_sizes
}

///|
fn filter_cluster_flat_constraints(
  cluster_node_set : Map[String, Bool],
  flat_constraints : Map[String, Bool],
) -> Map[String, Bool] {
  // Graphviz parity: local reorder forwards same-rank flat constraints only
  // when both endpoints belong to the active cluster node subset.
  let cluster_flat_constraints : Map[String, Bool] = Map::new()
  for key, value in flat_constraints {
    if !value {
      continue
    }
    match @dot_shared.parse_flat_constraint_key(key) {
      Some((tail, head)) => {
        if cluster_node_set.get(tail) is Some(_) &&
          cluster_node_set.get(head) is Some(_) {
          cluster_flat_constraints[key] = value
        }
      }
      None => ()
    }
  }
  cluster_flat_constraints
}

///|
/// Graphviz parity: cluster-local reorder run-input payload keeps edge arrays
/// and metadata maps grouped for dispatch into reorder_rank_groups.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderRunInputsOutput {
  cluster_edges : Array[@cgraph.Edge]
  cluster_edge_tail : Array[String]
  cluster_edge_head : Array[String]
  cluster_edge_tail_port_x : Array[Double]
  cluster_edge_head_port_x : Array[Double]
  cluster_edge_tail_port_order : Array[Double]
  cluster_edge_head_port_order : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  edge_order : Map[String, Int]
  cluster_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  cluster_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: cluster-local reorder input build context keeps the
/// per-cluster node subset together with shared edge/neighbor snapshots.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalReorderInputBuildContext {
  cluster_name : String
  include_external_crossing : Bool
  expanded_clusters : Map[String, Bool]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  neighbor_sources : @ordering.ClusterLocalNeighborSources
  cluster_node_set : Map[String, Bool]
  cluster_nodes : Array[String]
  fixed_ranks : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  vnode_sizes : Map[String, NodeSize]
  intercluster_keys : Map[String, String]
  flat_constraints : Map[String, Bool]
}

///|
priv struct LocalReorderEdgeBundle {
  cluster_edges : Array[@cgraph.Edge]
  cluster_edge_tail : Array[String]
  cluster_edge_head : Array[String]
  cluster_edge_tail_port_x : Array[Double]
  cluster_edge_head_port_x : Array[Double]
  cluster_edge_tail_port_order : Array[Double]
  cluster_edge_head_port_order : Array[Double]
  parents : Map[String, Array[String]]
  children : Map[String, Array[String]]
  edge_order : Map[String, Int]
}

///|
/// Graphviz parity: shallow cluster-local reorder (<=2 ranks) keeps incoming
/// and outgoing crossing edges so median anchors see external slots.
/// Do not change behavior without updating fixtures/tests.
fn build_local_reorder_edge_bundle(
  input_context : ClusterLocalReorderInputBuildContext,
) -> LocalReorderEdgeBundle {
  let cluster_edges : Array[@cgraph.Edge] = []
  let cluster_edge_tail : Array[String] = []
  let cluster_edge_head : Array[String] = []
  let cluster_edge_tail_port_x : Array[Double] = []
  let cluster_edge_head_port_x : Array[Double] = []
  let cluster_edge_tail_port_order : Array[Double] = []
  let cluster_edge_head_port_order : Array[Double] = []
  for i in 0..<input_context.order_edges.length() {
    let tail = input_context.order_edge_tail[i]
    let head = input_context.order_edge_head[i]
    let tail_in = input_context.cluster_node_set.get(tail) is Some(_)
    let head_in = input_context.cluster_node_set.get(head) is Some(_)
    let keep = (tail_in && head_in) ||
      (input_context.include_external_crossing && (tail_in || head_in))
    if !keep {
      continue
    }
    cluster_edges.push(input_context.order_edges[i])
    cluster_edge_tail.push(tail)
    cluster_edge_head.push(head)
    cluster_edge_tail_port_x.push(input_context.order_edge_tail_port_x[i])
    cluster_edge_head_port_x.push(input_context.order_edge_head_port_x[i])
    cluster_edge_tail_port_order.push(input_context.order_edge_tail_port_order[i])
    cluster_edge_head_port_order.push(input_context.order_edge_head_port_order[i])
  }
  let edge_index_data = @ordering.build_edge_index_for_names(
    input_context.cluster_nodes,
    cluster_edge_tail,
    cluster_edge_head,
    input_context.fixed_ranks,
  )
  {
    cluster_edges,
    cluster_edge_tail,
    cluster_edge_head,
    cluster_edge_tail_port_x,
    cluster_edge_head_port_x,
    cluster_edge_tail_port_order,
    cluster_edge_head_port_order,
    parents: edge_index_data.parents,
    children: edge_index_data.children,
    edge_order: @ordering.collect_edge_order(cluster_edges),
  }
}

///|
/// Graphviz parity: local cluster keys are cleared for all active cluster
/// nodes so cluster-local reorder ignores cross-cluster barriers.
fn build_local_reorder_cluster_keys(
  cluster_node_set : Map[String, Bool],
) -> Map[String, String] {
  let cluster_keys : Map[String, String] = Map::new()
  for name, _ in cluster_node_set {
    // Graphviz parity: mincross_clust() runs on the expanded subgraph where
    // ND_clust is cleared, so local reorder/transpose should not see
    // cross-cluster barriers for these nodes.
    cluster_keys[name] = ""
  }
  cluster_keys
}

///|
/// Graphviz parity: cluster-local reorder metadata keeps node sizes, local
/// cluster-key resets, flat constraints, and neighbor maps scoped together.
priv struct ClusterLocalReorderMetadata {
  cluster_sizes : Map[String, NodeSize]
  cluster_keys : Map[String, String]
  cluster_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
}

///|
/// Graphviz parity: cluster-local reorder metadata is assembled from one
/// cluster-node subset and one filtered edge bundle snapshot.
fn build_cluster_local_reorder_metadata(
  input_context : ClusterLocalReorderInputBuildContext,
  edge_bundle : LocalReorderEdgeBundle,
) -> ClusterLocalReorderMetadata {
  let cluster_sizes =
    build_cluster_sizes_for_reorder(
      input_context.cluster_node_set,
      input_context.order_sizes,
      input_context.vnode_sizes,
    )
  let cluster_keys =
    build_local_reorder_cluster_keys(input_context.cluster_node_set)
  let cluster_flat_constraints =
    filter_cluster_flat_constraints(
      input_context.cluster_node_set,
      input_context.flat_constraints,
    )
  let local_neighbor_maps =
    @ordering.build_local_neighbor_maps(
      input_context.cluster_name,
      input_context.expanded_clusters,
      input_context.cluster_nodes,
      input_context.neighbor_sources,
      input_context.intercluster_keys,
      edge_bundle.cluster_edges.length() >= 5,
    )
  {
    cluster_sizes,
    cluster_keys,
    cluster_flat_constraints,
    graphviz_out_neighbors: local_neighbor_maps.graphviz_out_neighbors,
    graphviz_in_neighbors: local_neighbor_maps.graphviz_in_neighbors,
  }
}

///|
/// Graphviz parity: cluster-local reorder builds internal edge bundle and
/// metadata maps from the same filtered cluster node subset.
/// Do not change behavior without updating fixtures/tests.
fn build_local_reorder_inputs(
  input_context : ClusterLocalReorderInputBuildContext,
) -> ClusterLocalReorderRunInputsOutput {
  let edge_bundle =
    build_local_reorder_edge_bundle(input_context)
  let metadata =
    build_cluster_local_reorder_metadata(input_context, edge_bundle)
  {
    cluster_edges: edge_bundle.cluster_edges,
    cluster_edge_tail: edge_bundle.cluster_edge_tail,
    cluster_edge_head: edge_bundle.cluster_edge_head,
    cluster_edge_tail_port_x: edge_bundle.cluster_edge_tail_port_x,
    cluster_edge_head_port_x: edge_bundle.cluster_edge_head_port_x,
    cluster_edge_tail_port_order: edge_bundle.cluster_edge_tail_port_order,
    cluster_edge_head_port_order: edge_bundle.cluster_edge_head_port_order,
    parents: edge_bundle.parents,
    children: edge_bundle.children,
    graphviz_out_neighbors: metadata.graphviz_out_neighbors,
    graphviz_in_neighbors: metadata.graphviz_in_neighbors,
    edge_order: edge_bundle.edge_order,
    cluster_sizes: metadata.cluster_sizes,
    cluster_keys: metadata.cluster_keys,
    cluster_flat_constraints: metadata.cluster_flat_constraints,
  }
}
