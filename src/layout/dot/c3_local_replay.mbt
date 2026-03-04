///|
/// Stage C Phase C3 split: cluster-local replay pass orchestration
/// and shared dispatch payload for local cluster rank reordering.

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
      compare_by_order_then_name(node_order, a, b)
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
  let cluster_groups = build_local_rank_groups(
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
    @ordering.run_cluster_local_rank_reorder_call(
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
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
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
/// Graphviz parity: cluster-local reorder writes only cluster members back to
/// existing rank slots, preserving non-cluster node positions.
fn apply_cluster_rank_reorder_output(
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
      vnode_clusters: dispatch_context.vnode_info.vnode_clusters,
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
    vnode_sizes: dispatch_context.vnode_info.vnode_sizes,
    intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
    flat_constraints: dispatch_context.cluster_meta.flat_constraints,
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
fn reorder_cluster_rank_groups(
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
    current_fixed_positions = @ordering.order_positions_from_groups(groups)
  }
}

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
fn run_cluster_local_rank_replay(
  groups : Map[Int, Array[String]],
  replay_context : ClusterLocalRankReplayContext,
) -> Unit {
  if replay_context.cluster_meta.cluster_order.length() == 0 {
    return ()
  }
  let cluster_graph_order =
    build_cluster_graph_order(
      replay_context.graph,
      replay_context.cluster_meta.cluster_order,
      replay_context.cluster_meta.cluster_parents,
    )
  let cluster_graphs = cluster_graph_order.cluster_graphs
  let cluster_names = cluster_graph_order.cluster_names
  if cluster_graphs.length() == 0 {
    return ()
  }
  let fixed_positions = @ordering.order_positions_from_groups(groups)
  let fixed_ranks = build_cluster_replay_fixed_ranks(replay_context)
  let neighbor_sources = build_cluster_replay_neighbor_sources(replay_context)
  let dispatch_context =
    build_cluster_replay_dispatch_context(
      replay_context,
      neighbor_sources,
      fixed_ranks,
    )
  reorder_cluster_rank_groups(
    cluster_names,
    cluster_graphs,
    groups,
    fixed_positions,
    dispatch_context,
  )
}

///|
/// Graphviz parity: local cluster replay applies only when clustered ordering
/// is enabled and uses pre-root unmapped order-graph snapshots.
/// Do not change behavior without updating fixtures/tests.
fn apply_cluster_local_rank_replay_after_root(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : @ordering.RootAndClusterRanksOutput,
) -> Unit {
  if !dispatch_context.reorder_setup.order_with_clusters {
    return ()
  }
  let replay_context =
    build_cluster_local_rank_replay_context(
      dispatch_context,
      pre_root_stage.reorder_context,
      pre_root_stage.materialized,
      pre_root_stage.order_sizes_out,
    )
  run_cluster_local_rank_replay(root_cluster_stage.ordered, replay_context)
}
