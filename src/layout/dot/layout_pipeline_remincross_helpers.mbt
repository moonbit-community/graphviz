///|
/// Extracted from layout_pipeline_helpers.mbt to keep clustered ReMincross
/// and rematerialization helpers isolated from non-cluster order flow.

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
      let pen = edge_xpenalty(rem_edges_out[idx])
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
/// Debug trace: dump selected ReMincross per-tail edge lists when
/// DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_order_edges_by_tail(
  rem_order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  match rem_order_edges_by_tail.get("arbiter_vadam") {
    Some(list) => {
      let mut idx = 0
      while idx < list.length() {
        let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
        println("remincross arbiter edge \{idx}: \{t} -> \{h}")
        idx = idx + 1
      }
    }
    None => ()
  }
  let debug_tails : Array[String] = ["front_end_jz", "others"]
  for name in debug_tails {
    match rem_order_edges_by_tail.get(name) {
      Some(list) => {
        let mut idx = 0
        while idx < list.length() {
          let (t, h, _pen, _c, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) = list[idx]
          println("remincross out \{name} \{idx}: \{t} -> \{h}")
          idx = idx + 1
        }
      }
      None => ()
    }
  }
}

///|
/// Debug trace: dump materialized ReMincross edges (high-pen and selected
/// endpoints) when DOT_TRACE_GROUPS is enabled (diagnostic only).
fn trace_remincross_materialized_edges(
  rem_edges_out : Array[@cgraph.Edge],
  rem_edge_tail_out : Array[String],
  rem_edge_head_out : Array[String],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_GROUPS") is None {
    return
  }
  let mut idx = 0
  while idx < rem_edges_out.length() {
    let edge = rem_edges_out[idx]
    let pen = edge_xpenalty(edge)
    if pen >= CL_CROSS {
      let tail = rem_edge_tail_out[idx]
      let head = rem_edge_head_out[idx]
      println("remincross high-pen edge \{tail} -> \{head} pen=\{pen}")
    }
    idx = idx + 1
  }
  let mut edge_idx = 0
  while edge_idx < rem_edge_tail_out.length() {
    let tail = rem_edge_tail_out[edge_idx]
    let head = rem_edge_head_out[edge_idx]
    if tail == "z_req" || tail == "z_req1" || head == "z_req" ||
      head == "z_req1" {
      println("remincross edge \{edge_idx}: \{tail} -> \{head}")
    }
    edge_idx = edge_idx + 1
  }
}

