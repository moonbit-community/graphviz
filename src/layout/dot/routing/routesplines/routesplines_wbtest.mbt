///|
fn assert_points_eq(
  actual : Array[@geom.Point],
  expected : Array[@geom.Point],
) -> Unit raise {
  if actual.length() != expected.length() {
    fail("expected point count \{expected.length()} got \{actual.length()}")
  }
  for i in 0..<expected.length() {
    assert_eq(actual[i], expected[i])
  }
}

///|
test "boxes_to_polygon_points filters degenerate boxes before polygon build" {
  let polygon = boxes_to_polygon_points([
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 2.0 },
    { llx: 1.0, lly: 2.0, urx: 5.0, ury: 6.0 },
    { llx: 2.0, lly: 6.0, urx: 4.0, ury: 6.0 },
  ])

  assert_points_eq(polygon, [
    { x: 1.0, y: 6.0 },
    { x: 1.0, y: 2.0 },
    { x: 5.0, y: 2.0 },
    { x: 5.0, y: 6.0 },
  ])
}

///|
test "boxes_to_polygon_points preserves descending corridors after flip normalization" {
  let polygon = boxes_to_polygon_points([
    { llx: 0.0, lly: 10.0, urx: 4.0, ury: 14.0 },
    { llx: 0.0, lly: 6.0, urx: 8.0, ury: 10.0 },
    { llx: 2.0, lly: 2.0, urx: 8.0, ury: 6.0 },
  ])

  assert_points_eq(polygon, [
    { x: 4.0, y: 14.0 },
    { x: 4.0, y: 10.0 },
    { x: 8.0, y: 10.0 },
    { x: 8.0, y: 6.0 },
    { x: 8.0, y: 6.0 },
    { x: 8.0, y: 2.0 },
    { x: 2.0, y: 2.0 },
    { x: 2.0, y: 6.0 },
    { x: 0.0, y: 6.0 },
    { x: 0.0, y: 10.0 },
    { x: 0.0, y: 10.0 },
    { x: 0.0, y: 14.0 },
  ])
}

///|
test "route_pathplan_from_boxes clamps endpoints into first and last boxes" {
  let boxes : Array[@geom.Rect] = [
    { llx: 0.0, lly: 4.0, urx: 4.0, ury: 8.0 },
    { llx: 0.0, lly: 0.0, urx: 4.0, ury: 4.0 },
  ]

  let route = match
    route_pathplan_from_boxes(boxes, { x: -2.0, y: 10.0 }, { x: 10.0, y: -2.0 }) {
    Some(value) => value
    None => fail("expected pathplan route")
  }

  assert_eq(route.points[0], { x: 0.0, y: 8.0 })
  assert_eq(route.points[route.points.length() - 1], { x: 4.0, y: 0.0 })
  assert_true(route.polygon.length() >= 4)
}

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

  let bounds = pathplan_bounds(
    positions, vnode_positions, sizes, vnode_sizes, x_groups,
  )
  assert_eq(bounds.left, -39.0)
  assert_eq(bounds.right, 73.0)
}

///|
test "pathplan_bounds returns zero bounds for empty rank groups" {
  let bounds = pathplan_bounds(
    Map::new(),
    Map::new(),
    Map::new(),
    Map::new(),
    Map::new(),
  )
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

  let limited = limit_boxes_for_spline(boxes, spline_points, fallback_polyline~)

  assert_eq(limited.length(), 2)
  for box in limited {
    assert_eq(box.llx, 0.0)
    assert_eq(box.urx, 10.0)
  }
}

