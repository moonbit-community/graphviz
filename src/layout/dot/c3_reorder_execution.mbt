///|
/// Stage C Phase C3 split: cluster-local reorder execution helpers.

/// Graphviz parity: cluster-local mincross runs only when a cluster has
/// internal ordering constraints; otherwise the input order is preserved.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_reorder(
  local_context : @ordering.ClusterLocalReorderContext,
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
  let local_context = match @ordering.build_cluster_local_reorder_context(
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
