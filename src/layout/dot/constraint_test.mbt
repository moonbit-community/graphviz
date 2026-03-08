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
test "constraint=false keeps same rank while default separates ranks" {
  let unconstrained = @dot_parser.parse_dot("digraph { a -> b [constraint=false]; }")
  let unconstrained_layout = layout_dot(unconstrained)
  unconstrained_layout.apply()
  let unconstrained_a = match node_pos(unconstrained, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let unconstrained_b = match node_pos(unconstrained, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(
    Double::is_close(
      unconstrained_a.y,
      unconstrained_b.y,
      absolute_tolerance=0.01,
    ),
  )

  let constrained = @dot_parser.parse_dot("digraph { a -> b; }")
  let constrained_layout = layout_dot(constrained)
  constrained_layout.apply()
  let constrained_a = match node_pos(constrained, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let constrained_b = match node_pos(constrained, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(
    !Double::is_close(
      constrained_a.y,
      constrained_b.y,
      absolute_tolerance=0.01,
    ),
  )
}
