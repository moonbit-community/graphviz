///|
test "node size constructors keep point inch and half-width relationships" {
  let size = node_size_from_points(72.0, 36.0)
  assert_eq(size.width_in, 1.0)
  assert_eq(size.height_in, 0.5)
  assert_eq(size.left_pt, 36.0)
  assert_eq(size.right_pt, 36.0)

  let swapped = swap_node_size(size)
  assert_eq(swapped.width_pt, 36.0)
  assert_eq(swapped.height_pt, 72.0)
  assert_eq(swapped.left_pt, 18.0)
  assert_eq(swapped.right_pt, 18.0)

  let vnode = vnode_size_from_widths_with_h(12.0, 18.0, 9.0)
  assert_eq(vnode.width_pt, 30.0)
  assert_eq(vnode.height_pt, 9.0)
  assert_eq(vnode.left_pt, 12.0)
  assert_eq(vnode.right_pt, 18.0)
}

///|
test "node side lookup uses stored sizes and falls back to default width" {
  let size = vnode_size_from_widths(11.0, 13.0)
  let sizes : Map[String, NodeSize] = { "a": size }
  let fallback = default_node_width_in() * 72.0 / 2.0

  assert_eq(node_left_pt("a", sizes), 11.0)
  assert_eq(node_right_pt("a", sizes), 13.0)
  assert_eq(node_left_pt("missing", sizes), fallback)
  assert_eq(node_right_pt("missing", sizes), fallback)
}

///|
test "clip_to_rect clips horizontal vertical and diagonal rays" {
  let center : @geom.Point = { x: 0.0, y: 0.0 }
  let size = node_size_from_points(20.0, 10.0)
  let horizontal : @geom.Point = { x: 20.0, y: 0.0 }
  let vertical : @geom.Point = { x: 0.0, y: 20.0 }
  let diagonal : @geom.Point = { x: 20.0, y: 20.0 }
  let clipped_horizontal : @geom.Point = { x: 10.0, y: 0.0 }
  let clipped_vertical : @geom.Point = { x: 0.0, y: 5.0 }
  let clipped_diagonal : @geom.Point = { x: 5.0, y: 5.0 }

  assert_eq(clip_to_rect(center, size, horizontal), clipped_horizontal)
  assert_eq(clip_to_rect(center, size, vertical), clipped_vertical)
  assert_eq(clip_to_rect(center, size, diagonal), clipped_diagonal)
}
