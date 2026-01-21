///|
fn neato_parse_double(text : String, fallback : Double) -> Double {
  try @strconv.parse_double(text) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn neato_parse_pos(text : String) -> @geom.Point {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 { neato_parse_double(parts[0], 0.0) } else { 0.0 }
  let y = if parts.length() > 1 { neato_parse_double(parts[1], 0.0) } else { 0.0 }
  { x, y }
}

///|
fn neato_node_pos(graph : @cgraph.Graph, name : String) -> @geom.Point? {
  match graph.find_node(name) {
    Some(node) => match node.get_attr("pos") {
      Some(value) => Some(neato_parse_pos(value))
      None => None
    }
    None => None
  }
}

///|
fn neato_distance(a : @geom.Point, b : @geom.Point) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  Double::sqrt(dx * dx + dy * dy)
}

test "layout_neato preserves pinned positions" {
  let graph = @dot_parser.parse_dot(
    "graph { node [shape=box,width=1,height=1,label=\"\"]; a [pos=\"10,20!\"]; b [pos=\"30,40\", pin=true]; c; a -- c; b -- c; }",
  )
  let layout = layout_neato(graph)
  layout.apply()
  let a_pos = match neato_node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_pos = match neato_node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  assert_true(Double::is_close(a_pos.x, 10.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(a_pos.y, 20.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(b_pos.x, 30.0, absolute_tolerance=0.01))
  assert_true(Double::is_close(b_pos.y, 40.0, absolute_tolerance=0.01))
}

test "layout_neato scales spacing with nodesep" {
  let graph_small = @dot_parser.parse_dot(
    "graph { nodesep=0.1; node [shape=box,width=1,height=1,label=\"\"]; a; b; }",
  )
  let graph_large = @dot_parser.parse_dot(
    "graph { nodesep=2; node [shape=box,width=1,height=1,label=\"\"]; a; b; }",
  )
  let layout_small = layout_neato(graph_small)
  layout_small.apply()
  let layout_large = layout_neato(graph_large)
  layout_large.apply()
  let a_small = match neato_node_pos(graph_small, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_small = match neato_node_pos(graph_small, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let a_large = match neato_node_pos(graph_large, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_large = match neato_node_pos(graph_large, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let small_dist = neato_distance(a_small, b_small)
  let large_dist = neato_distance(a_large, b_large)
  assert_true(large_dist > small_dist + 100.0)
}

test "layout_neato respects edge length" {
  let short_graph = @dot_parser.parse_dot(
    "graph { nodesep=0; node [shape=box,width=1,height=1,label=\"\"]; a -- b [len=1]; }",
  )
  let long_graph = @dot_parser.parse_dot(
    "graph { nodesep=0; node [shape=box,width=1,height=1,label=\"\"]; a -- b [len=3]; }",
  )
  let short_layout = layout_neato(short_graph)
  short_layout.apply()
  let long_layout = layout_neato(long_graph)
  long_layout.apply()
  let short_a = match neato_node_pos(short_graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let short_b = match neato_node_pos(short_graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let long_a = match neato_node_pos(long_graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let long_b = match neato_node_pos(long_graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let short_dist = neato_distance(short_a, short_b)
  let long_dist = neato_distance(long_a, long_b)
  assert_true(long_dist > short_dist + 80.0)
}
