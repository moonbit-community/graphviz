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
