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
