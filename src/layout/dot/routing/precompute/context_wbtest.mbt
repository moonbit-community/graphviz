///|
test "build_order_index flattens each rank into local order positions" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[2] = ["x"]

  let order = build_order_index(groups)

  assert_eq(order.get("a"), Some(0))
  assert_eq(order.get("b"), Some(1))
  assert_eq(order.get("x"), Some(0))
}

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

///|
test "prepare_routing_context keeps order maps vnode sizes and detected vnode clusters" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["tail", "head"]
  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["head", "tail"]

  let ranks : Map[String, Int] = Map::new()
  ranks["tail"] = 0
  ranks["head"] = 1

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v1"]

  let pathplan_sizes : Map[String, NodeSize] = Map::new()
  pathplan_sizes["tail"] = @node_primitives.node_size_from_points(10.0, 10.0)
  pathplan_sizes["head"] = @node_primitives.node_size_from_points(12.0, 10.0)

  let vnode_sizes : Map[String, NodeSize] = Map::new()
  vnode_sizes["v1"] = @node_primitives.vnode_size_from_widths_with_h(
    3.0, 5.0, 2.0,
  )

  let vnode_positions : Map[String, @geom.Point] = Map::new()
  vnode_positions["v1"] = { x: 2.0, y: 2.0 }

  let path_cluster_keys : Map[String, String] = Map::new()
  path_cluster_keys["tail"] = "cluster_tail"
  path_cluster_keys["head"] = "cluster_head"

  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  cluster_bboxes["cluster_tail"] = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }
  cluster_bboxes["cluster_head"] = { llx: 20.0, lly: 0.0, urx: 30.0, ury: 10.0 }

  let context = prepare_routing_context({
    edges: [edge],
    edge_tail: ["tail"],
    edge_head: ["head"],
    ranks,
    ordered_groups,
    x_groups,
    nodesep_pt: 12.0,
    edge_vnodes,
    pathplan_sizes,
    path_cluster_keys,
    vnode_sizes,
    vnode_positions,
    cluster_bboxes,
  })

  assert_eq(context.order_index.get("tail"), Some(0))
  assert_eq(context.order_index.get("head"), Some(1))
  assert_eq(context.path_order_index.get("head"), Some(0))
  assert_eq(context.path_order_index.get("tail"), Some(1))
  assert_eq(context.path_vnode_clusters.get("v1"), Some("cluster_tail"))
  assert_eq(
    context.pathplan_vnode_mval_sizes.get("v1").map(size => size.left_pt),
    Some(3.0),
  )
  assert_eq(
    context.pathplan_vnode_mval_sizes.get("v1").map(size => size.right_pt),
    Some(5.0),
  )
  assert_eq(
    context.cluster_bboxes.get("cluster_tail"),
    Some({ llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }),
  )
}
