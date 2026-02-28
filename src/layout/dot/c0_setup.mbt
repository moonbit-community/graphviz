///|
/// Stage C Phase C0 split: ordering setup-stage
/// type definitions for reorder/materialize preparation.

///|
/// Stage C Phase C0 split: ordering base/runtime
/// context types for pre-class2 setup derivation.

///|
priv struct OrderingBaseContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
}

///|
priv struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
  vnode_count : Int
}

///|
priv struct OrderingReorderSetup {
  ordering_groups_base : Map[Int, Array[String]]
  base_order_index : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  graphviz_flip : Bool
  flat_rank_constraints : Map[String, Bool]
  class2_data : OrderingClass2Data
  gdnlist_order : Array[String]
  vnode_order_keys_for_ordering : Map[String, Double]
}

///|
priv struct OrderingDispatchSetup {
  edge_port_data : OrderingEdgePortData
  reorder_setup : OrderingReorderSetup
  nlist_order : Array[String]
  vnode_creation_order : Array[String]
  gdnlist_order : Array[String]
}


///|
/// Stage C Phase C0 split: ordering setup context
/// and dispatch preparation helpers.

///|
/// Graphviz parity: ordering pre-pass collects real-node maps, edge cluster
/// ownership, vnode chains, and local cluster/port constraints before class2.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_base_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingBaseContext {
  let real_nodes : Map[String, Bool] = Map::new()
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    let name = node.name()
    real_nodes[name] = true
    existing_names[name] = true
  }
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_meta.cluster_parents,
  )
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = @dot_shared.port_is_explicit(edge.tail_port()) ||
      @dot_shared.port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  let local_cluster_order = build_local_cluster_order(
    nodes,
    cluster_meta.intercluster_keys,
    ranks,
    node_order,
  )
  let rank_same_constraints = build_rank_same_constraints(
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    node_order,
    port_edge_nodes,
    ranks,
  )
  {
    real_nodes,
    edge_cluster_keys,
    vnode_info,
    port_edge_nodes,
    local_cluster_order,
    rank_same_constraints,
  }
}

///|
/// Graphviz parity: ordering runtime prep keeps vnode tail-constraint derivation
/// in the same position as Graphviz ordering setup, even when only used for
/// parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context_with_tail_constraints(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  let base_context =
    build_ordering_base_context(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      ranks,
      node_order,
      nodesep_pt,
      rankdir,
      cluster_meta,
    )
  let runtime_context =
    {
      real_nodes: base_context.real_nodes,
      edge_cluster_keys: base_context.edge_cluster_keys,
      vnode_info: base_context.vnode_info,
      port_edge_nodes: base_context.port_edge_nodes,
      local_cluster_order: base_context.local_cluster_order,
      rank_same_constraints: base_context.rank_same_constraints,
      vnode_count: base_context.vnode_info.vnode_ranks.length(),
    }
  // Graphviz parity: probe vnode tail constraints in setup order even though
  // the result is diagnostic-only.
  let _ =
    if runtime_context.vnode_count > 0 {
      build_vnode_tail_constraints(runtime_context.vnode_info.vnodes_by_rank, edge_tail)
    } else {
      Map::new()
    }
  runtime_context
}

