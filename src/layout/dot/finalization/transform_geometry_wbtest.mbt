///|
test "transform_point and transform_optional_point map coordinates for each rankdir" {
  let bbox : @geom.Rect = { llx: 10.0, lly: 20.0, urx: 50.0, ury: 80.0 }
  let point : @geom.Point = { x: 13.0, y: 29.0 }

  assert_eq(transform_point(point, bbox, RankDir::TB), point)
  assert_eq(transform_point(point, bbox, RankDir::BT), { x: 13.0, y: 71.0 })
  assert_eq(transform_point(point, bbox, RankDir::LR), { x: 71.0, y: 13.0 })
  assert_eq(transform_point(point, bbox, RankDir::RL), { x: 29.0, y: 13.0 })

  assert_eq(
    transform_optional_point(Some(point), bbox, RankDir::BT),
    Some({ x: 13.0, y: 71.0 }),
  )
  assert_eq(transform_optional_point(None, bbox, RankDir::LR), None)
}

///|
test "transform_spline and shift_spline update all spline coordinates consistently" {
  let bbox : @geom.Rect = { llx: 0.0, lly: 10.0, urx: 100.0, ury: 60.0 }
  let spline : @geom.Spline = {
    start: Some({ x: 1.0, y: 11.0 }),
    end: Some({ x: 7.0, y: 17.0 }),
    points: [
      { x: 1.0, y: 11.0 },
      { x: 3.0, y: 13.0 },
      { x: 5.0, y: 15.0 },
      { x: 7.0, y: 17.0 },
    ],
  }

  let transformed = transform_spline(spline, bbox, RankDir::BT)
  assert_eq(transformed.start, Some({ x: 1.0, y: 59.0 }))
  assert_eq(transformed.end, Some({ x: 7.0, y: 53.0 }))
  assert_eq(transformed.points, [
    { x: 1.0, y: 59.0 },
    { x: 3.0, y: 57.0 },
    { x: 5.0, y: 55.0 },
    { x: 7.0, y: 53.0 },
  ])

  let shifted = shift_spline(spline, 4.0, -3.0)
  assert_eq(shifted.start, Some({ x: 5.0, y: 8.0 }))
  assert_eq(shifted.end, Some({ x: 11.0, y: 14.0 }))
  assert_eq(shifted.points, [
    { x: 5.0, y: 8.0 },
    { x: 7.0, y: 10.0 },
    { x: 9.0, y: 12.0 },
    { x: 11.0, y: 14.0 },
  ])
}

///|
test "shift helpers and transform_bbox_with_root preserve geometric bounds" {
  let point : @geom.Point = { x: 3.0, y: 4.0 }
  assert_eq(shift_point(point, 5.0, -2.0), { x: 8.0, y: 2.0 })
  assert_eq(
    shift_optional_point(Some(point), -1.0, 6.0),
    Some({ x: 2.0, y: 10.0 }),
  )
  assert_eq(shift_optional_point(None, -1.0, 6.0), None)

  let bbox : @geom.Rect = { llx: 20.0, lly: 10.0, urx: 40.0, ury: 30.0 }
  let root_bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 100.0, ury: 80.0 }

  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::TB), bbox)
  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::BT), {
    llx: 20.0,
    lly: 50.0,
    urx: 40.0,
    ury: 70.0,
  })
  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::LR), {
    llx: 50.0,
    lly: 20.0,
    urx: 70.0,
    ury: 40.0,
  })
  assert_eq(transform_bbox_with_root(bbox, root_bbox, RankDir::RL), {
    llx: 10.0,
    lly: 20.0,
    urx: 30.0,
    ury: 40.0,
  })
}
