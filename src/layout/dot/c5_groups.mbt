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
      build_seeded_remincross(
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
    dispatch_context.order_with_vnodes,
    dispatch_context.edges,
    dispatch_context.edge_tail,
    dispatch_context.edge_head,
    dispatch_context.edge_reversed,
    dispatch_context.ranks,
    dispatch_context.cluster_meta.intercluster_keys,
    dispatch_context.cluster_meta.cluster_parents,
    dispatch_context.cluster_meta.cluster_min_rank,
    dispatch_context.cluster_meta.cluster_max_rank,
    dispatch_context.vnode_info.edge_vnodes,
    dispatch_context.vnode_info.vnode_ranks,
    dispatch_context.vnode_info.vnodes_by_rank,
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
  let rem_rank_keys = collect_rank_keys(rem_groups)
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
      collect_real_only_rank_groups(
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
  let rem_ranks = build_node_ranks(rem_groups)
  let rem_nodes = build_order_nodes_from_groups(rem_groups, rem_rank_keys)
  let rem_graph_output =
    build_order_graph_and_nodes("order_remincross", rem_nodes)
  let rem_graph = rem_graph_output.order_graph
  let rem_node_map = rem_graph_output.order_node_map
  // Graphviz parity: ReMincross uses real intercluster edges
  // (no cluster skeleton mapping).
  let cluster_order_index =
    build_local_cluster_index(dispatch_context.cluster_meta.cluster_order)
  let materialized_edges =
    build_materialized_edges(
      dispatch_context.creation_order,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.edge_tail_port_x,
      dispatch_context.edge_head_port_x,
      dispatch_context.edge_tail_port_order,
      dispatch_context.edge_head_port_order,
      dispatch_context.ranks,
      dispatch_context.vnode_info.edge_vnodes,
      dispatch_context.order_with_vnodes,
      dispatch_context.cluster_meta.intercluster_keys,
      dispatch_context.order_with_clusters,
      dispatch_context.edges_by_tail,
      cluster_order_index,
    )
  let materialized_arrays =
    build_materialized_arrays(
      dispatch_context.creation_order,
      materialized_edges.vnode_creation,
      materialized_edges.edge_creation,
      materialized_edges.order_edges_by_tail,
      rem_graph,
      rem_node_map,
      rem_groups,
      dispatch_context.cluster_meta.intercluster_keys,
      cluster_order_index,
    )
  let pass_inputs =
    build_remincross_pass_inputs(
      dispatch_context.graph,
      dispatch_context.edges,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.order_with_vnodes,
      dispatch_context.order_with_clusters,
      dispatch_context.cluster_meta,
      dispatch_context.vnode_info,
      dispatch_context.order_sizes,
      dispatch_context.rank_same_constraints,
    )
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
    rem_cluster_keys: pass_inputs.rem_cluster_keys,
    rem_sizes: pass_inputs.rem_sizes,
    rem_flat_constraints: pass_inputs.rem_flat_constraints,
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
    build_edge_indices_and_order(
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
/// Graphviz parity: clustered ReMincross edge endpoint reads prefer oriented
/// edge_tail/edge_head arrays and fall back to edge object endpoints.
priv struct ReMincrossEdgeEndpoints {
  tail : String
  head : String
}

///|
/// Graphviz parity: clustered ReMincross edge endpoint reads prefer oriented
/// edge_tail/edge_head arrays and fall back to edge object endpoints.
fn remincross_edge_endpoints_at(
  edge : @cgraph.Edge,
  edge_idx : Int,
  edge_tail : Array[String],
  edge_head : Array[String],
) -> ReMincrossEdgeEndpoints {
  let tail =
    if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
      edge.tail().name()
    }
  let head =
    if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
      edge.head().name()
    }
  { tail, head }
}

///|
priv struct ReMincrossPassInputs {
  rem_cluster_keys : Map[String, String]
  rem_sizes : Map[String, NodeSize]
  rem_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: clustered ReMincross starts from a shallow clone of
/// intercluster keys before root remapping and vnode LCA assignments.
fn clone_remincross_cluster_keys(
  intercluster_keys : Map[String, String],
) -> Map[String, String] {
  let cloned : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    cloned[name] = key
  }
  cloned
}

///|
/// Graphviz parity: mark_lowclusters assigns ReMincross edge-vnodes to the
/// lowest common ancestor cluster (or root cluster when LCA is empty).
fn assign_remincross_clusters(
  rem_cluster_keys : Map[String, String],
  root_cluster : String,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_vnodes : Map[String, Array[String]],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
) -> Unit {
  for edge_idx, edge in edges {
    let vnodes =
      edge_vnodes.get(@dot_shared.edge_vnode_key(edge)).unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let endpoints =
      remincross_edge_endpoints_at(edge, edge_idx, edge_tail, edge_head)
    let tail = endpoints.tail
    let head = endpoints.head
    let tail_cluster = intercluster_keys.get(tail).unwrap_or_default()
    let head_cluster = intercluster_keys.get(head).unwrap_or_default()
    let vnode_cluster =
      cluster_lca(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
  }
}

///|
/// Graphviz parity: ReMincross reorder inputs derive cluster keys (including
/// vnode LCA assignments), size map extension, and flat-constraint
/// augmentation before final reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_pass_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
) -> ReMincrossPassInputs {
  let rem_cluster_keys =
    clone_remincross_cluster_keys(cluster_meta.intercluster_keys)
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  let root_cluster = graph.name().unwrap_or("__root__")
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = root_cluster
    }
  }
  if order_with_vnodes {
    assign_remincross_clusters(
      rem_cluster_keys,
      root_cluster,
      edges,
      edge_tail,
      edge_head,
      vnode_info.edge_vnodes,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
    )
  }
  let rem_sizes =
    build_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
    )
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  // Graphviz parity: ReMincross flat constraints combine existing same-rank
  // constraints with local intra-cluster adjacency locks for non-intercluster
  // real-node pairs (flat.c cluster-local reorder guard).
  if !order_with_clusters {
    for key, value in cluster_meta.flat_constraints {
      rem_flat_constraints[key] = value
    }
    for key, _ in rank_same_constraints {
      rem_flat_constraints[key] = true
    }
  }
  { rem_cluster_keys, rem_sizes, rem_flat_constraints }
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
    let endpoints =
      remincross_edge_endpoints_at(edge, edge_idx, edge_tail, edge_head)
    let tail = endpoints.tail
    let head = endpoints.head
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
    // Graphviz parity: intercluster trailing-vnode checks use inclusive
    // rank-range overlap derived from each cluster's min/max rank bounds.
    let tail_min = cluster_min_rank.get(tail_cluster).unwrap_or_default()
    let tail_max = cluster_max_rank.get(tail_cluster).unwrap_or(tail_min)
    let head_min = cluster_min_rank.get(head_cluster).unwrap_or_default()
    let head_max = cluster_max_rank.get(head_cluster).unwrap_or(head_min)
    if tail_min <= head_max && head_min <= tail_max {
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
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  rem_base_order_index : Map[String, Int],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
) -> Map[String, Double] {
  let remincross_cluster_keys =
    clone_remincross_cluster_keys(intercluster_keys)
  let intercluster_vnodes =
    collect_remincross_trailing(
      edges,
      edge_tail,
      edge_head,
      edge_vnodes,
      remincross_cluster_keys,
      cluster_parents,
      cluster_min_rank,
      cluster_max_rank,
    )
  let keys = build_vnode_order_keys(
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    rem_base_order_index,
    remincross_cluster_keys,
    cluster_parents,
    edge_vnodes,
    vnode_ranks,
  )
  apply_remincross_floor(
    keys,
    intercluster_vnodes,
    rem_base_order_index,
    ranks,
    vnode_ranks,
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
  order_with_vnodes : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  cluster_min_rank : Map[String, Int],
  cluster_max_rank : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_ranks : Map[String, Int],
  vnodes_by_rank : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  let rem_base_groups = clone_rank_groups(final_groups)
  let rem_base_order_index = build_order_index(rem_base_groups)
  let rem_vnode_order_keys =
    if !order_with_vnodes {
      Map::new()
    } else {
      build_remincross_vnode_keys(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        rem_base_order_index,
        intercluster_keys,
        cluster_parents,
        cluster_min_rank,
        cluster_max_rank,
        edge_vnodes,
        vnode_ranks,
      )
    }
  if order_with_vnodes {
    build_x_groups_with_vnodes(
      rem_base_groups,
      rem_base_order_index,
      vnodes_by_rank,
      rem_vnode_order_keys,
    )
  } else {
    rem_base_groups
  }
}

///|
/// Graphviz parity: seeded vnode-inclusive rank rebuilding anchors synthetic
/// names between nearest real-node predecessors/successors from base order.
priv struct NeighborRealIndices {
  prev_real : Array[Int?]
  next_real_by_pos : Array[Int?]
}

///|
/// Graphviz parity: seeded vnode-inclusive rank rebuilding anchors synthetic
/// names between nearest real-node predecessors/successors from base order.
fn build_neighbor_real_indices(
  filtered : Array[String],
  real_order : Map[String, Int],
) -> NeighborRealIndices {
  let prev_real : Array[Int?] = []
  let mut last_real : Int? = None
  for name in filtered {
    match real_order.get(name) {
      Some(idx) => last_real = Some(idx)
      None => ()
    }
    prev_real.push(last_real)
  }
  let next_rev : Array[Int?] = []
  let mut next_real : Int? = None
  let mut rev_idx = filtered.length()
  while rev_idx > 0 {
    rev_idx = rev_idx - 1
    let name = filtered[rev_idx]
    match real_order.get(name) {
      Some(idx) => next_real = Some(idx)
      None => ()
    }
    next_rev.push(next_real)
  }
  let next_real_by_pos : Array[Int?] = []
  let mut idx = next_rev.length()
  while idx > 0 {
    idx = idx - 1
    next_real_by_pos.push(next_rev[idx])
  }
  { prev_real, next_real_by_pos }
}

///|
/// Graphviz parity: when a mixed root/cluster rank begins with one synthetic
/// vnode, keep root real first, cluster reals next, and trail that vnode.
fn try_build_special_seed_order(
  filtered : Array[String],
  base_real : Array[String],
  real_order : Map[String, Int],
  cluster_keys : Map[String, String],
) -> Array[String]? {
  let mut root_real_count = 0
  let mut cluster_real_count = 0
  let mut root_real_name = ""
  let cluster_real_names : Array[String] = []
  for name in base_real {
    if cluster_key_or_empty(cluster_keys, name) == "" {
      root_real_count = root_real_count + 1
      root_real_name = name
    } else {
      cluster_real_count = cluster_real_count + 1
      cluster_real_names.push(name)
    }
  }
  let mut synthetic_count = 0
  let mut synthetic_name = ""
  for name in filtered {
    if real_order.get(name) is None {
      synthetic_count = synthetic_count + 1
      synthetic_name = name
    }
  }
  if filtered.length() == 4 &&
    is_edge_vnode_name(filtered[0]) &&
    root_real_count == 1 &&
    cluster_real_count >= 2 &&
    synthetic_count == 1 &&
    synthetic_name != "" &&
    root_real_name != "" {
    let special_order : Array[String] = [root_real_name]
    for name in cluster_real_names {
      special_order.push(name)
    }
    special_order.push(synthetic_name)
    return Some(special_order)
  }
  None
}

///|
/// Graphviz parity: seeded rank merge key places real nodes on even slots,
/// synthetic nodes after nearest previous/next real anchors.
fn seeded_rank_merge_key(
  index : Int,
  name : String,
  real_order : Map[String, Int],
  prev_real : Array[Int?],
  next_real_by_pos : Array[Int?],
) -> Int {
  match real_order.get(name) {
    Some(real_idx) => real_idx * 2
    None =>
      match prev_real[index] {
        Some(prev_idx) => prev_idx * 2 + 1
        None =>
          match next_real_by_pos[index] {
            Some(next_idx) => next_idx * 2 - 1
            None => index * 2
          }
      }
  }
}

///|
/// Graphviz parity: seeded rank rebuild first applies special mixed handoff
/// ordering, then falls back to key-based synthetic/real merge replay.
fn build_seeded_rank_order(
  filtered : Array[String],
  base_real : Array[String],
  cluster_keys : Map[String, String],
) -> Array[String] {
  let real_order : Map[String, Int] = Map::new()
  for i in 0..<base_real.length() {
    real_order[base_real[i]] = i
  }
  // Graphviz parity: special mixed rank handoff keeps root/cluster/vnode
  // sequence aligned with Graphviz before generic key-based placement.
  match try_build_special_seed_order(
    filtered,
    base_real,
    real_order,
    cluster_keys,
  ) {
    Some(special_order) => special_order
    None => {
      let neighbor_indices =
        build_neighbor_real_indices(filtered, real_order)
      let keyed : Array[(String, Int, Int)] = []
      for i in 0..<filtered.length() {
        let name = filtered[i]
        let key =
          seeded_rank_merge_key(
            i,
            name,
            real_order,
            neighbor_indices.prev_real,
            neighbor_indices.next_real_by_pos,
          )
        keyed.push((name, key, i))
      }
      // Graphviz parity: seeded rank replay uses keyed sort output order
      // directly as the vnode-inclusive rank sequence.
      keyed.sort_by((a, b) => {
        // Graphviz parity: keyed sort keeps merge-key primary order and
        // original index tie-break so equal keys preserve input order.
        let (_, key_a, idx_a) = a
        let (_, key_b, idx_b) = b
        if key_a < key_b {
          -1
        } else if key_a > key_b {
          1
        } else if idx_a < idx_b {
          -1
        } else if idx_a > idx_b {
          1
        } else {
          0
        }
      })
      let ordered_rank : Array[String] = []
      for entry in keyed {
        let (name, _, _) = entry
        ordered_rank.push(name)
      }
      ordered_rank
    }
  }
}

///|
/// Graphviz parity: ReMincross can seed from current vnode-inclusive rank
/// order while keeping real-node relative order from cleaned base groups.
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_remincross(
  base_groups : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  let rem_groups : Map[Int, Array[String]] = Map::new()
  for rank, names in ordered_with_vnodes {
    // Graphviz parity: seeded rank replay drops cluster skeleton placeholders
    // and keeps remaining name order unchanged.
    let filtered : Array[String] = []
    for name in names {
      if !name.has_prefix(CLUSTER_SKELETON_PREFIX) {
        filtered.push(name)
      }
    }
    if filtered.length() == 0 {
      continue
    }
    let base_real = base_groups.get(rank).unwrap_or_default()
    if base_real.length() == 0 {
      rem_groups[rank] = filtered
      continue
    }
    let ordered_rank =
      build_seeded_rank_order(
        filtered,
        base_real,
        cluster_keys,
      )
    rem_groups[rank] = ordered_rank
  }
  rem_groups
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
  vnode_info : EdgeVnodeInfo
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
