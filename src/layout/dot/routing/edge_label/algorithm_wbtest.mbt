///|
test "port_label_params applies defaults parse fallback and min clamp" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  assert_eq(port_label_params(edge, -25.0, -180.0), None)

  edge.set_attr("labeldistance", "2")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 2.0)))

  edge.set_attr("labelangle", "-999")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-180.0, 2.0)))

  edge.set_attr("labelangle", "oops")
  edge.set_attr("labeldistance", "oops")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 1.0)))
}

///|
test "port_label_params treats empty attrs as explicit defaults only when the other attr is present" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))

  edge.set_attr("labelangle", "")
  edge.set_attr("labeldistance", "")
  assert_eq(port_label_params(edge, -25.0, -180.0), None)

  edge.set_attr("labeldistance", "2")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-25.0, 2.0)))

  edge.set_attr("labelangle", "-30")
  edge.set_attr("labeldistance", "")
  assert_eq(port_label_params(edge, -25.0, -180.0), Some((-30.0, 1.0)))
}

///|
test "port_label_pos_from_points rotates the tangent direction by angle and distance" {
  let pos = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(4.0, 2.0),
    90.0,
    2.0,
    3.0,
    @node_geometry.GRAPHVIZ_PI,
  )

  assert_point_close(pos, @edge_spline.point(1.0, 8.0), eps=0.001)
}

///|
test "port_label_pos_from_points follows edge-local angle and distance scale" {
  let horizontal = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(5.0, 2.0),
    90.0,
    2.0,
    3.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  assert_point_close(horizontal, @edge_spline.point(1.0, 8.0), eps=0.001)

  let vertical = port_label_pos_from_points(
    @edge_spline.point(1.0, 2.0),
    @edge_spline.point(1.0, 6.0),
    0.0,
    0.5,
    4.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  assert_point_close(vertical, @edge_spline.point(1.0, 4.0), eps=0.001)
}

///|
test "edge_port_label_pos returns None without attrs or usable spline geometry" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let spline = straight_spline_with_markers()

  assert_eq(
    edge_port_label_pos(
      { edge, spline, is_head: false },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ),
    None,
  )

  edge.set_attr("labeldistance", "2")
  let short_spline : @geom.Spline = {
    start: None,
    end: None,
    points: [
      @edge_spline.point(0.0, 0.0),
      @edge_spline.point(1.0, 0.0),
      @edge_spline.point(2.0, 0.0),
    ],
  }
  assert_eq(
    edge_port_label_pos(
      { edge, spline: short_spline, is_head: true },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ),
    None,
  )
}

///|
test "edge_port_label_pos uses marker endpoints when dir enables both arrow markers" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("dir", "both")
  edge.set_attr("labelangle", "30")
  edge.set_attr("labeldistance", "1.4")
  let spline = straight_spline_with_markers()

  let tail = match
    edge_port_label_pos(
      { edge, spline, is_head: false },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ) {
    Some(value) => value
    None => fail("expected tail port label pos")
  }
  let head = match
    edge_port_label_pos(
      { edge, spline, is_head: true },
      -25.0,
      -180.0,
      10.0,
      @node_geometry.GRAPHVIZ_PI,
    ) {
    Some(value) => value
    None => fail("expected head port label pos")
  }

  let expected_tail = port_label_pos_from_points(
    @edge_spline.point(-1.0, 0.0),
    @edge_spline.point(0.0, 0.0),
    30.0,
    1.4,
    10.0,
    @node_geometry.GRAPHVIZ_PI,
  )
  let expected_head = port_label_pos_from_points(
    @edge_spline.point(10.0, 0.0),
    @edge_spline.point(9.0, 0.0),
    30.0,
    1.4,
    10.0,
    @node_geometry.GRAPHVIZ_PI,
  )

  assert_point_close(tail, expected_tail, eps=0.001)
  assert_point_close(head, expected_head, eps=0.001)
}

///|
test "edge_port_label_pos_for_dot uses bezier fallback and dot defaults when markers are absent" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  edge.set_attr("dir", "none")
  edge.set_attr("labeldistance", "2")
  let spline = straight_spline_with_markers()

  let tail = match
    edge_port_label_pos_for_dot({ edge, spline, is_head: false }) {
    Some(value) => value
    None => fail("expected tail port label pos")
  }
  let head = match
    edge_port_label_pos_for_dot({ edge, spline, is_head: true }) {
    Some(value) => value
    None => fail("expected head port label pos")
  }

  let expected_tail = port_label_pos_from_points(
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(0.9, 0.0),
    @node_geometry.PORT_LABEL_ANGLE_DEG,
    2.0,
    @node_geometry.PORT_LABEL_DISTANCE_PT,
    @node_geometry.GRAPHVIZ_PI,
  )
  let expected_head = port_label_pos_from_points(
    @edge_spline.point(9.0, 0.0),
    @edge_spline.point(8.1, 0.0),
    @node_geometry.PORT_LABEL_ANGLE_DEG,
    2.0,
    @node_geometry.PORT_LABEL_DISTANCE_PT,
    @node_geometry.GRAPHVIZ_PI,
  )

  assert_point_close(tail, expected_tail, eps=0.001)
  assert_point_close(head, expected_head, eps=0.001)
}

///|
