///|
fn complex_parse_double(text : String, fallback : Double) -> Double {
  try @strconv.parse_double(text) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn complex_parse_point(text : String) -> @geom.Point {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 {
    complex_parse_double(parts[0], 0.0)
  } else {
    0.0
  }
  let y = if parts.length() > 1 {
    complex_parse_double(parts[1], 0.0)
  } else {
    0.0
  }
  { x, y }
}

///|
fn complex_node_pos(graph : @cgraph.Graph, name : String) -> @geom.Point? {
  match graph.find_node(name) {
    Some(node) =>
      match node.get_attr("pos") {
        Some(value) => Some(complex_parse_point(value))
        None => None
      }
    None => None
  }
}

///|
fn complex_pos_close(
  actual : @geom.Point,
  expected : @geom.Point,
  eps : Double,
) -> Bool {
  let dx = Double::abs(actual.x - expected.x)
  let dy = Double::abs(actual.y - expected.y)
  dx <= eps && dy <= eps
}

///|
fn complex_parse_edge_points(text : String) -> Array[@geom.Point] {
  let points : Array[@geom.Point] = []
  for segment in text.split(";") {
    for token_view in segment.split(" ") {
      let token = token_view.trim(chars=" \n\r\t").to_string()
      if token == "" {
        continue
      }
      let mut cleaned = token
      if cleaned.has_suffix("\\") {
        cleaned = cleaned.unsafe_substring(start=0, end=cleaned.length() - 1)
      }
      if cleaned.has_prefix("\\") {
        cleaned = cleaned.unsafe_substring(start=1, end=cleaned.length())
      }
      cleaned = cleaned.trim(chars=" \n\r\t").to_string()
      if cleaned == "" {
        continue
      }
      if cleaned.has_prefix("s,") || cleaned.has_prefix("e,") {
        continue
      }
      if !cleaned.contains(",") {
        continue
      }
      points.push(complex_parse_point(cleaned))
    }
  }
  points
}

///|
fn complex_find_edge(
  graph : @cgraph.Graph,
  tail : String,
  head : String,
) -> @cgraph.Edge? {
  for edge in graph.edges() {
    if edge.tail().name() == tail && edge.head().name() == head {
      return Some(edge)
    }
  }
  None
}

///|
fn complex_edge_points(edge : @cgraph.Edge) -> Array[@geom.Point] {
  match edge.get_attr("pos") {
    Some(value) => complex_parse_edge_points(value)
    None => []
  }
}

///|
fn complex_edge_label_pos(edge : @cgraph.Edge) -> @geom.Point? {
  match edge.get_attr("lp") {
    Some(value) => Some(complex_parse_point(value))
    None => None
  }
}

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
    let count = if expected_points.length() < actual_points.length() {
      expected_points.length()
    } else {
      actual_points.length()
    }
    guard count > 0 else {
      fail("missing edge pos for \{tail} -> \{head}")
    }
    let mut max_sq = 0.0
    for i in 0..<count {
      let dx = actual_points[i].x - expected_points[i].x
      let dy = actual_points[i].y - expected_points[i].y
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
