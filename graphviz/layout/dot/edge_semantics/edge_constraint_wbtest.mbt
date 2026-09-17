// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn constraint_fixture_edge(
  graph : @cgraph.Graph,
  tail : String,
  head : String,
) -> @cgraph.Edge raise {
  for edge in graph.edges() {
    if edge.tail().name() == tail && edge.head().name() == head {
      return edge
    }
  }
  fail("missing edge \{tail} -> \{head}")
}

///|
test "edge_is_constraint matches graphviz mapbool parity" {
  let graph = @dot_parser.parse_dot(
    "digraph { a -> b [constraint=false]; c -> d [constraint=none]; e -> f [constraint=abc]; g -> h [constraint=yes]; i -> j [constraint=0]; k -> l [constraint=2xyz]; m -> n [constraint=\"\"]; o -> p; }",
  )

  assert_false(edge_is_constraint(constraint_fixture_edge(graph, "a", "b")))
  assert_false(edge_is_constraint(constraint_fixture_edge(graph, "c", "d")))
  assert_false(edge_is_constraint(constraint_fixture_edge(graph, "e", "f")))
  assert_true(edge_is_constraint(constraint_fixture_edge(graph, "g", "h")))
  assert_false(edge_is_constraint(constraint_fixture_edge(graph, "i", "j")))
  assert_true(edge_is_constraint(constraint_fixture_edge(graph, "k", "l")))
  assert_true(edge_is_constraint(constraint_fixture_edge(graph, "m", "n")))
  assert_true(edge_is_constraint(constraint_fixture_edge(graph, "o", "p")))
}

///|
test "constraint gating zeros weight and xpenalty" {
  let graph = @dot_parser.parse_dot(
    "digraph { a -> b [constraint=false, weight=5, xpenalty=7]; c -> d [constraint=yes, weight=5, xpenalty=7]; e -> f [constraint=0, weight=4, xpenalty=3]; }",
  )

  let edge_ab = constraint_fixture_edge(graph, "a", "b")
  let edge_cd = constraint_fixture_edge(graph, "c", "d")
  let edge_ef = constraint_fixture_edge(graph, "e", "f")

  assert_eq(edge_weight(edge_ab), 0)
  assert_eq(edge_xpenalty(edge_ab), 0)
  assert_eq(edge_weight(edge_cd), 5)
  assert_eq(edge_xpenalty(edge_cd), 7)
  assert_eq(edge_weight(edge_ef), 0)
  assert_eq(edge_xpenalty(edge_ef), 0)
}
