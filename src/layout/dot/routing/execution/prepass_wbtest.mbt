///|
test "collect_flat_adjacent_beziers builds one spindle per adjacent same-rank duplicate edge" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge_1 = graph.edge(a, b)
  let edge_2 = graph.edge(a, b)
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[edge_1.id()] = build_route_base(
    edge_1,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
    tail_clip_enabled=true,
    head_clip_enabled=true,
  )
  base_cache[edge_2.id()] = build_route_base(
    edge_2,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
    tail_clip_enabled=true,
    head_clip_enabled=true,
  )

  let output = collect_flat_adjacent_beziers(
    [edge_2, edge_1],
    base_cache,
    { "a": 0, "b": 0 },
    { "a": 0, "b": 1 },
  )

  let bezier_1 = match output.get(edge_1.id()) {
    Some(value) => value
    None => fail("expected first adjacent spindle")
  }
  let bezier_2 = match output.get(edge_2.id()) {
    Some(value) => value
    None => fail("expected second adjacent spindle")
  }
  assert_eq(bezier_1.length(), 4)
  assert_eq(bezier_2.length(), 4)
  assert_point_close(bezier_1[0], @edge_spline.point(0.0, 0.0))
  assert_point_close(bezier_1[1], @edge_spline.point(10.0, -5.0))
  assert_point_close(bezier_1[2], @edge_spline.point(20.0, -5.0))
  assert_point_close(bezier_1[3], @edge_spline.point(30.0, 0.0))
  assert_point_close(bezier_2[0], @edge_spline.point(0.0, 0.0))
  assert_point_close(bezier_2[1], @edge_spline.point(10.0, 5.0))
  assert_point_close(bezier_2[2], @edge_spline.point(20.0, 5.0))
  assert_point_close(bezier_2[3], @edge_spline.point(30.0, 0.0))
}

///|
test "collect_flat_adjacent_beziers filters out labeled ported sameport and unclipped duplicate classes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let labeled_1 = graph.edge(a, b)
  let labeled_2 = graph.edge(a, b)
  labeled_1.set_attr("label", "mid")
  labeled_2.set_attr("label", "mid")
  let ported_1 = graph.edge(a, b, head_port={ name: Some("p"), compass: None })
  let ported_2 = graph.edge(a, b, head_port={ name: Some("p"), compass: None })
  let sameport_1 = graph.edge(a, b)
  let sameport_2 = graph.edge(a, b)
  sameport_1.set_attr("samehead", "g")
  sameport_2.set_attr("samehead", "g")
  let unclipped_1 = graph.edge(a, b)
  let unclipped_2 = graph.edge(a, b)
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  for edge in [labeled_1, labeled_2, ported_1, ported_2, sameport_1, sameport_2] {
    base_cache[edge.id()] = build_route_base(
      edge,
      tail_anchor=@edge_spline.point(0.0, 0.0),
      head_anchor=@edge_spline.point(30.0, 0.0),
      tail_clip_enabled=true,
      head_clip_enabled=true,
    )
  }
  base_cache[unclipped_1.id()] = build_route_base(
    unclipped_1,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
  )
  base_cache[unclipped_2.id()] = build_route_base(
    unclipped_2,
    tail_anchor=@edge_spline.point(0.0, 0.0),
    head_anchor=@edge_spline.point(30.0, 0.0),
  )

  let output = collect_flat_adjacent_beziers(
    [
      labeled_1, labeled_2, ported_1, ported_2, sameport_1, sameport_2, unclipped_1,
      unclipped_2,
    ],
    base_cache,
    { "a": 0, "b": 0 },
    { "a": 0, "b": 1 },
  )

  assert_eq(output.length(), 0)
}