///|
/// Graphviz parity: reorder setup derives class2 data, GD_nlist order, and
/// vnode ordering keys in Graphviz class2->decompose->vnode-key sequence.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_and_vnode_keys_for_reorder_setup(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  vnode_count : Int,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
) -> (OrderingClass2Data, Array[String], Map[String, Double]) {
  let class2_data =
    build_ordering_class2_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      vnode_info.edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      cluster_meta,
      flat_rank_constraints,
      graphviz_flip,
    )
  // Graphviz parity: GD_nlist follows decompose DFS order over fast graph edges.
  // Do not change behavior without updating fixtures/tests.
  let gdnlist_order =
    if @sys.get_env_var("DOT_DEBUG_GDNLIST_FROM_CREATION_REV") is Some(_) ||
      (graphviz_flip && cluster_meta.cluster_order.length() > 1) {
      build_reverse_creation_order_from_nlist(class2_data.creation_order)
    } else {
      class2_data.nlist_order
    }
  let nlist_order_index : Map[String, Int] = Map::new()
  let mut nlist_idx = 0
  for name in class2_data.nlist_order {
    nlist_order_index[name] = nlist_idx
    nlist_idx = nlist_idx + 1
  }
  let vnode_order_keys_for_ordering =
    build_vnode_order_keys_for_ordering_stage(
      vnode_count,
      cluster_meta,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      base_order_index,
      vnode_info,
      ordering_groups_base,
      nlist_order_index,
    )
  (class2_data, gdnlist_order, vnode_order_keys_for_ordering)
}


///|
/// Graphviz parity: reorder setup derives rank-same-adjusted groups, order
/// indices, cluster/vnode flags, flip direction, and flat-rank constraints.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_reorder_flags_and_constraints(
  groups : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  vnode_count : Int,
  rankdir : RankDir,
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> (
  Map[Int, Array[String]],
  Map[String, Int],
  Bool,
  Bool,
  Bool,
  Map[String, Bool],
) {
  let ordering_groups_base = apply_rank_same_order_with_port_override(
    groups,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    node_order,
    port_edge_nodes,
  )
  let base_order_index = build_order_index(ordering_groups_base)
  let order_with_vnodes = vnode_count > 0
  let order_with_clusters =
    cluster_meta.has_clusters && cluster_meta.cluster_min_rank.length() > 0
  let graphviz_flip = rankdir == RankDir::RL || rankdir == RankDir::LR
  let flat_rank_constraints =
    build_flat_rank_constraints(
      edge_tail,
      edge_head,
      ranks,
    )
  (
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: reorder setup preserves class2/GD_nlist prep order before
/// clustered/nonclustered mincross paths diverge.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_reorder_setup(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
  vnode_count : Int,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
) -> OrderingReorderSetup {
  let (
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip,
    flat_rank_constraints,
  ) =
    build_ordering_reorder_flags_and_constraints(
      groups,
      cluster_meta,
      node_order,
      port_edge_nodes,
      vnode_count,
      rankdir,
      edge_tail,
      edge_head,
      ranks,
    )
  let (class2_data, gdnlist_order, vnode_order_keys_for_ordering) =
    build_ordering_class2_and_vnode_keys_for_reorder_setup(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      vnode_count,
      cluster_meta,
      vnode_info,
      ordering_groups_base,
      base_order_index,
      order_with_vnodes,
      order_with_clusters,
      flat_rank_constraints,
      graphviz_flip,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
    )
  {
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    graphviz_flip,
    flat_rank_constraints,
    class2_data,
    gdnlist_order,
    vnode_order_keys_for_ordering,
  }
}

///|
/// Graphviz parity: dispatch setup keeps edge-port extraction and reorder setup
/// sequence identical to Graphviz class2/mincross preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  port_edge_nodes : Map[String, Bool],
  vnode_count : Int,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
) -> OrderingDispatchSetup {
  let edge_port_data =
    build_ordering_edge_port_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  let reorder_setup =
    build_ordering_reorder_setup(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      groups,
      node_order,
      port_edge_nodes,
      vnode_count,
      rankdir,
      cluster_meta,
      vnode_info,
      edge_port_data.edge_tail_port_x,
      edge_port_data.edge_head_port_x,
      edge_port_data.edge_tail_port_order,
      edge_port_data.edge_head_port_order,
    )
  let class2_data = reorder_setup.class2_data
  {
    edge_port_data,
    reorder_setup,
    nlist_order: class2_data.nlist_order,
    vnode_creation_order: class2_data.vnode_creation_order,
    gdnlist_order: reorder_setup.gdnlist_order,
  }
}
