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
test "nudge_route_endpoints respects rankdir and explicit ports" {
  let (tb_start, tb_end) = nudge_route_endpoints(
    { x: 0.0, y: 0.0 },
    { x: 0.0, y: 10.0 },
    RankDir::TB,
    false,
    false,
  )
  assert_eq(tb_start, { x: 0.0, y: 1.0 })
  assert_eq(tb_end, { x: 0.0, y: 9.0 })

  let (lr_start, lr_end) = nudge_route_endpoints(
    { x: 0.0, y: 0.0 },
    { x: 10.0, y: 0.0 },
    RankDir::LR,
    false,
    false,
  )
  assert_eq(lr_start, { x: 1.0, y: 0.0 })
  assert_eq(lr_end, { x: 9.0, y: 0.0 })

  let (explicit_start, explicit_end) = nudge_route_endpoints(
    { x: 0.0, y: 0.0 },
    { x: 0.0, y: 10.0 },
    RankDir::TB,
    true,
    true,
  )
  assert_eq(explicit_start, { x: 0.0, y: 0.0 })
  assert_eq(explicit_end, { x: 0.0, y: 10.0 })
}
