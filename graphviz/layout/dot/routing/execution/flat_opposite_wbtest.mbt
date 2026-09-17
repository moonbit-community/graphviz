///|
test "adjacent opposite edges share a spindle group and preserve direction" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let forward = graph.edge(a, b)
  let backward = graph.edge(b, a)
  let left = @edge_spline.point(0.0, 0.0)
  let right = @edge_spline.point(30.0, 0.0)
  let bases : Map[Int, EdgeRouteBase] = Map([
    (
      forward.id(),
      build_route_base(
        forward,
        tail_anchor=left,
        head_anchor=right,
        tail_clip_enabled=true,
        head_clip_enabled=true,
      ),
    ),
    (
      backward.id(),
      build_route_base(
        backward,
        tail_anchor=right,
        head_anchor=left,
        tail_clip_enabled=true,
        head_clip_enabled=true,
      ),
    ),
  ])
  let output = collect_flat_adjacent_beziers(
    [forward, backward],
    bases,
    { "a": 0, "b": 0 },
    { "a": 0, "b": 1 },
  )
  guard output.get(forward.id()) is Some(first) else { fail("missing forward") }
  guard output.get(backward.id()) is Some(second) else {
    fail("missing backward")
  }
  assert_point_close(first[0], left)
  assert_point_close(first[1], @edge_spline.point(10.0, -5.0))
  assert_point_close(first[3], right)
  assert_point_close(second[0], right)
  assert_point_close(second[1], @edge_spline.point(20.0, 5.0))
  assert_point_close(second[2], @edge_spline.point(10.0, 5.0))
  assert_point_close(second[3], left)
}
