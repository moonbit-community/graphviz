///|
/// Stage C Phase C3 split: clustered local-replay context and dispatch builders.

///|
/// Graphviz parity: apply cluster-local mincross ordering before ReMincross
/// (mincross_clust + cluster.c). Do not change behavior without updating fixtures/tests.
priv struct ClusterLocalRankReplayContext {
  graph : @cgraph.Graph
  cluster_meta : ClusterMetadata
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  ranks : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  vnode_info : @routing.EdgeVnodeInfo
  order_with_vnodes : Bool
}

///|
/// Graphviz parity: root mincross output is replayed into clustered
/// build_ranks using unmapped order-edge snapshots before local cluster pass.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_local_rank_replay_context(
  dispatch_context : ClusteredDispatchContext,
  reorder_context : @ordering.OrderReorderContext,
  materialized : @ordering.OrderMaterializationData,
  order_sizes_out : Map[String, NodeSize],
) -> ClusterLocalRankReplayContext {
  let runtime_context = dispatch_context.runtime_context
  {
    graph: dispatch_context.graph,
    cluster_meta: dispatch_context.cluster_meta,
    node_order: reorder_context.order_node_order,
    order_edges: materialized.order_edges_out_unmapped,
    order_edge_tail: materialized.order_edge_tail_out_unmapped,
    order_edge_head: materialized.order_edge_head_out_unmapped,
    order_edge_tail_port_x: materialized.order_edge_tail_port_x_unmapped,
    order_edge_head_port_x: materialized.order_edge_head_port_x_unmapped,
    order_edge_tail_port_order: materialized.order_edge_tail_port_order_unmapped,
    order_edge_head_port_order: materialized.order_edge_head_port_order_unmapped,
    graphviz_out_neighbors: materialized.graphviz_out_neighbors,
    graphviz_in_neighbors: materialized.graphviz_in_neighbors,
    ranks: dispatch_context.ranks,
    order_sizes: order_sizes_out,
    nodesep_pt: dispatch_context.nodesep_pt,
    has_edge_labels: dispatch_context.has_edge_labels,
    port_order_positions: dispatch_context.port_order_positions,
    port_order_contrib: dispatch_context.port_order_contrib,
    vnode_info: runtime_context.vnode_info,
    order_with_vnodes: dispatch_context.reorder_setup.order_with_vnodes,
  }
}

///|
/// Graphviz parity: local replay fixed-rank map overlays vnode ranks on top of
/// base node ranks before any per-cluster reorder calls.
fn build_cluster_replay_fixed_ranks(
  replay_context : ClusterLocalRankReplayContext,
) -> Map[String, Int] {
  let fixed_ranks : Map[String, Int] = Map::new()
  for name, rank in replay_context.ranks {
    fixed_ranks[name] = rank
  }
  for name, rank in replay_context.vnode_info.vnode_ranks {
    fixed_ranks[name] = rank
  }
  fixed_ranks
}

///|
/// Graphviz parity: local replay neighbor sources preserve order-graph ND_out/
/// ND_in and append raw AGSEQ traversal maps for median fallback.
fn build_cluster_replay_neighbor_sources(
  replay_context : ClusterLocalRankReplayContext,
) -> ClusterLocalNeighborSources {
  // Graphviz parity: cluster-local ND_out/ND_in maps keep raw graph
  // tail/head AGSEQ replay order for startpass=2 median anchors.
  let raw_graphviz_neighbors = build_raw_graphviz_neighbor_maps(replay_context.graph)
  {
    source_out_neighbors: replay_context.graphviz_out_neighbors,
    source_in_neighbors: replay_context.graphviz_in_neighbors,
    raw_out_neighbors: raw_graphviz_neighbors.out_neighbors,
    raw_in_neighbors: raw_graphviz_neighbors.in_neighbors,
  }
}

///|
/// Graphviz parity: local replay dispatch context keeps one immutable payload
/// shared by all per-cluster reorder calls in traversal order.
fn build_cluster_replay_dispatch_context(
  replay_context : ClusterLocalRankReplayContext,
  neighbor_sources : ClusterLocalNeighborSources,
  fixed_ranks : Map[String, Int],
) -> ClusterLocalReorderDispatchContext {
  {
    node_order: replay_context.node_order,
    order_edges: replay_context.order_edges,
    order_edge_tail: replay_context.order_edge_tail,
    order_edge_head: replay_context.order_edge_head,
    order_edge_tail_port_x: replay_context.order_edge_tail_port_x,
    order_edge_head_port_x: replay_context.order_edge_head_port_x,
    order_edge_tail_port_order: replay_context.order_edge_tail_port_order,
    order_edge_head_port_order: replay_context.order_edge_head_port_order,
    neighbor_sources,
    order_sizes: replay_context.order_sizes,
    nodesep_pt: replay_context.nodesep_pt,
    has_edge_labels: replay_context.has_edge_labels,
    port_order_positions: replay_context.port_order_positions,
    port_order_contrib: replay_context.port_order_contrib,
    cluster_meta: replay_context.cluster_meta,
    vnode_info: replay_context.vnode_info,
    fixed_ranks,
    order_with_vnodes: replay_context.order_with_vnodes,
  }
}