///|
test "route_pathplan_from_boxes matches Graphviz simple straight corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: -32.0, lly: 82.0, urx: 110.23527602606173, ury: 108.0 },
    { llx: -32.0, lly: 74.0, urx: 110.23527602606173, ury: 82.0 },
    { llx: -32.0, lly: 26.0, urx: 110.23527602606173, ury: 74.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 47.0, y: 107.0 }, { x: 47.0, y: 27.0 }) {
    Some(value) => value
    None => fail("expected route for straight corridor fixture")
  }

  assert_points_eq(route.polygon, [
    { x: 110.23527602606173, y: 108.0 },
    { x: 110.23527602606173, y: 82.0 },
    { x: 110.23527602606173, y: 82.0 },
    { x: 110.23527602606173, y: 74.0 },
    { x: 110.23527602606173, y: 74.0 },
    { x: 110.23527602606173, y: 26.0 },
    { x: -32.0, y: 26.0 },
    { x: -32.0, y: 74.0 },
    { x: -32.0, y: 74.0 },
    { x: -32.0, y: 82.0 },
    { x: -32.0, y: 82.0 },
    { x: -32.0, y: 108.0 },
  ])
  assert_points_eq(route.points, [
    { x: 47.0, y: 107.0 },
    { x: 47.0, y: 27.0 },
  ])
}

///|
test "route_pathplan_from_boxes matches Graphviz long straight corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: 511.0, lly: 457.0, urx: 1434.35693359375, ury: 483.5 },
    { llx: -240.0, lly: 447.0, urx: 1434.35693359375, ury: 457.0 },
    { llx: -240.0, lly: 446.0, urx: 1434.35693359375, ury: 447.0 },
    { llx: -240.0, lly: 428.0, urx: 1434.35693359375, ury: 446.0 },
    { llx: -240.0, lly: 409.5, urx: 1434.35693359375, ury: 428.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 824.0, y: 482.5 }, { x: 824.0, y: 410.5 }) {
    Some(value) => value
    None => fail("expected route for long straight corridor fixture")
  }

  assert_points_eq(route.polygon, [
    { x: 1434.35693359375, y: 483.5 },
    { x: 1434.35693359375, y: 457.0 },
    { x: 1434.35693359375, y: 457.0 },
    { x: 1434.35693359375, y: 447.0 },
    { x: 1434.35693359375, y: 447.0 },
    { x: 1434.35693359375, y: 446.0 },
    { x: 1434.35693359375, y: 446.0 },
    { x: 1434.35693359375, y: 428.0 },
    { x: 1434.35693359375, y: 428.0 },
    { x: 1434.35693359375, y: 409.5 },
    { x: -240.0, y: 409.5 },
    { x: -240.0, y: 428.0 },
    { x: -240.0, y: 428.0 },
    { x: -240.0, y: 446.0 },
    { x: -240.0, y: 446.0 },
    { x: -240.0, y: 447.0 },
    { x: -240.0, y: 447.0 },
    { x: -240.0, y: 457.0 },
    { x: 511.0, y: 457.0 },
    { x: 511.0, y: 483.5 },
  ])
  assert_points_eq(route.points, [
    { x: 824.0, y: 482.5 },
    { x: 824.0, y: 410.5 },
  ])
}

///|
test "route_pathplan_from_boxes matches Graphviz single-bend corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: -240.0, lly: 248.0, urx: 1434.35693359375, ury: 266.5 },
    { llx: -240.0, lly: 230.0, urx: 1434.35693359375, ury: 248.0 },
    { llx: -240.0, lly: 216.0, urx: 788.896484375, ury: 230.0 },
    { llx: -240.0, lly: 198.0, urx: 1434.35693359375, ury: 216.0 },
    { llx: -240.0, lly: 179.5, urx: 833.0, ury: 198.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 824.0, y: 265.5 }, { x: 780.0, y: 180.5 }) {
    Some(value) => value
    None => fail("expected route for single-bend fixture")
  }

  assert_points_eq(route.polygon, [
    { x: 1434.35693359375, y: 266.5 },
    { x: 1434.35693359375, y: 248.0 },
    { x: 1434.35693359375, y: 248.0 },
    { x: 1434.35693359375, y: 230.0 },
    { x: 788.896484375, y: 230.0 },
    { x: 788.896484375, y: 216.0 },
    { x: 1434.35693359375, y: 216.0 },
    { x: 1434.35693359375, y: 198.0 },
    { x: 833.0, y: 198.0 },
    { x: 833.0, y: 179.5 },
    { x: -240.0, y: 179.5 },
    { x: -240.0, y: 198.0 },
    { x: -240.0, y: 198.0 },
    { x: -240.0, y: 216.0 },
    { x: -240.0, y: 216.0 },
    { x: -240.0, y: 230.0 },
    { x: -240.0, y: 230.0 },
    { x: -240.0, y: 248.0 },
    { x: -240.0, y: 248.0 },
    { x: -240.0, y: 266.5 },
  ])
  assert_points_eq(route.points, [
    { x: 824.0, y: 265.5 },
    { x: 788.896484375, y: 230.0 },
    { x: 780.0, y: 180.5 },
  ])
}

