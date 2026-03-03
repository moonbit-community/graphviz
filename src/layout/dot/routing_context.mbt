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
/// Graphviz parity: parallel offsets group by unordered endpoints/ports (set of
/// tail/head), and only for unlabeled edges (class2 merge_chain).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_parallel_offsets(
  edges : Array[@cgraph.Edge],
  edge_has_label_by_id : Map[Int, Bool],
  ranks : Map[String, Int],
  _order_index : Map[String, Int],
  nodesep_pt : Double,
  edge_reversed_by_id : Map[Int, Bool],
  cluster_keys : Map[String, String],
) -> Map[Int, Double] {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_dir_attr : Map[String, String] = Map::new()
  let group_has_mixed_dir_attr : Map[String, Bool] = Map::new()
  let sameport_marked : Map[Int, Bool] = Map::new()
  let edge_by_id : Map[Int, @cgraph.Edge] = Map::new()
  let has_self_edge : Map[String, Bool] = Map::new()
  for edge in edges {
    edge_by_id[edge.id()] = edge
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      has_self_edge[tail] = true
    }
  }
  for edge in edges {
    let has_label = match edge_has_label_by_id.get(edge.id()) {
      Some(value) => value
      None => false
    }
    if has_label {
      continue
    }
    let orig_tail = edge.tail().name()
    let orig_head = edge.head().name()
    if orig_tail == orig_head {
      continue
    }
    let tail_rank = match ranks.get(orig_tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(orig_head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let key =
      @edge_ops.edge_parallel_key(
        orig_tail,
        orig_head,
        edge.tail_port(),
        edge.head_port(),
      )
    let dir_attr = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let mark = @edge_ops.edge_has_sameport_mark(edge)
    sameport_marked[edge.id()] = mark
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_dir_attr.get(key) {
      Some(first_dir) =>
        if first_dir != dir_attr {
          group_has_mixed_dir_attr[key] = true
        }
      None => {
        group_first_dir_attr[key] = dir_attr
        group_has_mixed_dir_attr[key] = false
      }
    }
  }
  let offsets : Map[Int, Double] = Map::new()
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    ids.sort_by((a, b) => {
      let a_mark = match sameport_marked.get(a) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      let b_mark = match sameport_marked.get(b) {
        Some(value) => if value { 1 } else { 0 }
        None => 0
      }
      if a_mark != b_mark {
        b_mark - a_mark
      } else {
        a - b
      }
    })
    let mixed_dir = match group_has_mixed_dir_attr.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_dir {
      let mut left = 0
      let mut right = ids.length()
      while left + 1 < right {
        right = right - 1
        let tmp = ids[left]
        ids[left] = ids[right]
        ids[right] = tmp
        left = left + 1
      }
    }
    // Graphviz parity: for reverse-edge pairs, prefer the tail without a
    // self-loop first. This matches class2/dotsplines slot assignment on NaN.gv.
    if ids.length() == 2 {
      let edge0 = edge_by_id.get(ids[0])
      let edge1 = edge_by_id.get(ids[1])
      match (edge0, edge1) {
        (Some(a), Some(b)) => {
          let a_tail = a.tail().name()
          let a_head = a.head().name()
          let b_tail = b.tail().name()
          let b_head = b.head().name()
          if a_tail == b_head && a_head == b_tail {
            let a_tail_cluster = match cluster_keys.get(a_tail) {
              Some(value) => value
              None => ""
            }
            let a_head_cluster = match cluster_keys.get(a_head) {
              Some(value) => value
              None => ""
            }
            let intercluster =
              a_tail_cluster != a_head_cluster &&
              (a_tail_cluster != "" || a_head_cluster != "")
            let a_tail_has_self = match has_self_edge.get(a_tail) {
              Some(value) => value
              None => false
            }
            let b_tail_has_self = match has_self_edge.get(b_tail) {
              Some(value) => value
              None => false
            }
            // Graphviz parity: reverse-pair slot ordering applies to regular
            // intra-cluster pairs (rowe), but cluster-crossing pairs (clust2)
            // keep cluster-constrained ordering.
            if !intercluster && a_tail_has_self == b_tail_has_self {
              let a_reversed = match edge_reversed_by_id.get(ids[0]) {
                Some(value) => value
                None => false
              }
              let b_reversed = match edge_reversed_by_id.get(ids[1]) {
                Some(value) => value
                None => false
              }
              if !a_reversed && b_reversed {
                let tmp = ids[0]
                ids[0] = ids[1]
                ids[1] = tmp
              }
            }
            if a_tail_has_self && !b_tail_has_self {
              let tmp = ids[0]
              ids[0] = ids[1]
              ids[1] = tmp
            }
          }
        }
        _ => ()
      }
    }
    let count = ids.length()
    let dx = nodesep_pt * Double::from_int(count - 1) / 2.0
    for i in 0..<count {
      let offset = dx - Double::from_int(i) * nodesep_pt
      offsets[ids[i]] = offset
    }
  }
  offsets
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
    build_edge_parallel_offsets(
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
