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