///|
test "route_pathplan_from_boxes matches Graphviz multi-bend corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: 537.0, lly: 699.0, urx: 631.0, ury: 725.5 },
    { llx: -240.0, lly: 689.0, urx: 1434.35693359375, ury: 699.0 },
    { llx: 595.0, lly: 675.0, urx: 832.5771484375, ury: 689.0 },
    { llx: -240.0, lly: 667.0, urx: 1434.35693359375, ury: 675.0 },
    { llx: 746.0, lly: 590.5, urx: 908.0, ury: 667.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 586.0, y: 724.5 }, { x: 823.0, y: 591.5 }) {
    Some(value) => value
    None => fail("expected route for multi-bend fixture")
  }

  assert_points_eq(route.points, [
    { x: 586.0, y: 724.5 },
    { x: 631.0, y: 699.0 },
    { x: 746.0, y: 667.0 },
    { x: 823.0, y: 591.5 },
  ])
}

///|
test "route_pathplan_from_boxes matches Graphviz barrier-aware bend corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: -240.0, lly: 153.0, urx: 833.0, ury: 179.5 },
    { llx: -240.0, lly: 143.0, urx: 1434.35693359375, ury: 153.0 },
    { llx: -240.0, lly: 129.0, urx: 770.1103515625, ury: 143.0 },
    { llx: -240.0, lly: 121.0, urx: 1434.35693359375, ury: 129.0 },
    { llx: -240.0, lly: 42.5, urx: 819.0, ury: 121.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 780.0, y: 178.5 }, { x: 783.0, y: 43.5 }) {
    Some(value) => value
    None => fail("expected route for barrier-aware bend fixture")
  }

  assert_points_eq(route.polygon, [
    { x: 833.0, y: 179.5 },
    { x: 833.0, y: 153.0 },
    { x: 1434.35693359375, y: 153.0 },
    { x: 1434.35693359375, y: 143.0 },
    { x: 770.1103515625, y: 143.0 },
    { x: 770.1103515625, y: 129.0 },
    { x: 1434.35693359375, y: 129.0 },
    { x: 1434.35693359375, y: 121.0 },
    { x: 819.0, y: 121.0 },
    { x: 819.0, y: 42.5 },
    { x: -240.0, y: 42.5 },
    { x: -240.0, y: 121.0 },
    { x: -240.0, y: 121.0 },
    { x: -240.0, y: 129.0 },
    { x: -240.0, y: 129.0 },
    { x: -240.0, y: 143.0 },
    { x: -240.0, y: 143.0 },
    { x: -240.0, y: 153.0 },
    { x: -240.0, y: 153.0 },
    { x: -240.0, y: 179.5 },
  ])
  assert_points_eq(route.points, [
    { x: 780.0, y: 178.5 },
    { x: 770.1103515625, y: 143.0 },
    { x: 770.1103515625, y: 129.0 },
    { x: 783.0, y: 43.5 },
  ])
}

