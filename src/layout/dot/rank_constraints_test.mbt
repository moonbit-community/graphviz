///|
fn rank_parse_double(text : String, fallback : Double) -> Double {
  try @strconv.parse_double(text) catch {
    _ => fallback
  } noraise {
    value => value
  }
}

///|
fn rank_parse_point(text : String) -> @geom.Point {
  let parts : Array[String] = []
  for part in text.split(",") {
    parts.push(part.to_string())
  }
  let x = if parts.length() > 0 {
    rank_parse_double(parts[0], 0.0)
  } else {
    0.0
  }
  let y = if parts.length() > 1 {
    rank_parse_double(parts[1], 0.0)
  } else {
    0.0
  }
  { x, y }
}

///|
fn rank_node_pos(graph : @cgraph.Graph, name : String) -> @geom.Point? {
  match graph.find_node(name) {
    Some(node) =>
      match node.get_attr("pos") {
        Some(value) => Some(rank_parse_point(value))
        None => None
      }
    None => None
  }
}

///|
#skip
test "rank=min places nodes at top" {
  let graph = @dot_parser.parse_dot(
    "digraph { subgraph { rank=min; a; b; } c; a -> c; b -> c; }",
  )
  let layout = layout_dot(graph)
  layout.apply()
  let a_pos = match rank_node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_pos = match rank_node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let c_pos = match rank_node_pos(graph, "c") {
    Some(value) => value
    None => fail("missing pos for node c")
  }
  assert_true(Double::is_close(a_pos.y, b_pos.y, absolute_tolerance=0.01))
  assert_true(a_pos.y > c_pos.y)
}

///|
#skip
test "rank=max places nodes at bottom" {
  let graph = @dot_parser.parse_dot(
    "digraph { subgraph { rank=max; a; b; } c; c -> a; c -> b; }",
  )
  let layout = layout_dot(graph)
  layout.apply()
  let a_pos = match rank_node_pos(graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let b_pos = match rank_node_pos(graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let c_pos = match rank_node_pos(graph, "c") {
    Some(value) => value
    None => fail("missing pos for node c")
  }
  assert_true(Double::is_close(a_pos.y, b_pos.y, absolute_tolerance=0.01))
  assert_true(a_pos.y < c_pos.y)
}

///|
#skip
test "rank=source and rank=sink keep extremes" {
  let graph = @dot_parser.parse_dot(
    "digraph { subgraph { rank=source; s1; s2; } subgraph { rank=sink; t1; t2; } s1 -> t1; s2 -> t2; }",
  )
  let layout = layout_dot(graph)
  layout.apply()
  let s1_pos = match rank_node_pos(graph, "s1") {
    Some(value) => value
    None => fail("missing pos for node s1")
  }
  let s2_pos = match rank_node_pos(graph, "s2") {
    Some(value) => value
    None => fail("missing pos for node s2")
  }
  let t1_pos = match rank_node_pos(graph, "t1") {
    Some(value) => value
    None => fail("missing pos for node t1")
  }
  let t2_pos = match rank_node_pos(graph, "t2") {
    Some(value) => value
    None => fail("missing pos for node t2")
  }
  assert_true(Double::is_close(s1_pos.y, s2_pos.y, absolute_tolerance=0.01))
  assert_true(Double::is_close(t1_pos.y, t2_pos.y, absolute_tolerance=0.01))
  assert_true(s1_pos.y > t1_pos.y)
}
