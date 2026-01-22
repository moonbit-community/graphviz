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
