///|
pub fn cluster_containing_point_or_empty(
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
pub fn path_vnode_clusters(
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
