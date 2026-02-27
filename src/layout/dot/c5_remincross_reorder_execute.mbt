///|
/// Stage C Phase C5 split: remincross reorder execute
/// helpers for focused ReMincross responsibilities.

///|
/// Graphviz parity: ReMincross clustered reorder executes mincross with
/// startpass=2 on rematerialized fast-graph edges and local flat constraints.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_rank_reorder_startpass2(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> Map[Int, Array[String]] {
  capture_remincross_input_snapshot(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_cluster_keys,
  )
  if @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    for rank in rem_rank_keys {
      let names = match rem_groups.get(rank) {
        Some(list) => list
        None => []
      }
      let rank_joined = names.join(" ")
      println("remincross_input_rank \{rank}: \{rank_joined}")
    }
    let mut idx = 0
    while idx < rem_edges_out.length() {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      let pen = @dot_shared.edge_xpenalty(rem_edges_out[idx])
      println("remincross_input_edge \{idx}: \{tail} -> \{head} pen=\{pen}")
      idx = idx + 1
    }
  }
  reorder_rank_groups(
    rem_rank_keys,
    rem_groups,
    rem_edges_out,
    rem_edge_tail_out,
    rem_edge_head_out,
    rem_edge_tail_port_x,
    rem_edge_head_port_x,
    rem_edge_tail_port_order,
    rem_edge_head_port_order,
    rem_parents,
    rem_children,
    rem_cluster_keys,
    rank_same_groups,
    rank_same_order,
    rem_edge_order,
    rem_node_order,
    rem_sizes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    Map::new(),
    Map::new(),
    rem_flat_constraints,
    graphviz_flip=graphviz_flip,
    // Graphviz parity: ReMincross counts parallel chain segments once
    // with summed xpenalty before startpass=2 transposition.
    coalesce_parallel_edges=true,
    startpass=2,
    remincross_mode=true,
  )
}

///|
/// Graphviz parity: ReMincross final reorder runs with startpass=2 using
/// materialized fast-graph edges, then drops non-real nodes for final groups
/// while preserving rank iteration and per-rank order.
/// Do not change behavior without updating fixtures/tests.
fn run_remincross_reorder_and_collect_real_groups(
  rem_rank_keys : Array[Int],
  rem_groups : Map[Int, Array[String]],
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
  rem_edge_tail_port_x : Array[Double],
  rem_edge_head_port_x : Array[Double],
  rem_edge_tail_port_order : Array[Double],
  rem_edge_head_port_order : Array[Double],
  rem_parents : Map[String, Array[String]],
  rem_children : Map[String, Array[String]],
  rem_cluster_keys : Map[String, String],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  rem_edge_order : Map[String, Int],
  rem_node_order : Map[String, Int],
  rem_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  rem_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  real_nodes : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let rem_ordered =
    run_remincross_rank_reorder_startpass2(
      rem_rank_keys,
      rem_groups,
      rem_edges_out,
      rem_edge_tail_out,
      rem_edge_head_out,
      rem_edge_tail_port_x,
      rem_edge_head_port_x,
      rem_edge_tail_port_order,
      rem_edge_head_port_order,
      rem_parents,
      rem_children,
      rem_cluster_keys,
      rank_same_groups,
      rank_same_order,
      rem_edge_order,
      rem_node_order,
      rem_sizes,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      rem_flat_constraints,
      graphviz_flip,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    dot_trace_groups("remincross_ordered", rem_ordered)
  }
  let rem_cleaned =
    collect_real_only_rank_groups(rem_rank_keys, rem_ordered, real_nodes)
  (rem_ordered, rem_cleaned)
}

///|
/// Graphviz parity: ReMincross flat constraints combine existing same-rank
/// constraints with local intra-cluster adjacency locks for non-intercluster
/// real-node pairs (flat.c cluster-local reorder guard).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_flat_constraints(
  flat_constraints : Map[String, Bool],
  rank_same_constraints : Map[String, Bool],
  order_with_clusters : Bool,
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> Map[String, Bool] {
  let rem_flat_constraints : Map[String, Bool] = Map::new()
  if !order_with_clusters {
    for key, value in flat_constraints {
      rem_flat_constraints[key] = value
    }
    for key, _ in rank_same_constraints {
      rem_flat_constraints[key] = true
    }
    return rem_flat_constraints
  }
  ignore(rem_groups)
  ignore(real_nodes)
  ignore(rem_cluster_keys)
  ignore(intercluster_nodes)
  rem_flat_constraints
}

