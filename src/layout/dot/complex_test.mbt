///|
test "dot layout handles complex sample" {
  let graph = @dot_parser.parse_dot_file("tests/layout/dot/complex.dot")
  let layout = layout_dot(graph)
  layout.apply()
  let nodes = graph.nodes()
  guard nodes.length() > 0 else { fail("expected nodes") }
  for node in nodes {
    guard node.get_attr("pos") is Some(_) else {
      fail("missing pos for node \{node.name()}")
    }
  }
  let edges = graph.edges()
  guard edges.length() > 0 else { fail("expected edges") }
  for edge in edges {
    guard edge.get_attr("pos") is Some(_) else {
      fail(
        "missing pos for edge \{edge.tail().name()} -> \{edge.head().name()}",
      )
    }
  }
  guard graph.get_attr("bb") is Some(_) else { fail("missing graph bb") }
  let ordered = [
    "z_shapeshifter", "mobvm_a_req", "mobvm_a_req1", "other_xprot", "tunnel_ingress",
    "accel_appearance", "handle_1", "handle_x",
  ]
  let positions : Array[@geom.Point] = []
  for name in ordered {
    let pos = match complex_node_pos(graph, name) {
      Some(value) => value
      None => fail("missing pos for node \{name}")
    }
    positions.push(pos)
  }
  for i in 1..<positions.length() {
    guard positions[i - 1].x < positions[i].x else {
      fail("expected \{ordered[i - 1]} left of \{ordered[i]}")
    }
  }
}

///|
test "dot layout matches graphviz node positions for complex sample" {
  let reference = @dot_parser.parse_dot_file("tests/layout/dot/complex.gv.dot")
  let graph = @dot_parser.parse_dot_file("tests/layout/dot/complex.dot")
  let layout = layout_dot(graph)
  layout.apply()
  let eps = 3.0
  for node in reference.nodes() {
    let name = node.name()
    let expected = match complex_node_pos(reference, name) {
      Some(value) => value
      None => fail("missing pos in reference for node \{name}")
    }
    let actual = match complex_node_pos(graph, name) {
      Some(value) => value
      None => fail("missing pos in layout for node \{name}")
    }
    if !complex_pos_close(actual, expected, eps) {
      fail(
        "node \{name} pos drift: got (\{actual.x},\{actual.y}) expected (\{expected.x},\{expected.y})",
      )
    }
  }
}

///|
test "dot layout matches graphviz edge control points for complex sample" {
  let reference = @dot_parser.parse_dot_file("tests/layout/dot/complex.gv.dot")
  let graph = @dot_parser.parse_dot_file("tests/layout/dot/complex.dot")
  let layout = layout_dot(graph)
  layout.apply()
  let tol = 60.0
  let tol_sq = tol * tol
  let mut worst_tail = ""
  let mut worst_head = ""
  let mut worst_sq = 0.0
  for edge in reference.edges() {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let actual_edge = match complex_find_edge(graph, tail, head) {
      Some(value) => value
      None => fail("missing edge \{tail} -> \{head} in layout")
    }
    let expected_points = complex_edge_points(edge)
    let actual_points = complex_edge_points(actual_edge)
    let expected_samples = complex_resample_polyline(expected_points, 8)
    let actual_samples = complex_resample_polyline(actual_points, 8)
    let count = if expected_samples.length() < actual_samples.length() {
      expected_samples.length()
    } else {
      actual_samples.length()
    }
    guard count > 0 else {
      fail("missing edge pos for \{tail} -> \{head}")
    }
    let mut max_sq = 0.0
    for i in 0..<count {
      let dx = actual_samples[i].x - expected_samples[i].x
      let dy = actual_samples[i].y - expected_samples[i].y
      let dist_sq = dx * dx + dy * dy
      if dist_sq > max_sq {
        max_sq = dist_sq
      }
    }
    if max_sq > worst_sq {
      worst_sq = max_sq
      worst_tail = tail
      worst_head = head
    }
  }
  if worst_sq > tol_sq {
    fail(
      "edge \{worst_tail} -> \{worst_head} pos drift: max \{Double::sqrt(worst_sq)} > \{tol}",
    )
  }
}

///|
test "dot layout matches graphviz edge label positions for complex sample" {
  let reference = @dot_parser.parse_dot_file("tests/layout/dot/complex.gv.dot")
  let graph = @dot_parser.parse_dot_file("tests/layout/dot/complex.dot")
  let layout = layout_dot(graph)
  layout.apply()
  let eps = 18.0
  for edge in reference.edges() {
    let expected = match complex_edge_label_pos(edge) {
      Some(value) => value
      None => continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    let actual_edge = match complex_find_edge(graph, tail, head) {
      Some(value) => value
      None => fail("missing edge \{tail} -> \{head} in layout")
    }
    let actual = match complex_edge_label_pos(actual_edge) {
      Some(value) => value
      None => fail("missing label pos for edge \{tail} -> \{head}")
    }
    if !complex_pos_close(actual, expected, eps) {
      fail(
        "edge \{tail} -> \{head} label pos drift: got (\{actual.x},\{actual.y}) expected (\{expected.x},\{expected.y})",
      )
    }
  }
}
