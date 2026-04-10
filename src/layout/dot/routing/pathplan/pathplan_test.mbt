// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn point(x : Double, y : Double) -> @geom.Point {
  { x, y }
}

///|
test "shortest path is direct inside rectangle" {
  let polygon = [
    point(0.0, 0.0),
    point(10.0, 0.0),
    point(10.0, 10.0),
    point(0.0, 10.0),
  ]
  let start = point(1.0, 1.0)
  let end = point(9.0, 9.0)
  let path = shortest_path_in_poly(polygon, start, end)
  assert_eq(path.length(), 2)
  assert_eq(path[0], start)
  assert_eq(path[1], end)
}

///|
test "shortest path bends around concave notch" {
  let polygon = [
    point(0.0, 0.0),
    point(6.0, 0.0),
    point(6.0, 2.0),
    point(2.0, 2.0),
    point(2.0, 6.0),
    point(0.0, 6.0),
  ]
  let start = point(1.0, 5.0)
  let end = point(5.0, 1.0)
  let path = shortest_path_in_poly(polygon, start, end)
  assert_true(path.length() > 2)
  assert_eq(path[0], start)
  assert_eq(path[path.length() - 1], end)
}

///|
fn assert_points_eq(actual : Array[@geom.Point], expected : Array[@geom.Point]) -> Unit raise {
  if actual.length() != expected.length() {
    fail("expected point count \{expected.length()} got \{actual.length()}")
  }
  for i in 0..<expected.length() {
    assert_eq(actual[i], expected[i])
  }
}

///|
test "shortest path matches Graphviz single-bend corridor fixture" {
  let polygon = [
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
  let path = shortest_path_in_poly(
    polygon,
    point(824.0, 265.5),
    point(780.0, 180.5),
  )

  assert_points_eq(path, [
    point(824.0, 265.5),
    point(788.896484375, 230.0),
    point(780.0, 180.5),
  ])
}

///|
test "shortest path matches Graphviz multi-bend corridor fixture" {
  let polygon = [
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
  let path = shortest_path_in_poly(
    polygon,
    point(586.0, 724.5),
    point(823.0, 591.5),
  )

  assert_points_eq(path, [
    point(586.0, 724.5),
    point(631.0, 699.0),
    point(746.0, 667.0),
    point(823.0, 591.5),
  ])
}
