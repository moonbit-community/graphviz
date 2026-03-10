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