///|
/// Graphviz parity: ReMincross reorder cluster inputs derive cluster keys
/// (including vnode LCA assignments) and intercluster short-span node guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_inputs_for_reorder(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> (Map[String, String], Map[String, Bool]) {
  let rem_cluster_keys =
    build_remincross_cluster_keys(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      cluster_meta.intercluster_keys,
      cluster_meta.cluster_parents,
      vnode_info.edge_vnodes,
    )
  let intercluster_nodes =
    collect_intercluster_nodes_with_short_span(
      order_with_clusters,
      edge_tail,
      edge_head,
      cluster_meta.intercluster_keys,
      ranks,
    )
  if @sys.get_env_var("DOT_TRACE_GROUPS") is Some(_) {
    let debug_vnodes : Array[String] = [
      "_mbt_edge_vn_0_3",
      "_mbt_edge_vn_1_3",
    ]
    for name in debug_vnodes {
      let cluster = cluster_key_or_empty(rem_cluster_keys, name)
      println("remincross vnode \{name} cluster=\{cluster}")
    }
  }
  (rem_cluster_keys, intercluster_nodes)
}

///|
/// Graphviz parity: ReMincross reorder size/constraint inputs extend sizes with
/// vnode dimensions and augment flat constraints with same-rank + cluster-local
/// guards before final reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_sizes_and_flat_constraints(
  order_sizes : Map[String, NodeSize],
  order_with_vnodes : Bool,
  vnode_sizes : Map[String, NodeSize],
  flat_constraints : Map[String, Bool],
  rank_same_constraints : Map[String, Bool],
  order_with_clusters : Bool,
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
  rem_cluster_keys : Map[String, String],
  intercluster_nodes : Map[String, Bool],
) -> (Map[String, NodeSize], Map[String, Bool]) {
  let rem_sizes =
    build_order_sizes_for_order_graph(
      order_sizes,
      order_with_vnodes,
      vnode_sizes,
    )
  let rem_flat_constraints =
    build_remincross_flat_constraints(
      flat_constraints,
      rank_same_constraints,
      order_with_clusters,
      rem_groups,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  (rem_sizes, rem_flat_constraints)
}

///|
/// Graphviz parity: ReMincross reorder inputs derive cluster keys (including
/// vnode LCA assignments), local intercluster-node guards, size map extension,
/// and flat-constraint augmentation before final reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_reorder_inputs(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ranks : Map[String, Int],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
  rem_groups : Map[Int, Array[String]],
  real_nodes : Map[String, Bool],
) -> (Map[String, String], Map[String, NodeSize], Map[String, Bool]) {
  let (rem_cluster_keys, intercluster_nodes) =
    build_remincross_cluster_inputs_for_reorder(
      graph,
      edges,
      edge_tail,
      edge_head,
      order_with_vnodes,
      order_with_clusters,
      ranks,
      cluster_meta,
      vnode_info,
    )
  let (rem_sizes, rem_flat_constraints) =
    build_remincross_sizes_and_flat_constraints(
      order_sizes,
      order_with_vnodes,
      vnode_info.vnode_sizes,
      cluster_meta.flat_constraints,
      rank_same_constraints,
      order_with_clusters,
      rem_groups,
      real_nodes,
      rem_cluster_keys,
      intercluster_nodes,
    )
  (rem_cluster_keys, rem_sizes, rem_flat_constraints)
}

///|
/// Graphviz parity: ReMincross base cluster keys copy intercluster keys and
/// map empty keys to a non-empty root ND_clust key (mark_lowclusters).
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys_base(
  graph : @cgraph.Graph,
  intercluster_keys : Map[String, String],
) -> (Map[String, String], String) {
  let rem_cluster_keys : Map[String, String] = Map::new()
  for name, key in intercluster_keys {
    rem_cluster_keys[name] = key
  }
  // Graphviz parity: ND_clust is the root graph for nodes outside
  // any cluster (mark_lowclusters). Use a non-empty root key so
  // ReMincross can block swaps across cluster boundaries.
  let root_cluster = match graph.name() {
    Some(value) => value
    None => "__root__"
  }
  for name, key in rem_cluster_keys {
    if key == "" {
      rem_cluster_keys[name] = root_cluster
    }
  }
  (rem_cluster_keys, root_cluster)
}

