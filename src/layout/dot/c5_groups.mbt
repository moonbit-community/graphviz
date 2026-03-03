///|
/// Stage C Phase C5 split: remincross clustered groups
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: clustered ReMincross rank groups can seed from current
/// vnode-inclusive order for single-cluster or ratio=fill scenarios, with
/// fallback to full rebuild when seeded output is empty.
fn build_remincross_groups(
  dispatch_context : ReMincrossDispatchContext,
) -> Map[Int, Array[String]] {
  // Graphviz parity: ratio=fill enables seeded vnode-inclusive reorder input
  // in clustered ReMincross (Graphviz fill-specific branch behavior).
  let prefer_seeded_from_ordered_with_vnodes =
    dispatch_context.graph.get_attr("ratio").unwrap_or_default() == "fill"
  // Graphviz parity: seeded-group path is considered only when vnode ordering
  // is enabled and graph shape matches single-cluster or ratio=fill scenarios.
  let should_try_seeded =
    dispatch_context.order_with_vnodes &&
    (dispatch_context.cluster_meta.cluster_order.length() == 1 ||
    prefer_seeded_from_ordered_with_vnodes)
  if should_try_seeded {
    let seeded =
      @ordering.build_seeded_remincross(
        dispatch_context.base_groups,
        dispatch_context.ordered_with_vnodes,
        dispatch_context.cluster_meta.cluster_keys,
      )
    if seeded.length() > 0 {
      return seeded
    }
  }
  // Graphviz parity: clustered ReMincross rebuilt groups come from base real
  // groups plus optional vnode injection with trailing-vnode adjustments.
  @ordering.build_remincross_vnode_groups(
    {
      final_groups: dispatch_context.base_groups,
      order_with_vnodes: dispatch_context.order_with_vnodes,
      edges: dispatch_context.edges,
      edge_tail: dispatch_context.edge_tail,
      edge_head: dispatch_context.edge_head,
      edge_reversed: dispatch_context.edge_reversed,
      ranks: dispatch_context.ranks,
      intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
      cluster_parents: dispatch_context.cluster_meta.cluster_parents,
      cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
      cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
      edge_vnodes: dispatch_context.vnode_info.edge_vnodes,
      vnode_ranks: dispatch_context.vnode_info.vnode_ranks,
      vnodes_by_rank: dispatch_context.vnode_info.vnodes_by_rank,
    },
    build_vnode_order_keys,
  )
}

///|
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_pass(
  dispatch_context : ReMincrossDispatchContext,
) -> OrderingDispatchOutput {
  let rem_groups = build_remincross_groups(dispatch_context)
  let rem_rank_keys = @ordering.collect_rank_keys(rem_groups)
  if rem_rank_keys.length() <= 1 {
    {
      ordered_groups: dispatch_context.base_groups,
      ordered_with_vnodes: dispatch_context.ordered_with_vnodes,
    }
  } else {
    // Graphviz parity: clustered ReMincross multi-rank branch materializes
    // remapped edges and executes clustered cleanup reorder in startpass=2.
    let materialized_inputs =
      @ordering.build_remincross_materialized_inputs(
        {
          rem_rank_keys,
          rem_groups,
          creation_order: dispatch_context.creation_order,
          edges: dispatch_context.edges,
          edge_tail: dispatch_context.edge_tail,
          edge_head: dispatch_context.edge_head,
          edge_tail_port_x: dispatch_context.edge_tail_port_x,
          edge_head_port_x: dispatch_context.edge_head_port_x,
          edge_tail_port_order: dispatch_context.edge_tail_port_order,
          edge_head_port_order: dispatch_context.edge_head_port_order,
          ranks: dispatch_context.ranks,
          edge_vnodes: dispatch_context.vnode_info.edge_vnodes,
          order_with_vnodes: dispatch_context.order_with_vnodes,
          intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
          cluster_order: dispatch_context.cluster_meta.cluster_order,
          order_with_clusters: dispatch_context.order_with_clusters,
          edges_by_tail: dispatch_context.edges_by_tail,
          root_tail_order_override: remincross_root_tail_order_override_snapshot.val,
          root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
          cluster_parents: dispatch_context.cluster_meta.cluster_parents,
          order_sizes: dispatch_context.order_sizes,
          vnode_sizes: dispatch_context.vnode_info.vnode_sizes,
          cluster_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
          rank_same_constraints: dispatch_context.rank_same_constraints,
        },
      )
    let rem_ordered =
      run_remincross_cleanup(
        dispatch_context,
        rem_rank_keys,
        rem_groups,
        materialized_inputs,
      )
    let rem_cleaned =
      @ordering.collect_real_only_rank_groups(
        rem_rank_keys,
        rem_ordered,
        dispatch_context.real_nodes,
      )
    {
      ordered_groups: rem_cleaned,
      ordered_with_vnodes: rem_ordered,
    }
  }
}