///|
test "route_pathplan_from_boxes matches Graphviz constrained head tangent corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: -240.0, lly: 564.0, urx: 178.0, ury: 590.5 },
    { llx: -240.0, lly: 554.0, urx: 1434.35693359375, ury: 564.0 },
    { llx: -240.0, lly: 540.0, urx: 180.2587890625, ury: 554.0 },
    { llx: -240.0, lly: 532.0, urx: 1434.35693359375, ury: 540.0 },
    { llx: -240.0, lly: 502.0, urx: 746.0, ury: 532.0 },
    { llx: -240.0, lly: 483.5, urx: 209.02978515625, ury: 502.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 79.0, y: 589.5 }, { x: 208.02978515625, y: 483.5 }) {
    Some(value) => value
    None => fail("expected route for constrained head tangent fixture")
  }

  assert_points_eq(route.polygon, [
    { x: 178.0, y: 590.5 },
    { x: 178.0, y: 564.0 },
    { x: 1434.35693359375, y: 564.0 },
    { x: 1434.35693359375, y: 554.0 },
    { x: 180.2587890625, y: 554.0 },
    { x: 180.2587890625, y: 540.0 },
    { x: 1434.35693359375, y: 540.0 },
    { x: 1434.35693359375, y: 532.0 },
    { x: 746.0, y: 532.0 },
    { x: 746.0, y: 502.0 },
    { x: 209.02978515625, y: 502.0 },
    { x: 209.02978515625, y: 483.5 },
    { x: -240.0, y: 483.5 },
    { x: -240.0, y: 502.0 },
    { x: -240.0, y: 502.0 },
    { x: -240.0, y: 532.0 },
    { x: -240.0, y: 532.0 },
    { x: -240.0, y: 540.0 },
    { x: -240.0, y: 540.0 },
    { x: -240.0, y: 554.0 },
    { x: -240.0, y: 554.0 },
    { x: -240.0, y: 564.0 },
    { x: -240.0, y: 564.0 },
    { x: -240.0, y: 590.5 },
  ])
  assert_points_eq(route.points, [
    { x: 79.0, y: 589.5 },
    { x: 208.02978515625, y: 483.5 },
  ])
}

///|
test "route_pathplan_from_boxes matches Graphviz stepped cluster corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: -80.0, lly: 224.0, urx: 122.0, ury: 242.0 },
    { llx: -80.0, lly: 188.0, urx: 252.0, ury: 224.0 },
    { llx: 99.0, lly: 152.0, urx: 122.0, ury: 188.0 },
    { llx: -80.0, lly: 116.0, urx: 252.0, ury: 152.0 },
    { llx: 86.0, lly: 80.0, urx: 122.0, ury: 116.0 },
    { llx: -80.0, lly: 44.0, urx: 252.0, ury: 80.0 },
    { llx: -80.0, lly: 26.0, urx: 122.0, ury: 44.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 83.0, y: 241.0 }, { x: 83.0, y: 27.0 }) {
    Some(value) => value
    None => fail("expected route for stepped cluster corridor fixture")
  }

  assert_points_eq(route.polygon, [
    { x: 122.0, y: 242.0 },
    { x: 122.0, y: 224.0 },
    { x: 252.0, y: 224.0 },
    { x: 252.0, y: 188.0 },
    { x: 122.0, y: 188.0 },
    { x: 122.0, y: 152.0 },
    { x: 252.0, y: 152.0 },
    { x: 252.0, y: 116.0 },
    { x: 122.0, y: 116.0 },
    { x: 122.0, y: 80.0 },
    { x: 252.0, y: 80.0 },
    { x: 252.0, y: 44.0 },
    { x: 122.0, y: 44.0 },
    { x: 122.0, y: 26.0 },
    { x: -80.0, y: 26.0 },
    { x: -80.0, y: 44.0 },
    { x: -80.0, y: 44.0 },
    { x: -80.0, y: 80.0 },
    { x: 86.0, y: 80.0 },
    { x: 86.0, y: 116.0 },
    { x: -80.0, y: 116.0 },
    { x: -80.0, y: 152.0 },
    { x: 99.0, y: 152.0 },
    { x: 99.0, y: 188.0 },
    { x: -80.0, y: 188.0 },
    { x: -80.0, y: 224.0 },
    { x: -80.0, y: 224.0 },
    { x: -80.0, y: 242.0 },
  ])
  assert_points_eq(route.points, [
    { x: 83.0, y: 241.0 },
    { x: 99.0, y: 188.0 },
    { x: 99.0, y: 152.0 },
    { x: 83.0, y: 27.0 },
  ])
}

