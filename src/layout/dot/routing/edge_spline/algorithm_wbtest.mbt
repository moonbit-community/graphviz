///|
fn assert_close(actual : Double, expected : Double, eps? : Double = 0.000001) -> Unit raise {
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
  assert_close(actual.x, expected.x, eps=eps)
  assert_close(actual.y, expected.y, eps=eps)
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
    assert_point_close(actual[i], expected[i], eps=eps)
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

  assert_eq(
    bezier,
    [point(0.0, 12.0), point(0.0, 12.0), point(0.0, 0.0), point(0.0, 0.0)],
  )
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

  assert_points_close(
    bezier,
    [
      point(0.0, 12.0),
      point(0.0, 12.0),
      point(0.0, 16.0 / 3.0),
      point(0.0, 0.0),
    ],
  )
}

///|
test "route_polyline_to_bezier matches Graphviz simple straight corridor fixture" {
  let polygon : Array[@geom.Point] = [
    point(110.23527602606173, 108.0),
    point(110.23527602606173, 82.0),
    point(110.23527602606173, 82.0),
    point(110.23527602606173, 74.0),
    point(110.23527602606173, 74.0),
    point(110.23527602606173, 26.0),
    point(-32.0, 26.0),
    point(-32.0, 74.0),
    point(-32.0, 74.0),
    point(-32.0, 82.0),
    point(-32.0, 82.0),
    point(-32.0, 108.0),
  ]
  let bezier = route_polyline_to_bezier(
    [point(47.0, 107.0), point(47.0, 27.0)],
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_eq(
    bezier,
    [point(47.0, 107.0), point(47.0, 107.0), point(47.0, 27.0), point(47.0, 27.0)],
  )
}

///|
test "route_polyline_to_bezier matches Graphviz long straight corridor fixture" {
  let polygon : Array[@geom.Point] = [
    point(1434.35693359375, 483.5),
    point(1434.35693359375, 457.0),
    point(1434.35693359375, 457.0),
    point(1434.35693359375, 447.0),
    point(1434.35693359375, 447.0),
    point(1434.35693359375, 446.0),
    point(1434.35693359375, 446.0),
    point(1434.35693359375, 428.0),
    point(1434.35693359375, 428.0),
    point(1434.35693359375, 409.5),
    point(-240.0, 409.5),
    point(-240.0, 428.0),
    point(-240.0, 428.0),
    point(-240.0, 446.0),
    point(-240.0, 446.0),
    point(-240.0, 447.0),
    point(-240.0, 447.0),
    point(-240.0, 457.0),
    point(511.0, 457.0),
    point(511.0, 483.5),
  ]
  let bezier = route_polyline_to_bezier(
    [point(824.0, 482.5), point(824.0, 410.5)],
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_eq(
    bezier,
    [
      point(824.0, 482.5),
      point(824.0, 482.5),
      point(824.0, 410.5),
      point(824.0, 410.5),
    ],
  )
}

///|
test "route_polyline_to_bezier reproduces the barrier-aware bend fit from Graphviz fixtures" {
  let shortest : Array[@geom.Point] = [
    point(780.0, 178.5),
    point(770.1103515625, 143.0),
    point(770.1103515625, 129.0),
    point(783.0, 43.5),
  ]
  let polygon : Array[@geom.Point] = [
    point(833.0, 179.5),
    point(833.0, 153.0),
    point(1434.35693359375, 153.0),
    point(1434.35693359375, 143.0),
    point(770.1103515625, 143.0),
    point(770.1103515625, 129.0),
    point(1434.35693359375, 129.0),
    point(1434.35693359375, 121.0),
    point(819.0, 121.0),
    point(819.0, 42.5),
    point(-240.0, 42.5),
    point(-240.0, 121.0),
    point(-240.0, 121.0),
    point(-240.0, 129.0),
    point(-240.0, 129.0),
    point(-240.0, 143.0),
    point(-240.0, 143.0),
    point(-240.0, 153.0),
    point(-240.0, 153.0),
    point(-240.0, 179.5),
  ]
  let route_barriers = bezier_test_polygon_edges(polygon)

  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=route_barriers,
  )

  assert_points_close(
    bezier,
    [
      point(780.0, 178.5),
      point(780.0, 178.5),
      point(772.3284867912414, 159.22768260618975),
      point(770.1103515625, 143.0),
      point(764.0713344784783, 98.81908117095833),
      point(783.0, 43.5),
      point(783.0, 43.5),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier matches Graphviz single-bend corridor fit" {
  let shortest : Array[@geom.Point] = [
    point(824.0, 265.5),
    point(788.896484375, 230.0),
    point(780.0, 180.5),
  ]
  let polygon : Array[@geom.Point] = [
    point(1434.35693359375, 266.5),
    point(1434.35693359375, 248.0),
    point(1434.35693359375, 248.0),
    point(1434.35693359375, 230.0),
    point(788.896484375, 230.0),
    point(788.896484375, 216.0),
    point(1434.35693359375, 216.0),
    point(1434.35693359375, 198.0),
    point(833.0, 198.0),
    point(833.0, 179.5),
    point(-240.0, 179.5),
    point(-240.0, 198.0),
    point(-240.0, 198.0),
    point(-240.0, 216.0),
    point(-240.0, 216.0),
    point(-240.0, 230.0),
    point(-240.0, 230.0),
    point(-240.0, 248.0),
    point(-240.0, 248.0),
    point(-240.0, 266.5),
  ]
  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(824.0, 265.5),
      point(824.0, 265.5),
      point(799.11933711946494, 249.69366156435439),
      point(788.896484375, 230.0),
      point(778.59825726675103, 210.16113462139765),
      point(780.0, 180.5),
      point(780.0, 180.5),
    ],
    eps=0.0001,
  )
}

///|
test "route_polyline_to_bezier matches Graphviz multi-bend corridor fit" {
  let shortest : Array[@geom.Point] = [
    point(586.0, 724.5),
    point(631.0, 699.0),
    point(746.0, 667.0),
    point(823.0, 591.5),
  ]
  let polygon : Array[@geom.Point] = [
    point(631.0, 725.5),
    point(631.0, 699.0),
    point(1434.35693359375, 699.0),
    point(1434.35693359375, 689.0),
    point(832.5771484375, 689.0),
    point(832.5771484375, 675.0),
    point(1434.35693359375, 675.0),
    point(1434.35693359375, 667.0),
    point(908.0, 667.0),
    point(908.0, 590.5),
    point(746.0, 590.5),
    point(746.0, 667.0),
    point(-240.0, 667.0),
    point(-240.0, 675.0),
    point(595.0, 675.0),
    point(595.0, 689.0),
    point(-240.0, 689.0),
    point(-240.0, 699.0),
    point(537.0, 699.0),
    point(537.0, 725.5),
  ]
  let bezier = route_polyline_to_bezier(
    shortest,
    point(0.0, 0.0),
    point(0.0, 0.0),
    true,
    1.0,
    0.0,
    route_barriers=bezier_test_polygon_edges(polygon),
  )

  assert_points_close(
    bezier,
    [
      point(586.0, 724.5),
      point(586.0, 724.5),
      point(609.7687386985847, 707.8135116721695),
      point(631.0, 699.0),
      point(679.9988404072257, 678.659623339332),
      point(700.0516020945997, 693.5209730944704),
      point(746.0, 667.0),
      point(787.5101242690987, 643.0407557374377),
      point(823.0, 591.5),
      point(823.0, 591.5),
    ],
    eps=0.0001,
  )
}

///|
test "parse_arrow_flags handles defaults synonyms and invalid values" {
  assert_eq(parse_arrow_flags(None), [ARR_TYPE_NORM])
  assert_eq(parse_arrow_flags(Some("")), [ARR_TYPE_NORM])
  assert_eq(
    parse_arrow_flags(Some("invempty")),
    [ARR_TYPE_NORM | ARR_MOD_INV | ARR_MOD_OPEN],
  )
  assert_eq(parse_arrow_flags(Some("crowtee")), [ARR_TYPE_CROW, ARR_TYPE_TEE])
  assert_eq(parse_arrow_flags(Some("l")), [ARR_TYPE_NORM | ARR_MOD_LEFT])
  assert_eq(parse_arrow_flags(Some("bogus")), [])
}

///|
test "arrow_length_for_edge swaps oriented attrs and clamps override" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)
  edge.set_attr("arrowtail", "crow")
  edge.set_attr("arrowhead", "box")
  edge.set_attr("arrowsize", "1.5")
  edge.set_attr("penwidth", "2.0")

  let base = arrow_length_for_edge(edge, true, true, None)
  let swapped = arrow_length_for_edge_oriented(edge, true, true, None, true)
  let override_len = arrow_length_for_edge(edge, true, true, Some(0.5))
  let head_only = arrow_length_for_edge(edge, false, true, None)

  assert_true(base.tail > 0.5)
  assert_true(base.head > 0.5)
  assert_eq(swapped.tail, base.head)
  assert_eq(swapped.head, base.tail)
  assert_eq(override_len.tail, 0.5)
  assert_eq(override_len.head, 0.5)
  assert_eq(head_only.tail, 0.0)
  assert_eq(head_only.head, base.head)
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

  assert_eq(
    compacted,
    [
      point(0.0, 0.0),
      point(5.0, 0.0),
      point(5.0, 6.0),
      point(3.0, 6.0),
      point(5.0, 6.0),
    ],
  )
}