///|
/// Graphviz parity: ReMincross clustered cleanup reorder captures rematerialized
/// inputs, builds edge index maps, and executes startpass=2 mincross on the
/// rematerialized fast-graph edge set.
fn run_remincross_cleanup(
  dispatch_context : ReMincrossDispatchContext,
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  materialized_inputs : @ordering.ReMincrossCleanupMaterializedInputs,
) -> Map[Int, Array[String]] {
  let rem_edge_indices =
    @ordering.build_edge_indices_and_order(
      materialized_inputs.rem_nodes,
      materialized_inputs.rem_edge_tail_out,
      materialized_inputs.rem_edge_head_out,
      materialized_inputs.rem_ranks,
      materialized_inputs.rem_edges_out,
    )
  // Graphviz parity: ReMincross clustered reorder executes mincross with
  // startpass=2 on rematerialized fast-graph edges and local flat constraints.
  capture_remincross_snapshot(
    rem_rank_keys,
    rem_groups,
    materialized_inputs.rem_edges_out,
    materialized_inputs.rem_edge_tail_out,
    materialized_inputs.rem_edge_head_out,
    materialized_inputs.rem_edge_tail_port_x,
    materialized_inputs.rem_edge_head_port_x,
    materialized_inputs.rem_edge_tail_port_order,
    materialized_inputs.rem_edge_head_port_order,
    materialized_inputs.rem_cluster_keys,
  )
  reorder_rank_groups(
    rem_rank_keys,
    rem_groups,
    materialized_inputs.rem_edges_out,
    materialized_inputs.rem_edge_tail_out,
    materialized_inputs.rem_edge_head_out,
    materialized_inputs.rem_edge_tail_port_x,
    materialized_inputs.rem_edge_head_port_x,
    materialized_inputs.rem_edge_tail_port_order,
    materialized_inputs.rem_edge_head_port_order,
    rem_edge_indices.parents,
    rem_edge_indices.children,
    materialized_inputs.rem_cluster_keys,
    dispatch_context.cluster_meta.rank_same_groups,
    dispatch_context.cluster_meta.rank_same_order,
    rem_edge_indices.edge_order,
    materialized_inputs.rem_node_order,
    materialized_inputs.rem_sizes,
    dispatch_context.nodesep_pt,
    dispatch_context.has_edge_labels,
    dispatch_context.port_order_positions,
    dispatch_context.port_order_contrib,
    Map::new(),
    Map::new(),
    materialized_inputs.rem_flat_constraints,
    graphviz_flip=dispatch_context.graphviz_flip,
    // Graphviz parity: ReMincross counts parallel chain segments once
    // with summed xpenalty before startpass=2 transposition.
    coalesce_parallel_edges=true,
    startpass=2,
    remincross_mode=true,
  )
}

///|
/// Graphviz parity: clustered ReMincross pass dispatch context keeps
/// rematerialize+cleanup payload ordering unchanged before rank-count branch.
/// Do not change behavior without updating fixtures/tests.
priv struct ReMincrossDispatchContext {
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_meta : ClusterMetadata
  vnode_info : @routing.EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  base_groups : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}
