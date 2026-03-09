///|
test "cluster_containing_point_or_empty requires a named cluster and in-bounds point" {
  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  cluster_bboxes["cluster0"] = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 20.0 }

  assert_eq(
    cluster_containing_point_or_empty("cluster0", cluster_bboxes, {
      x: 5.0,
      y: 6.0,
    }),
    "cluster0",
  )
  assert_eq(
    cluster_containing_point_or_empty("cluster0", cluster_bboxes, {
      x: -1.0,
      y: 6.0,
    }),
    "",
  )
  assert_eq(
    cluster_containing_point_or_empty("", cluster_bboxes, { x: 5.0, y: 6.0 }),
    "",
  )
}

///|
test "build_path_vnode_clusters prefers tail cluster then falls back to head cluster" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = [
    "v_tail", "v_head", "v_none",
  ]

  let vnode_positions : Map[String, @geom.Point] = Map::new()
  vnode_positions["v_tail"] = { x: 2.0, y: 2.0 }
  vnode_positions["v_head"] = { x: 22.0, y: 2.0 }
  vnode_positions["v_none"] = { x: 40.0, y: 2.0 }

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["tail"] = "cluster_tail"
  cluster_keys["head"] = "cluster_head"

  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  cluster_bboxes["cluster_tail"] = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  cluster_bboxes["cluster_head"] = { llx: 20.0, lly: 0.0, urx: 30.0, ury: 10.0 }

  let vnode_clusters = build_path_vnode_clusters({
    edges: [edge],
    edge_vnodes,
    vnode_positions,
    cluster_keys,
    cluster_bboxes,
  })

  assert_eq(vnode_clusters.get("v_tail"), Some("cluster_tail"))
  assert_eq(vnode_clusters.get("v_head"), Some("cluster_head"))
  assert_eq(vnode_clusters.get("v_none"), Some(""))
}
