// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "point and map scaling helpers keep expected rounding and axis scaling" {
  let point : @geom.Point = { x: 1.25, y: -2.5 }
  assert_eq(scale_point(point, 2.0, 3.0), { x: 2.5, y: -7.5 })
  assert_eq(scale_point_rounded({ x: 1.4, y: -2.6 }, 2.0, 3.0), {
    x: 3.0,
    y: -8.0,
  })
  assert_eq(
    scale_optional_point(Some(point), 2.0, 3.0),
    Some({ x: 2.5, y: -7.5 }),
  )
  assert_eq(scale_optional_point(None, 2.0, 3.0), None)

  let points : Map[String, @geom.Point] = Map::new()
  points["a"] = { x: 1.4, y: -2.6 }
  points["b"] = { x: -0.6, y: 0.6 }
  let scaled_points = scale_point_map_rounded(points, 2.0, 3.0)
  assert_eq(scaled_points.get("a"), Some({ x: 3.0, y: -8.0 }))
  assert_eq(scaled_points.get("b"), Some({ x: -1.0, y: 2.0 }))

  let doubles : Map[Int, Double] = Map::new()
  doubles[1] = 1.24
  doubles[2] = -1.26
  let scaled_doubles = scale_double_map_rounded(doubles, 10.0)
  assert_eq(scaled_doubles.get(1), Some(12.0))
  assert_eq(scaled_doubles.get(2), Some(-13.0))

  let named : Map[String, Double] = Map::new()
  named["x"] = 1.5
  named["y"] = -2.0
  let scaled_named = scale_named_double_map(named, 4.0)
  assert_eq(scaled_named.get("x"), Some(6.0))
  assert_eq(scaled_named.get("y"), Some(-8.0))

  let rects : Map[String, @geom.Rect] = Map::new()
  rects["r"] = { llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 }
  let scaled_rects = scale_rect_map(rects, 2.0, 5.0)
  assert_eq(
    scaled_rects.get("r"),
    Some({ llx: 2.0, lly: 10.0, urx: 6.0, ury: 20.0 }),
  )
}