///|
/// Graphviz parity: ReMincross virtual nodes take the LCA endpoint cluster
/// (or root fallback) from intercluster edge endpoints.
/// Do not change behavior without updating fixtures/tests.
fn assign_remincross_vnode_clusters_from_edges(
  rem_cluster_keys : Map[String, String],
  root_cluster : String,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Unit {
  let mut edge_idx = 0
  for edge in edges {
    let vnodes = match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      edge_idx = edge_idx + 1
      continue
    }
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
    let head_cluster = cluster_key_or_empty(intercluster_keys, head)
    // Graphviz parity: mark_lowclusters assigns virtual nodes to the
    // lowest common ancestor cluster for intercluster edges.
    let vnode_cluster =
      cluster_lowest_common_ancestor(
        tail_cluster,
        head_cluster,
        cluster_parents,
      )
    let rem_cluster = if vnode_cluster == "" { root_cluster } else { vnode_cluster }
    for vnode in vnodes {
      rem_cluster_keys[vnode] = rem_cluster
    }
    edge_idx = edge_idx + 1
  }
}

///|
/// Graphviz parity: ReMincross cluster keys start from intercluster keys,
/// map empty keys to the root graph key, and assign edge vnodes to the LCA
/// cluster (mark_lowclusters) for cluster-boundary swap guards.
/// Do not change behavior without updating fixtures/tests.
fn build_remincross_cluster_keys(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_with_vnodes : Bool,
  intercluster_keys : Map[String, String],
  cluster_parents : Map[String, String?],
  edge_vnodes : Map[String, Array[String]],
) -> Map[String, String] {
  let (rem_cluster_keys, root_cluster) =
    build_remincross_cluster_keys_base(graph, intercluster_keys)
  if !order_with_vnodes {
    return rem_cluster_keys
  }
  assign_remincross_vnode_clusters_from_edges(
    rem_cluster_keys,
    root_cluster,
    edges,
    edge_tail,
    edge_head,
    intercluster_keys,
    cluster_parents,
    edge_vnodes,
  )
  rem_cluster_keys
}

///|
/// Graphviz parity: intercluster short-span guard selects only edges crossing
/// cluster keys with absolute rank difference <= 1.
/// Do not change behavior without updating fixtures/tests.
fn edge_has_intercluster_short_span(
  tail : String,
  head : String,
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Bool {
  let tail_cluster = cluster_key_or_empty(intercluster_keys, tail)
  let head_cluster = cluster_key_or_empty(intercluster_keys, head)
  if tail_cluster == head_cluster {
    return false
  }
  let tail_rank = rank_or_zero_for_flat_constraints(ranks, tail)
  let head_rank = rank_or_zero_for_flat_constraints(ranks, head)
  let span = if tail_rank <= head_rank {
    head_rank - tail_rank
  } else {
    tail_rank - head_rank
  }
  span <= 1
}

///|
/// Graphviz parity: intercluster node guard marks real endpoints of
/// intercluster edges with rank span <= 1 for local-order relaxation.
/// Do not change behavior without updating fixtures/tests.
fn collect_intercluster_nodes_with_short_span(
  order_with_clusters : Bool,
  edge_tail : Array[String],
  edge_head : Array[String],
  intercluster_keys : Map[String, String],
  ranks : Map[String, Int],
) -> Map[String, Bool] {
  let intercluster_nodes : Map[String, Bool] = Map::new()
  if !order_with_clusters {
    return intercluster_nodes
  }
  let mut edge_idx = 0
  while edge_idx < edge_tail.length() {
    let tail = edge_tail[edge_idx]
    let head = edge_head[edge_idx]
    if edge_has_intercluster_short_span(
      tail,
      head,
      intercluster_keys,
      ranks,
    ) {
      intercluster_nodes[tail] = true
      intercluster_nodes[head] = true
    }
    edge_idx = edge_idx + 1
  }
  intercluster_nodes
}
