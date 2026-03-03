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
  build_remincross_vnode_groups(
    dispatch_context.base_groups,
    dispatch_context,
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
      build_remincross_inputs(
        dispatch_context,
        rem_rank_keys,
        rem_groups,
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
/// Graphviz parity: clustered ReMincross materialized-input payload keeps
/// graph node/rank context, rematerialized edge arrays, and final reorder
/// maps for cleanup reorder dispatch.
priv struct ClusteredReMincrossMaterializedInputs {
  rem_nodes : Array[String]
  rem_ranks : Map[String, Int]
  rem_node_order : Map[String, Int]
  rem_edges_out : Array[@cgraph.Edge]
  rem_edge_tail_out : Array[String]
  rem_edge_head_out : Array[String]
  rem_edge_tail_port_x : Array[Double]
  rem_edge_head_port_x : Array[Double]
  rem_edge_tail_port_order : Array[Double]
  rem_edge_head_port_order : Array[Double]
  rem_cluster_keys : Map[String, String]
  rem_sizes : Map[String, NodeSize]
  rem_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: clustered ReMincross multi-rank materialization builds
/// order graph context, rematerialized edge arrays, and reorder input maps
/// before cleanup reorder dispatch.
fn build_remincross_inputs(
  dispatch_context : ReMincrossDispatchContext,
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
) -> ClusteredReMincrossMaterializedInputs {
  let rem_ranks = @ordering.build_node_ranks(rem_groups)
  let rem_nodes = @ordering.build_order_nodes_from_groups(rem_groups, rem_rank_keys)
  let rem_graph_output =
    @ordering.build_order_graph_and_nodes("order_remincross", rem_nodes)
  // Graphviz parity: ReMincross uses real intercluster edges
  // (no cluster skeleton mapping).
  let cluster_order_index =
    build_local_cluster_index(dispatch_context.cluster_meta.cluster_order)
  // Graphviz parity: ReMincross rematerialization keeps order-edge expansion
  // and order-graph array materialization on one shared context snapshot.
  let materialized_edges =
    @ordering.build_remincross_materialized_edges(
      {
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
        order_with_clusters: dispatch_context.order_with_clusters,
        edges_by_tail: dispatch_context.edges_by_tail,
        cluster_order_index,
      },
    )
  let materialized_arrays =
    @ordering.build_remincross_materialized_arrays(
      {
        creation_order: dispatch_context.creation_order,
        rem_groups,
        rem_graph: rem_graph_output.order_graph,
        rem_node_map: rem_graph_output.order_node_map,
        rem_cluster_keys: dispatch_context.cluster_meta.intercluster_keys,
        cluster_order_index,
        root_tail_order_override: remincross_root_tail_order_override_snapshot.val,
        materialized_edges,
      },
    )
  let rem_cluster_keys =
    @ordering.build_remincross_cluster_keys(
      {
        root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
        edges: dispatch_context.edges,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        edge_vnodes: dispatch_context.vnode_info.edge_vnodes,
        intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
        cluster_parents: dispatch_context.cluster_meta.cluster_parents,
        order_with_vnodes: dispatch_context.order_with_vnodes,
      },
    )
  let rem_sizes =
    @ordering.build_sizes_for_order_graph(
      dispatch_context.order_sizes,
      dispatch_context.order_with_vnodes,
      dispatch_context.vnode_info.vnode_sizes,
    )
  let rem_flat_constraints =
    build_remincross_flat_constraints(dispatch_context)
  {
    rem_nodes,
    rem_ranks,
    rem_node_order: materialized_arrays.node_order,
    rem_edges_out: materialized_arrays.edges_out,
    rem_edge_tail_out: materialized_arrays.edge_tail_out,
    rem_edge_head_out: materialized_arrays.edge_head_out,
    rem_edge_tail_port_x: materialized_arrays.edge_tail_port_x,
    rem_edge_head_port_x: materialized_arrays.edge_head_port_x,
    rem_edge_tail_port_order: materialized_arrays.edge_tail_port_order,
    rem_edge_head_port_order: materialized_arrays.edge_head_port_order,
    rem_cluster_keys,
    rem_sizes,
    rem_flat_constraints,
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
  materialized_inputs : ClusteredReMincrossMaterializedInputs,
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
/// Graphviz parity: ReMincross flat constraints combine cluster flat locks and
/// rank=same constraints only for non-cluster reorder path.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_flat_constraints(
  dispatch_context : ReMincrossDispatchContext,
) -> Map[String, Bool] {
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  // Graphviz parity: ReMincross flat constraints combine existing same-rank
  // constraints with local intra-cluster adjacency locks for non-intercluster
  // real-node pairs (flat.c cluster-local reorder guard).
  if !dispatch_context.order_with_clusters {
    for key, value in dispatch_context.cluster_meta.flat_constraints {
      rem_flat_constraints[key] = value
    }
    for key, _ in dispatch_context.rank_same_constraints {
      rem_flat_constraints[key] = true
    }
  }
  rem_flat_constraints
}

///|
/// Graphviz parity: intercluster trailing-vnode checks use inclusive overlap
/// over each cluster's min/max rank bounds with min-rank fallback.
/// Do not change behavior without updating fixtures/tests.
fn cluster_rank_ranges_overlap(
  tail_cluster : String,
  head_cluster : String,
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Bool {
  let tail_min = cluster_min_rank.get(tail_cluster).unwrap_or_default()
  let tail_max = cluster_max_rank.get(tail_cluster).unwrap_or(tail_min)
  let head_min = cluster_min_rank.get(head_cluster).unwrap_or_default()
  let head_max = cluster_max_rank.get(head_cluster).unwrap_or(head_min)
  tail_min <= head_max && head_min <= tail_max
}

///|
/// Graphviz parity: trailing-vnode candidate set comes from intercluster edge
/// vnode chains on edges that satisfy the rank-range overlap gate.
fn collect_remincross_trailing(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_vnodes : Map[String, Array[String]],
  remincross_cluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_vnodes : Map[String, Bool] = Map::new()
  for edge_idx, edge in edges {
    let (tail, head) =
      @ordering.edge_endpoints_at(
        edge,
        edge_idx,
        edge_tail,
        edge_head,
      )
    let tail_cluster = remincross_cluster_keys.get(tail).unwrap_or_default()
    let head_cluster = remincross_cluster_keys.get(head).unwrap_or_default()
    // Graphviz parity: trailing-vnode tagging applies only to non-internal,
    // non-root, cross-cluster edges whose cluster rank ranges do not overlap.
    let internal =
      tail_cluster != "" && head_cluster != "" &&
      edge_internal_to_cluster(tail_cluster, head_cluster, cluster_parents)
    if internal ||
      tail_cluster == head_cluster ||
      tail_cluster == "" ||
      head_cluster == "" {
      continue
    }
    if cluster_rank_ranges_overlap(
      tail_cluster,
      head_cluster,
      cluster_min_rank,
      cluster_max_rank,
    ) {
      continue
    }
    let vnodes =
      edge_vnodes.get(@dot_shared.edge_vnode_key(edge)).unwrap_or_default()
    for vnode in vnodes {
      intercluster_vnodes[vnode] = true
    }
  }
  intercluster_vnodes
}

///|
/// Graphviz parity: trailing intercluster vnodes are floored behind real-node
/// positions on their rank using stable sequence offsets.
fn apply_remincross_floor(
  keys : Map[String, Double],
  intercluster_vnodes : Map[String, Bool],
  rem_base_order_index : Map[String, Int],
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
) -> Unit {
  if intercluster_vnodes.length() == 0 {
    return ()
  }
  // Graphviz parity: trailing-vnode floor uses maximum real-node order per
  // rank from the current ReMincross base order index.
  let max_order_by_rank : Map[Int, Int] = Map::new()
  for name, order in rem_base_order_index {
    let rank = match ranks.get(name) {
      Some(value) => value
      None => continue
    }
    match max_order_by_rank.get(rank) {
      Some(current) =>
        if order > current {
          max_order_by_rank[rank] = order
        }
      None => max_order_by_rank[rank] = order
    }
  }
  let mut seq = 0
  for vnode, _ in intercluster_vnodes {
    let rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let max_order = max_order_by_rank.get(rank).unwrap_or(-1)
    let base = Double::from_int(max_order + 1)
    let offset = Double::from_int(seq) * 0.000001
    let min_key = base + offset
    match keys.get(vnode) {
      Some(current) =>
        if current < min_key {
          keys[vnode] = min_key
        }
      None => keys[vnode] = min_key
    }
    seq = seq + 1
  }
}

///|
/// Graphviz parity: ReMincross vnode order keys come from base vnode-order
/// scoring plus trailing-vnode floor adjustments for selected intercluster
/// vnode chains.
fn build_remincross_vnode_keys(
  dispatch_context : ReMincrossDispatchContext,
  rem_base_order_index : Map[String, Int],
) -> Map[String, Double] {
  let remincross_cluster_keys : Map[String, String] = Map::new()
  for name, key in dispatch_context.cluster_meta.intercluster_keys {
    remincross_cluster_keys[name] = key
  }
  let intercluster_vnodes =
    collect_remincross_trailing(
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.vnode_info.edge_vnodes,
      remincross_cluster_keys,
      dispatch_context.cluster_meta.cluster_parents,
      dispatch_context.cluster_meta.cluster_min_rank,
      dispatch_context.cluster_meta.cluster_max_rank,
    )
  let keys = build_vnode_order_keys(
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_reversed,
    dispatch_context.ranks,
    rem_base_order_index,
    remincross_cluster_keys,
    dispatch_context.cluster_meta.cluster_parents,
    dispatch_context.vnode_info.edge_vnodes,
    dispatch_context.vnode_info.vnode_ranks,
  )
  apply_remincross_floor(
    keys,
    intercluster_vnodes,
    rem_base_order_index,
    dispatch_context.ranks,
    dispatch_context.vnode_info.vnode_ranks,
  )
  keys
}

///|
/// Graphviz parity: ReMincross rank groups start from real-node groups and
/// optionally inject edge-vnodes using vnode order keys from cluster-aware
/// trailing-vnode adjustments.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_vnode_groups(
  final_groups : Map[Int, Array[String]],
  dispatch_context : ReMincrossDispatchContext,
) -> Map[Int, Array[String]] {
  let rem_base_groups = @ordering.clone_rank_groups(final_groups)
  let rem_base_order_index = @ordering.build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    if !dispatch_context.order_with_vnodes {
      Map::new()
    } else {
      build_remincross_vnode_keys(dispatch_context, rem_base_order_index)
    }
  if dispatch_context.order_with_vnodes {
    @ordering.build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      dispatch_context.vnode_info.vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
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
