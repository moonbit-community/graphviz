///|
/// Ordering domain: cluster-local reorder execution helpers used by
/// Stage C clustered local replay orchestration.

/// Graphviz parity: cluster-local mincross runs only when a cluster has
/// internal ordering constraints; otherwise the input order is preserved.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_reorder(
  local_context : ClusterLocalReorderContext,
  input_phase_output : ClusterLocalReorderRunInputsOutput,
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> Map[Int, Array[String]]? {
  if input_phase_output.cluster_edges.length() == 0 &&
    input_phase_output.cluster_flat_constraints.length() == 0 {
    return None
  }
  let seeded_cluster_groups =
    build_cluster_rank_seeded_groups(
      local_context,
      input_phase_output,
      dispatch_context.fixed_ranks,
    )
  let ordered_cluster =
    run_cluster_local_rank_reorder_call(
      {
        cluster_rank_keys: local_context.cluster_rank_keys,
        seeded_cluster_groups,
        cluster_edges: input_phase_output.cluster_edges,
        cluster_edge_tail: input_phase_output.cluster_edge_tail,
        cluster_edge_head: input_phase_output.cluster_edge_head,
        cluster_edge_tail_port_x: input_phase_output.cluster_edge_tail_port_x,
        cluster_edge_head_port_x: input_phase_output.cluster_edge_head_port_x,
        cluster_edge_tail_port_order: input_phase_output.cluster_edge_tail_port_order,
        cluster_edge_head_port_order: input_phase_output.cluster_edge_head_port_order,
        parents: input_phase_output.parents,
        children: input_phase_output.children,
        cluster_keys: input_phase_output.cluster_keys,
        rank_same_groups: dispatch_context.rank_same_groups,
        rank_same_order: dispatch_context.rank_same_order,
        edge_order: input_phase_output.edge_order,
        cluster_node_order: local_context.cluster_node_order,
        cluster_sizes: input_phase_output.cluster_sizes,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        cluster_flat_constraints: input_phase_output.cluster_flat_constraints,
        graphviz_out_neighbors: input_phase_output.graphviz_out_neighbors,
        graphviz_in_neighbors: input_phase_output.graphviz_in_neighbors,
        cluster_fixed_positions: local_context.cluster_fixed_positions,
        fixed_ranks: dispatch_context.fixed_ranks,
      },
    )
  Some(ordered_cluster)
}

