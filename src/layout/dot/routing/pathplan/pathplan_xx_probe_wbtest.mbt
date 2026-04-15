///|
fn probe_point(x : Double, y : Double) -> @geom.Point {
  { x, y }
}

///|
#skip
test "probe xx first-segment triangulation status" {
  let polygon = [
    probe_point(-5509.992865238848, 483.5),
    probe_point(-5509.992865238848, 472.0),
    probe_point(-8183.896627562704, 472.0),
    probe_point(-8183.896627562704, 436.0),
    probe_point(-9116.332061835481, 436.0),
    probe_point(-9116.332061835481, 413.0),
    probe_point(-9898.0, 413.0),
    probe_point(-9898.0, 377.0),
    probe_point(-9922.0, 377.0),
    probe_point(-9922.0, 365.5),
    probe_point(-9898.0, 365.5),
    probe_point(-9898.0, 377.0),
    probe_point(-9228.225544759291, 377.0),
    probe_point(-9228.225544759291, 413.0),
    probe_point(-8329.773606883049, 413.0),
    probe_point(-8329.773606883049, 436.0),
    probe_point(-5636.806322811214, 436.0),
    probe_point(-5636.806322811214, 472.0),
    probe_point(-4533.0, 472.0),
    probe_point(-4533.0, 483.5),
  ]
  let normalized = normalize_polygon_order(polygon)
  let nodes = prepare_polygon_nodes(normalized)
  let point_indices : Array[Int] = []
  for i in 0..<normalized.length() {
    point_indices.push(i)
  }
  let triangles : Array[PathTriangle] = []
  let ok = triangulate(point_indices, nodes, triangles)

  inspect(ok)
  inspect(normalized.length())
  inspect(triangles.length())
}
