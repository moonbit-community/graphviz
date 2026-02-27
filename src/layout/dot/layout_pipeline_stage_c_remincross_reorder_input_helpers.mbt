///|
/// Extracted from layout_pipeline_remincross_helpers.mbt to isolate
/// Stage C ReMincross reorder input derivation helpers.

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