///|
test "route_pathplan_from_boxes matches Graphviz routed multi-bend corridor fixture" {
  let boxes : Array[@geom.Rect] = [
    { llx: -240.0, lly: 801.0, urx: 1434.35693359375, ury: 819.5 },
    { llx: -240.0, lly: 783.0, urx: 1434.35693359375, ury: 801.0 },
    { llx: -240.0, lly: 782.0, urx: 582.0, ury: 783.0 },
    { llx: -240.0, lly: 774.0, urx: 1434.35693359375, ury: 782.0 },
    { llx: 246.0, lly: 699.0, urx: 542.0, ury: 774.0 },
    { llx: -240.0, lly: 689.0, urx: 1434.35693359375, ury: 699.0 },
    { llx: 164.0, lly: 675.0, urx: 585.0, ury: 689.0 },
    { llx: -240.0, lly: 667.0, urx: 1434.35693359375, ury: 675.0 },
    { llx: 487.0, lly: 590.5, urx: 746.0, ury: 667.0 },
  ]
  let route = match
    route_pathplan_from_boxes(boxes, { x: 586.0, y: 818.5 }, { x: 598.0, y: 591.5 }) {
    Some(value) => value
    None => fail("expected route for routed multi-bend corridor fixture")
  }

  assert_points_eq(route.polygon, [
    { x: 1434.35693359375, y: 819.5 },
    { x: 1434.35693359375, y: 801.0 },
    { x: 1434.35693359375, y: 801.0 },
    { x: 1434.35693359375, y: 783.0 },
    { x: 582.0, y: 783.0 },
    { x: 582.0, y: 782.0 },
    { x: 1434.35693359375, y: 782.0 },
    { x: 1434.35693359375, y: 774.0 },
    { x: 542.0, y: 774.0 },
    { x: 542.0, y: 699.0 },
    { x: 1434.35693359375, y: 699.0 },
    { x: 1434.35693359375, y: 689.0 },
    { x: 585.0, y: 689.0 },
    { x: 585.0, y: 675.0 },
    { x: 1434.35693359375, y: 675.0 },
    { x: 1434.35693359375, y: 667.0 },
    { x: 746.0, y: 667.0 },
    { x: 746.0, y: 590.5 },
    { x: 487.0, y: 590.5 },
    { x: 487.0, y: 667.0 },
    { x: -240.0, y: 667.0 },
    { x: -240.0, y: 675.0 },
    { x: 164.0, y: 675.0 },
    { x: 164.0, y: 689.0 },
    { x: -240.0, y: 689.0 },
    { x: -240.0, y: 699.0 },
    { x: 246.0, y: 699.0 },
    { x: 246.0, y: 774.0 },
    { x: -240.0, y: 774.0 },
    { x: -240.0, y: 782.0 },
    { x: -240.0, y: 782.0 },
    { x: -240.0, y: 783.0 },
    { x: -240.0, y: 783.0 },
    { x: -240.0, y: 801.0 },
    { x: -240.0, y: 801.0 },
    { x: -240.0, y: 819.5 },
  ])
  assert_points_eq(route.points, [
    { x: 586.0, y: 818.5 },
    { x: 542.0, y: 774.0 },
    { x: 542.0, y: 699.0 },
    { x: 598.0, y: 591.5 },
  ])
}
