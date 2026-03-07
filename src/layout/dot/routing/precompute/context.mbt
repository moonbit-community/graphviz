///|
type NodeSize = @dot_shared.NodeSize

///|
pub(all) struct RoutingContext {
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
fn build_order_index(groups : Map[Int, Array[String]]) -> Map[String, Int] {
  let order : Map[String, Int] = Map::new()
  for _rank, names in groups {
    for i in 0..<names.length() {
      order[names[i]] = i
    }
  }
  order
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
/// Graphviz parity: vnode-cluster assignment input keeps edge/vnode and
/// cluster-geometry maps grouped for deterministic containment probing.
priv struct PathVnodeClustersInput {
  edges : Array[@cgraph.Edge]
  edge_vnodes : Map[String, Array[String]]
  vnode_positions : Map[String, @geom.Point]
  cluster_keys : Map[String, String]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
fn build_path_vnode_clusters(
  input : PathVnodeClustersInput,
) -> Map[String, String] {
  let vnode_clusters : Map[String, String] = Map::new()
  for edge in input.edges {
    let key = @edge_identity.edge_vnode_key(edge)
    let vnodes = input.edge_vnodes.get(key).unwrap_or_default()
    if vnodes.length() == 0 {
      continue
    }
    let tail_cluster =
      input.cluster_keys.get(edge.tail().name()).unwrap_or_default()
    let head_cluster =
      input.cluster_keys.get(edge.head().name()).unwrap_or_default()
    for vnode in vnodes {
      let pos = match input.vnode_positions.get(vnode) {
        Some(value) => value
        None => continue
      }
      let mut vnode_cluster =
        cluster_containing_point_or_empty(
          tail_cluster,
          input.cluster_bboxes,
          pos,
        )
      if vnode_cluster == "" {
        vnode_cluster =
          cluster_containing_point_or_empty(
            head_cluster,
            input.cluster_bboxes,
            pos,
          )
      }
      vnode_clusters[vnode] = vnode_cluster
    }
  }
  vnode_clusters
}


///|
/// Graphviz parity: routing-context input keeps pathplan/rank/cluster snapshots
/// and callback dependencies grouped at one pre-routing boundary.
pub(all) struct PrepareRoutingContextInput {
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  ordered_groups : Map[Int, Array[String]]
  x_groups : Map[Int, Array[String]]
  nodesep_pt : Double
  edge_vnodes : Map[String, Array[String]]
  pathplan_sizes : Map[String, NodeSize]
  path_cluster_keys : Map[String, String]
  vnode_sizes : Map[String, NodeSize]
  vnode_positions : Map[String, @geom.Point]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
/// Graphviz parity: routing context aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn prepare_routing_context(
  input : PrepareRoutingContextInput,
) -> RoutingContext {
  let order_index = build_order_index(input.ordered_groups)
  let path_order_index = build_order_index(input.x_groups)
  let path_adjacency =
    @routesplines.build_path_adjacency(
      input.edges,
      input.edge_vnodes,
      input.edge_tail,
      input.edge_head,
    )
  // Graphviz parity: preserve original vnode widths for ND_mval usage.
  let pathplan_vnode_mval_sizes : Map[String, NodeSize] = Map::new()
  for name, size in input.vnode_sizes {
    pathplan_vnode_mval_sizes[name] = size
  }
  let path_vnode_clusters =
    build_path_vnode_clusters(
      {
        edges: input.edges,
        edge_vnodes: input.edge_vnodes,
        vnode_positions: input.vnode_positions,
        cluster_keys: input.path_cluster_keys,
        cluster_bboxes: input.cluster_bboxes,
      },
    )
  let (edge_reversed_by_id, edge_has_label_by_id) =
    collect_parallel_offset_edge_flags(input.edges, input.edge_tail, input.edge_head)
  let parallel_offsets =
    build_edge_parallel_offsets(
      {
        edges: input.edges,
        edge_has_label_by_id,
        ranks: input.ranks,
        nodesep_pt: input.nodesep_pt,
        edge_reversed_by_id,
        cluster_keys: input.path_cluster_keys,
      },
    )
  {
    order_index,
    path_order_index,
    path_adjacency,
    pathplan_sizes: input.pathplan_sizes,
    pathplan_vnode_mval_sizes,
    path_cluster_keys: input.path_cluster_keys,
    path_vnode_clusters,
    parallel_offsets,
    cluster_bboxes: input.cluster_bboxes,
  }
}