///|
test "bbox spline clipping trims straight bezier at the first boundary hit" {
  let points : Array[@geom.Point] = [
    point(0.0, 0.0),
    point(3.0, 0.0),
    point(6.0, 0.0),
    point(9.0, 0.0),
  ]
  let end_bbox : @geom.Rect = { llx: 5.0, lly: -1.0, urx: 7.0, ury: 1.0 }
  let start_bbox : @geom.Rect = { llx: 0.0, lly: -1.0, urx: 4.0, ury: 1.0 }

  let end_clipped = clip_spline_end_to_bbox(points, end_bbox)
  let start_clipped = clip_spline_start_to_bbox(points, start_bbox)

  assert_eq(end_clipped.length(), 4)
  assert_point_close(end_clipped[0], point(0.0, 0.0))
  assert_point_close(end_clipped[1], point(1.6666667, 0.0), eps=0.01)
  assert_point_close(end_clipped[2], point(3.3333333, 0.0), eps=0.01)
  assert_point_close(end_clipped[3], point(5.0, 0.0), eps=0.01)

  assert_eq(start_clipped.length(), 4)
  assert_point_close(start_clipped[0], point(4.0, 0.0), eps=0.01)
  assert_point_close(start_clipped[1], point(5.6666667, 0.0), eps=0.01)
  assert_point_close(start_clipped[2], point(7.3333333, 0.0), eps=0.01)
  assert_point_close(start_clipped[3], point(9.0, 0.0))
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
    [
      point(408.0, 589.5),
      point(256.8798828125, 502.5),
    ],
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
    [
      point(79.0, 589.5),
      point(208.02978515625, 483.5),
    ],
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
