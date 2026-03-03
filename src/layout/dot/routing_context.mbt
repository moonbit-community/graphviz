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
fn cluster_containing_point_or_empty(
  cluster_name : String,
  cluster_bboxes : Map[String, @geom.Rect],
  pos : @geom.Point,
) -> String {
  if cluster_name == "" {
    return ""
  }
  match cluster_bboxes.get(cluster_name) {
    Some(rect) =>
      if pos.x >= rect.llx && pos.x <= rect.urx &&
        pos.y >= rect.lly && pos.y <= rect.ury {
        cluster_name
      } else {
        ""
      }
    None => ""
  }
}

///|
fn build_path_vnode_clusters(
  edges : Array[@cgraph.Edge],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
  cluster_keys : Map[String, String],
  cluster_bboxes : Map[String, @geom.Rect],
) -> Map[String, String] {
  let vnode_clusters : Map[String, String] = Map::new()
  for edge in edges {
    let key = @dot_shared.edge_vnode_key(edge)
    let vnodes = edge_vnodes.get(key).unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let tail_cluster = cluster_keys.get(edge.tail().name()).unwrap_or_default()
    let head_cluster = cluster_keys.get(edge.head().name()).unwrap_or_default()
    for vnode in vnodes {
      let pos = match vnode_positions.get(vnode) {
        Some(value) => value
        None => continue
      }
      let mut vnode_cluster =
        cluster_containing_point_or_empty(
          tail_cluster,
          cluster_bboxes,
          pos,
        )
      if vnode_cluster == "" {
        vnode_cluster =
          cluster_containing_point_or_empty(
            head_cluster,
            cluster_bboxes,
            pos,
          )
      }
      vnode_clusters[vnode] = vnode_cluster
    }
  }
  vnode_clusters
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
    build_path_vnode_clusters(
      edges,
      vnode_info.edge_vnodes,
      vnode_positions,
      path_cluster_keys,
      cluster_bboxes,
    )
  let (edge_reversed_by_id, edge_has_label_by_id) =
    collect_parallel_offset_edge_flags(edges, edge_tail, edge_head)
  let parallel_offsets =
    build_edge_parallel_offsets(
      edges,
      edge_has_label_by_id,
      ranks,
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
