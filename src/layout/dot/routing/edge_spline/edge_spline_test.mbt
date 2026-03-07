///|
test "point helpers compute expected values" {
  let a = point(1.0, 2.0)
  let b = point(3.0, 4.0)
  assert_eq(point_add(a, b), { x: 4.0, y: 6.0 })
  assert_eq(point_sub(b, a), { x: 2.0, y: 2.0 })
  assert_eq(point_scale(a, 2.0), { x: 2.0, y: 4.0 })
  assert_eq(point_dist2(a, b), 8.0)
  assert_eq(point_lerp(a, b, 0.5), { x: 2.0, y: 3.0 })
  assert_eq(point_dist(a, a), 0.0)
}

///|
test "port side helpers and endpoint slope" {
  let size = @node_primitives.node_size_from_points(100.0, 50.0)
  let pos = point(10.0, 20.0)
  let rect = port_side_rect(pos, size)
  assert_eq(rect, { llx: -40.0, lly: -5.0, urx: 60.0, ury: 45.0 })
  assert_eq(port_side_count(rect, pos, size), 4)
  let port_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + 1.0,
    urx: rect.llx + 5.0,
    ury: rect.ury - 1.0,
  }
  assert_eq(port_side_count(port_rect, pos, size), 1)
  let slope = endpoint_slope_for_anchor(
    None,
    0,
    point(0.0, 0.0),
    pos,
    size,
    point(10.0, 0.0),
    @dot_shared.RankDir::TB,
    true,
    None,
  )
  assert_eq(slope, { x: 0.0, y: 0.0 })
}
