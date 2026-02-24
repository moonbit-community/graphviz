///|
fn parse_double(text : String, fallback : Double) -> Double {
  try @strconv.parse_double(text) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn parse_point(text : String) -> @geom.Point {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 { parse_double(parts[0], 0.0) } else { 0.0 }
  let y = if parts.length() > 1 { parse_double(parts[1], 0.0) } else { 0.0 }
  { x, y }
}

///|
fn node_pos(graph : @cgraph.Graph, name : String) -> @geom.Point? {
  match graph.find_node(name) {
    Some(node) =>
      match node.get_attr("pos") {
        Some(value) => Some(parse_point(value))
        None => None
      }
    None => None
  }
}

///|
test "constraint false keeps nodes on same rank" {
  let graph = @dot_parser.parse_dot("digraph { a -> b [constraint=false]; }")
  let layout = layout_dot(graph)
  layout.apply()
  let a_pos = match node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_pos = match node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(Double::is_close(a_pos.y, b_pos.y, absolute_tolerance=0.01))
}

///|
test "constraint none keeps nodes on same rank" {
  let graph = @dot_parser.parse_dot("digraph { a -> b [constraint=none]; }")
  let layout = layout_dot(graph)
  layout.apply()
  let a_pos = match node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_pos = match node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(Double::is_close(a_pos.y, b_pos.y, absolute_tolerance=0.01))
}

///|
test "constraint unknown token keeps nodes on same rank" {
  let graph = @dot_parser.parse_dot("digraph { a -> b [constraint=abc]; }")
  let layout = layout_dot(graph)
  layout.apply()
  let a_pos = match node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_pos = match node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(Double::is_close(a_pos.y, b_pos.y, absolute_tolerance=0.01))
}

///|
test "constraint true separates ranks" {
  let graph = @dot_parser.parse_dot("digraph { a -> b; }")
  let layout = layout_dot(graph)
  layout.apply()
  let a_pos = match node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_pos = match node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(!Double::is_close(a_pos.y, b_pos.y, absolute_tolerance=0.01))
}
