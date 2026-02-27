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
  let node_size = @dot_shared.node_size_from_points(10.0, 10.0)

  let (tail_boxes, tail_start) = beginpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: 0.0, y: 0.0 },
    SIDE_BOTTOM,
    false,
    10.0,
  )
  assert_eq(tail_boxes.length(), 1)
  assert_eq(tail_start, { x: 0.0, y: -1.0 })

  let (tail_top_boxes, tail_top_start) = beginpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: -1.0, y: 5.0 },
    SIDE_TOP,
    false,
    10.0,
  )
  assert_eq(tail_top_boxes.length(), 2)
  assert_eq(tail_top_start, { x: -1.0, y: 6.0 })

  let (head_boxes, head_end) = endpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: 0.0, y: 0.0 },
    SIDE_TOP,
    false,
    10.0,
  )
  assert_eq(head_boxes.length(), 1)
  assert_eq(head_end, { x: 0.0, y: 1.0 })

  let (head_bottom_boxes, head_bottom_end) = endpath_boxes_regular(
    base_box,
    node_pos,
    node_size,
    { x: -1.0, y: -5.0 },
    SIDE_BOTTOM,
    false,
    10.0,
  )
  assert_eq(head_bottom_boxes.length(), 2)
  assert_eq(head_bottom_end, { x: -1.0, y: -6.0 })
}
