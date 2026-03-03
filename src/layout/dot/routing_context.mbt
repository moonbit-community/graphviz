///|
priv struct RoutingContext {
  order_index : Map[String, Int]
  path_order_index : Map[String, Int]
  path_adjacency : @routesplines.PathAdjacency
  pathplan_sizes : Map[String, NodeSize]
  pathplan_vnode_mval_sizes : Map[String, NodeSize]
  path_cluster_keys : Map[String, String]
  path_vnode_clusters : Map[String, String]
  parallel_offsets : Map[Int, Double]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
/// Graphviz parity: routing context aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn prepare_routing_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
  ranks : Map[String, Int],
  ordered_groups : Map[Int, Array[String]],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  cluster_bboxes : Map[String, @geom.Rect],
) -> RoutingContext {
  let order_index = build_order_index(ordered_groups)
  let path_order_index = build_order_index(x_groups)
  let path_adjacency =
    @routesplines.build_path_adjacency(
      edges,
      vnode_info.edge_vnodes,
      edge_tail,
      edge_head,
    )
  // Graphviz parity: pathplan neighbor widths use ND_mval (self-edge right space).
  let pathplan_sizes =
    apply_self_edge_right_space(
      nodes,
      edges,
      sizes,
      rankdir,
      record_orientation,
    )
  // Graphviz parity: preserve original vnode widths for ND_mval usage.
  let pathplan_vnode_mval_sizes : Map[String, NodeSize] = Map::new()
  for name, size in vnode_info.vnode_sizes {
    pathplan_vnode_mval_sizes[name] = size
  }
  let path_cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    path_cluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let path_vnode_clusters =
    @routing.path_vnode_clusters(
      edges,
      vnode_info.edge_vnodes,
      vnode_positions,
      path_cluster_keys,
      cluster_bboxes,
    )
  let edge_reversed_by_id : Map[Int, Bool] = Map::new()
  let edge_has_label_by_id : Map[Int, Bool] = Map::new()
  for i in 0..<edges.length() {
    let edge = edges[i]
    let (oriented_tail, oriented_head) =
      edge_endpoints_at(
        edge,
        i,
        edge_tail,
        edge_head,
      )
    let reversed = edge_orientation_is_reversed(edge, oriented_tail, oriented_head)
    edge_reversed_by_id[edge.id()] = reversed
    edge_has_label_by_id[edge.id()] = edge_has_label(edge)
  }
  let parallel_offsets =
    @routing.edge_parallel_offsets(
      edges,
      edge_has_label_by_id,
      ranks,
      order_index,
      nodesep_pt,
      edge_reversed_by_id,
      path_cluster_keys,
    )
  {
    order_index,
    path_order_index,
    path_adjacency,
    pathplan_sizes,
    pathplan_vnode_mval_sizes,
    path_cluster_keys,
    path_vnode_clusters,
    parallel_offsets,
    cluster_bboxes,
  }
}
