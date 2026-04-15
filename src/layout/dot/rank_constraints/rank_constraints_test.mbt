// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn rank_parse_double(text : String, fallback : Double) -> Double {
  try @string.parse_double(text) catch {
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
test "rank keywords keep expected vertical extremes" {
  let min_graph = @dot_parser.parse_dot(
    "digraph { subgraph { rank=min; a; b; } c; a -> c; b -> c; }",
  )
  let min_layout = @layout_dot.layout_dot(min_graph)
  min_layout.apply()
  let min_a = match rank_node_pos(min_graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let min_b = match rank_node_pos(min_graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let min_c = match rank_node_pos(min_graph, "c") {
    Some(value) => value
    None => fail("missing pos for node c")
  }
  assert_true(Double::is_close(min_a.y, min_b.y, absolute_tolerance=0.01))
  assert_true(min_a.y > min_c.y)

  let max_graph = @dot_parser.parse_dot(
    "digraph { subgraph { rank=max; a; b; } c; c -> a; c -> b; }",
  )
  let max_layout = @layout_dot.layout_dot(max_graph)
  max_layout.apply()
  let max_a = match rank_node_pos(max_graph, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let max_b = match rank_node_pos(max_graph, "b") {
    Some(value) => value
    None => fail("missing pos for node b")
  }
  let max_c = match rank_node_pos(max_graph, "c") {
    Some(value) => value
    None => fail("missing pos for node c")
  }
  assert_true(Double::is_close(max_a.y, max_b.y, absolute_tolerance=0.01))
  assert_true(max_a.y < max_c.y)

  let extremes_graph = @dot_parser.parse_dot(
    "digraph { subgraph { rank=source; s1; s2; } subgraph { rank=sink; t1; t2; } s1 -> t1; s2 -> t2; }",
  )
  let extremes_layout = @layout_dot.layout_dot(extremes_graph)
  extremes_layout.apply()
  let s1_pos = match rank_node_pos(extremes_graph, "s1") {
    Some(value) => value
    None => fail("missing pos for node s1")
  }
  let s2_pos = match rank_node_pos(extremes_graph, "s2") {
    Some(value) => value
    None => fail("missing pos for node s2")
  }
  let t1_pos = match rank_node_pos(extremes_graph, "t1") {
    Some(value) => value
    None => fail("missing pos for node t1")
  }
  let t2_pos = match rank_node_pos(extremes_graph, "t2") {
    Some(value) => value
    None => fail("missing pos for node t2")
  }
  assert_true(Double::is_close(s1_pos.y, s2_pos.y, absolute_tolerance=0.01))
  assert_true(Double::is_close(t1_pos.y, t2_pos.y, absolute_tolerance=0.01))
  assert_true(s1_pos.y > t1_pos.y)
}

///|
test "constraint=false keeps same rank while default separates ranks" {
  let unconstrained = @dot_parser.parse_dot("digraph { a -> b [constraint=false]; }")
  let unconstrained_layout = @layout_dot.layout_dot(unconstrained)
  unconstrained_layout.apply()
  let unconstrained_a = match rank_node_pos(unconstrained, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let unconstrained_b = match rank_node_pos(unconstrained, "b") {
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
  let constrained_layout = @layout_dot.layout_dot(constrained)
  constrained_layout.apply()
  let constrained_a = match rank_node_pos(constrained, "a") {
    Some(value) => value
    None => fail("missing pos for node a")
  }
  let constrained_b = match rank_node_pos(constrained, "b") {
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
