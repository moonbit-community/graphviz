///|
test "dedupe_polyline_points removes consecutive duplicates" {
  let points : Array[@geom.Point] = [
    { x: 0.0, y: 0.0 },
    { x: 0.0, y: 0.0 },
    { x: 1.0, y: 0.0 },
    { x: 1.0, y: 0.0 },
    { x: 1.0, y: 2.0 },
  ]
  let deduped = dedupe_polyline_points(points)
  assert_eq(deduped.length(), 3)
  assert_eq(deduped[0], { x: 0.0, y: 0.0 })
  assert_eq(deduped[1], { x: 1.0, y: 0.0 })
  assert_eq(deduped[2], { x: 1.0, y: 2.0 })
}

///|
test "beginpath/endpath nudges follow side masks" {
  let base_box : @geom.Rect = { llx: -5.0, lly: -5.0, urx: 5.0, ury: 5.0 }
  let node_pos : @geom.Point = { x: 0.0, y: 0.0 }
  let node_size = @node_primitives.node_size_from_points(10.0, 10.0)

  let tail_result = beginpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: 0.0, y: 0.0 },
    SIDE_BOTTOM,
    false,
    10.0,
  )
  assert_eq(tail_result.boxes.length(), 1)
  assert_eq(tail_result.endpoint, { x: 0.0, y: -1.0 })

  let tail_top_result = beginpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: -1.0, y: 5.0 },
    SIDE_TOP,
    false,
    10.0,
  )
  assert_eq(tail_top_result.boxes.length(), 2)
  assert_eq(tail_top_result.endpoint, { x: -1.0, y: 6.0 })

  let head_result = endpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: 0.0, y: 0.0 },
    SIDE_TOP,
    false,
    10.0,
  )
  assert_eq(head_result.boxes.length(), 1)
  assert_eq(head_result.endpoint, { x: 0.0, y: 1.0 })

  let head_bottom_result = endpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: -1.0, y: -5.0 },
    SIDE_BOTTOM,
    false,
    10.0,
  )
  assert_eq(head_bottom_result.boxes.length(), 2)
  assert_eq(head_bottom_result.endpoint, { x: -1.0, y: -6.0 })
}

///|
test "build_path_adjacency dedupes parallel edges and expands vnode chains" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let direct0 = graph.edge(a, b)
  let direct1 = graph.edge(a, b)
  let chained = graph.edge(b, c)

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(chained)] = ["v1", "v2"]

  let adjacency = build_path_adjacency(
    [direct0, direct1, chained],
    edge_vnodes,
    [],
    [],
  )

  assert_eq(adjacency.out_edges.get("a").unwrap_or([]), ["b"])
  assert_eq(adjacency.out_edges.get("b").unwrap_or([]), ["v1"])
  assert_eq(adjacency.out_edges.get("v1").unwrap_or([]), ["v2"])
  assert_eq(adjacency.out_edges.get("v2").unwrap_or([]), ["c"])
  assert_eq(adjacency.in_edges.get("b").unwrap_or([]), ["a"])
  assert_eq(adjacency.in_edges.get("v1").unwrap_or([]), ["b"])
  assert_eq(adjacency.in_edges.get("v2").unwrap_or([]), ["v1"])
  assert_eq(adjacency.in_edges.get("c").unwrap_or([]), ["v2"])
}

///|
test "build_path_adjacency uses overridden tail and head order" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  let adjacency = build_path_adjacency([edge], Map::new(), ["b"], ["a"])

  assert_eq(adjacency.out_edges.get("b").unwrap_or([]), ["a"])
  assert_eq(adjacency.in_edges.get("a").unwrap_or([]), ["b"])
  guard adjacency.out_edges.get("a") is None else {
    fail("expected overridden tail/head to suppress original direction")
  }
}

///|
test "pathplan_bounds merges vnode positions and expands each rank by route width" {
  let positions : Map[String, @geom.Point] = Map::new()
  positions["a"] = { x: 10.0, y: 0.0 }
  positions["b"] = { x: 40.0, y: 0.0 }

  let vnode_positions : Map[String, @geom.Point] = Map::new()
  vnode_positions["v"] = { x: -20.0, y: 0.0 }

  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths(2.0, 4.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths(5.0, 1.0)

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["v"] = @node_primitives.vnode_size_from_widths(3.0, 7.0)

  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  x_groups[1] = ["v"]

  let bounds = pathplan_bounds(positions, vnode_positions, sizes, vnode_sizes, x_groups)
  assert_eq(bounds.left, -39.0)
  assert_eq(bounds.right, 73.0)
}

///|
test "pathplan_bounds returns zero bounds for empty rank groups" {
  let bounds = pathplan_bounds(Map::new(), Map::new(), Map::new(), Map::new(), Map::new())
  assert_eq(bounds.left, 0.0)
  assert_eq(bounds.right, 0.0)
}

///|
test "limit_boxes_for_spline collapses horizontal splines to one x lane" {
  let boxes : Array[@geom.Rect] = [
    { llx: -3.0, lly: 0.0, urx: -1.0, ury: 4.0 },
    { llx: 2.0, lly: 0.0, urx: 6.0, ury: 4.0 },
  ]
  let spline_points : Array[@geom.Point] = [
    { x: 5.0, y: 1.0 },
    { x: 9.0, y: 1.0 },
  ]

  let limited = limit_boxes_for_spline(boxes, spline_points)

  assert_eq(limited.length(), 2)
  for box in limited {
    assert_eq(box.llx, 5.0)
    assert_eq(box.urx, 5.0)
  }
}

///|
test "limit_boxes_for_spline falls back to polyline when spline sampling misses all boxes" {
  let boxes : Array[@geom.Rect] = [
    { llx: 0.0, lly: 0.0, urx: 1.0, ury: 10.0 },
    { llx: 2.0, lly: 0.0, urx: 3.0, ury: 10.0 },
  ]
  let spline_points : Array[@geom.Point] = [
    { x: 0.0, y: 0.0 },
    { x: 3.0, y: 4.0 },
    { x: 8.0, y: 1.0 },
  ]
  let fallback_polyline : Array[@geom.Point] = [
    { x: 0.0, y: 5.0 },
    { x: 10.0, y: 5.0 },
  ]

  let limited =
    limit_boxes_for_spline(boxes, spline_points, fallback_polyline=fallback_polyline)

  assert_eq(limited.length(), 2)
  for box in limited {
    assert_eq(box.llx, 0.0)
    assert_eq(box.urx, 10.0)
  }
}
