///|
test "label attachment follows upstream midpoint termination and underline order" {
  let spline : @geom.Spline = {
    start: None,
    end: None,
    points: [
      { x: 0.0, y: 0.0, },
      { x: 10.0, y: 0.0, },
      { x: 20.0, y: 0.0, },
      { x: 30.0, y: 0.0, },
    ],
  }
  let points = label_attachment("label", { x: 15.0, y: 10.0, }, 8.0, 4.0, [
    spline,
  ])
  assert_true(points.length() == 3)
  assert_true(points[0].x == 19.0 && points[0].y == 8.0)
  assert_true(points[1].x == 11.0 && points[1].y == 8.0)
  assert_true(points[2].x == 15.0 && points[2].y == 0.0)
  assert_true(
    label_attachment(" \t", { x: 0.0, y: 0.0, }, 8.0, 4.0, [spline]).length() ==
    0,
  )
  assert_true(
    label_attachment("label", { x: 0.0, y: 0.0, }, 8.0, 4.0, []).length() == 0,
  )
}
