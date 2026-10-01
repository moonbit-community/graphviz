// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn extract_numbers(value : String) -> Array[Double] raise {
  let sb = StringBuilder()
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
    } else {
      sb.write_char(' ')
    }
  }
  let normalized = sb.to_string()
  let numbers : Array[Double] = []
  for token in normalized.split(" ") {
    if token.length() == 0 {
      continue
    }
    let parsed = @string.parse_double(token)
    numbers.push(parsed)
  }
  numbers
}

///|
test "compass ports on plain nodes clip away from node centers" {
  let graph = try
    @dot_parser.parse_dot(
      "digraph { foo:s -> bar:n [dir=both arrowhead=crow arrowtail=crow] }",
    )
  catch {
    err => fail("parse failed: \{err}")
  } noraise {
    value => value
  }
  let layout = @dot.layout_dot(graph)
  layout.apply()
  let edges = graph.edges()
  assert_eq(edges.length(), 1)
  let pos = match edges[0].get_attr("pos") {
    Some(value) => value
    None => fail("missing edge pos")
  }
  let numbers = try extract_numbers(pos) catch {
    err => fail("extract_numbers failed: \{err}")
  } noraise {
    value => value
  }
  if numbers.length() < 4 {
    fail("unexpected pos attr: \{pos}")
  }
  let tail_y = numbers[1]
  let head_y = numbers[3]
  // Centers for default nodes are near y=90 and y=18; port clipping should
  // move anchors toward boundaries around y=72 and y=36.
  assert_true(tail_y < 80.0)
  assert_true(head_y > 30.0)
}
