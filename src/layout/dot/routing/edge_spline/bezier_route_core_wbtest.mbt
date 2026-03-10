///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn assert_point_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_close(actual.x, expected.x, eps~)
  assert_close(actual.y, expected.y, eps~)
}

///|
fn assert_points_close(
  actual : Array[@geom.Point],
  expected : Array[@geom.Point],
  eps? : Double = 0.000001,
) -> Unit raise {
  if actual.length() != expected.length() {
    fail("expected point count \{expected.length()} got \{actual.length()}")
  }
  for i in 0..<expected.length() {
    assert_point_close(actual[i], expected[i], eps~)
  }
}

///|
fn bezier_test_polygon_edges(
  polygon : Array[@geom.Point],
) -> Array[(@geom.Point, @geom.Point)] {
  let edges : Array[(@geom.Point, @geom.Point)] = []
  for i in 0..<polygon.length() {
    let next = if i + 1 < polygon.length() { i + 1 } else { 0 }
    edges.push((polygon[i], polygon[next]))
  }
  edges
}

///|
test "route_polyline_to_bezier keeps unconstrained straight segments as degenerate cubic" {
  let bezier = route_polyline_to_bezier(
    [point(0.0, 12.0), point(0.0, 0.0)],
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
  )

  assert_eq(bezier, [
    point(0.0, 12.0),
    point(0.0, 12.0),
    point(0.0, 0.0),
    point(0.0, 0.0),
  ])
}

///|
test "route_polyline_to_bezier honors a constrained head tangent on a straight segment" {
  let bezier = route_polyline_to_bezier(
    [point(0.0, 12.0), point(0.0, 0.0)],
    point(0.0, 0.0),
    point(0.0, -1.0),
    true,
    1.0,
    0.0,
  )

  assert_points_close(bezier, [
    point(0.0, 12.0),
    point(0.0, 12.0),
    point(0.0, 16.0 / 3.0),
    point(0.0, 0.0),
  ])
}

///|
test "compact_polyline removes straight runs but preserves reversals" {
  let points : Array[@geom.Point] = [
    point(0.0, 0.0),
    point(2.0, 0.0),
    point(5.0, 0.0),
    point(5.0, 0.0),
    point(5.0, 3.0),
    point(5.0, 6.0),
    point(3.0, 6.0),
    point(5.0, 6.0),
  ]

  let compacted = compact_polyline(points)

  assert_eq(compacted, [
    point(0.0, 0.0),
    point(5.0, 0.0),
    point(5.0, 6.0),
    point(3.0, 6.0),
    point(5.0, 6.0),
  ])
}

///|
test "route_polyline_to_bezier matches Graphviz constrained vertical head tangent" {
  let polygon : Array[@geom.Point] = [
    point(519.0, 590.5),
    point(519.0, 564.0),
    point(1434.35693359375, 564.0),
    point(1434.35693359375, 554.0),
    point(385.0, 554.0),
    point(385.0, 540.0),
    point(1434.35693359375, 540.0),
    point(1434.35693359375, 532.0),
    point(746.0, 532.0),
    point(746.0, 457.0),
    point(-240.0, 457.0),
    point(-240.0, 532.0),
    point(-240.0, 532.0),
    point(-240.0, 540.0),
    point(271.0, 540.0),
    point(271.0, 554.0),
    point(-240.0, 554.0),
    point(-240.0, 564.0),
    point(333.0, 564.0),
    point(333.0, 590.5),
  ]
  let bezier = route_polyline_to_bezier(
    [point(408.0, 589.5), point(256.8798828125, 502.5)],
    point(0.0, 0.0),
    point(0.0, -1.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(408.0, 589.5),
      point(408.0, 589.5),
      point(256.8798828125, 541.2497764669068),
      point(256.8798828125, 502.5),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier matches Graphviz constrained horizontal head tangent" {
  let bezier = route_polyline_to_bezier(
    [point(79.0, 589.5), point(208.02978515625, 483.5)],
    point(0.0, 0.0),
    point(1.0, 0.0),
    true,
    1.0,
    0.0,
  )

  assert_points_close(
    bezier,
    [
      point(79.0, 589.5),
      point(79.0, 589.5),
      point(133.8133043969875, 483.5),
      point(208.02978515625, 483.5),
    ],
    eps=0.0001,
  )
}