///|
/// Graphviz parity: each cluster-local reorder pass reuses global fixed slots,
/// but only mutates rank entries that belong to that cluster.
/// Do not change behavior without updating fixtures/tests.
fn reorder_cluster_rank_group(
  cluster : String,
  expanded_clusters : Map[String, Bool],
  cluster_graph : @cgraph.Graph,
  groups : Map[Int, Array[String]],
  fixed_positions : Map[String, Double],
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> Unit {
  let local_context = match build_cluster_local_reorder_context(
    {
      cluster,
      cluster_graph,
      groups,
      node_order: dispatch_context.node_order,
      source_out_neighbors: dispatch_context.neighbor_sources.source_out_neighbors,
      vnode_clusters: dispatch_context.vnode_clusters,
      fixed_positions,
      order_with_vnodes: dispatch_context.order_with_vnodes,
    },
  ) {
    Some(value) => value
    None => return ()
  }
  let cluster_graph_edge_count = cluster_graph.edges().length()
  let include_external_crossing =
    should_include_external_crossing_edges(
      local_context.cluster_rank_keys,
      cluster_graph_edge_count,
      count_edge_vnodes(local_context.cluster_nodes),
    )
  let input_context : ClusterLocalReorderInputBuildContext = {
    cluster_name: cluster,
    include_external_crossing,
    expanded_clusters,
    order_edges: dispatch_context.order_edges,
    order_edge_tail: dispatch_context.order_edge_tail,
    order_edge_head: dispatch_context.order_edge_head,
    order_edge_tail_port_x: dispatch_context.order_edge_tail_port_x,
    order_edge_head_port_x: dispatch_context.order_edge_head_port_x,
    order_edge_tail_port_order: dispatch_context.order_edge_tail_port_order,
    order_edge_head_port_order: dispatch_context.order_edge_head_port_order,
    neighbor_sources: dispatch_context.neighbor_sources,
    cluster_node_set: local_context.cluster_node_set,
    cluster_nodes: local_context.cluster_nodes,
    fixed_ranks: dispatch_context.fixed_ranks,
    order_sizes: dispatch_context.order_sizes,
    vnode_sizes: dispatch_context.vnode_sizes,
    intercluster_keys: dispatch_context.intercluster_keys,
    flat_constraints: dispatch_context.flat_constraints,
  }
  let input_phase_output =
    build_local_reorder_inputs(input_context)
  let ordered_cluster = match run_cluster_rank_reorder(
    local_context,
    input_phase_output,
    dispatch_context,
  ) {
    Some(value) => value
    None => return ()
  }
  apply_cluster_rank_reorder_output(
    groups,
    local_context.cluster_rank_keys,
    ordered_cluster,
    local_context.cluster_node_set,
  )
}

///|
/// Graphviz parity: cluster-local reorder iterates clusters in deterministic
/// build order and applies one independent local pass per cluster.
/// Do not change behavior without updating fixtures/tests.
pub fn reorder_cluster_rank_groups(
  cluster_names : Array[String],
  cluster_graphs : Map[String, @cgraph.Graph],
  groups : Map[Int, Array[String]],
  fixed_positions : Map[String, Double],
  dispatch_context : ClusterLocalReorderDispatchContext,
) -> Unit {
  let expanded_clusters : Map[String, Bool] = Map::new()
  let mut current_fixed_positions = fixed_positions
  for cluster in cluster_names {
    let cluster_graph = match cluster_graphs.get(cluster) {
      Some(value) => value
      None => continue
    }
    reorder_cluster_rank_group(
      cluster,
      expanded_clusters,
      cluster_graph,
      groups,
      current_fixed_positions,
      dispatch_context,
    )
    expanded_clusters[cluster] = true
    current_fixed_positions = order_positions_from_groups(groups)
  }
}

///|
/// Ordering domain: cluster-local reorder input assembly helpers used by
/// Stage C clustered local reorder execution.

///|
/// Graphviz parity: cluster-local reorder dispatch context keeps shared
/// arrays/maps together so each cluster pass reuses one immutable payload.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusterLocalReorderDispatchContext {
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  neighbor_sources : ClusterLocalNeighborSources
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  intercluster_keys : Map[String, String]
  flat_constraints : Map[String, Bool]
  vnode_clusters : Map[String, String]
  vnode_sizes : Map[String, NodeSize]
  fixed_ranks : Map[String, Int]
  order_with_vnodes : Bool
}

///|
pub fn count_edge_vnodes(names : Array[String]) -> Int {
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
pub fn should_include_external_crossing_edges(
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
    match @shared.parse_flat_constraint_key(key) {
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
pub(all) struct ClusterLocalReorderRunInputsOutput {
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
pub(all) struct ClusterLocalReorderInputBuildContext {
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
  neighbor_sources : ClusterLocalNeighborSources
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
  let edge_index_data = build_edge_index_for_names(
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
    edge_order: collect_edge_order(cluster_edges),
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
    build_local_neighbor_maps(
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
pub fn build_local_reorder_inputs(
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

///|
/// Graphviz parity: cluster-local reorder writes only cluster members back to
/// existing rank slots, preserving non-cluster node positions.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_cluster_rank_reorder_output(
  groups : Map[Int, Array[String]],
  cluster_rank_keys : Array[Int],
  ordered_cluster : Map[Int, Array[String]],
  cluster_node_set : Map[String, Bool],
) -> Unit {
  for rank in cluster_rank_keys {
    let desired = ordered_cluster.get(rank).unwrap_or_default()
    if desired.length() <= 1 {
      continue
    }
    let names = match groups.get(rank) {
      Some(list) => list
      None => continue
    }
    let mut idx = 0
    let mut pos = 0
    while pos < names.length() && idx < desired.length() {
      if cluster_node_set.get(names[pos]) is Some(_) {
        names[pos] = desired[idx]
        idx = idx + 1
      }
      pos = pos + 1
    }
  }
}
