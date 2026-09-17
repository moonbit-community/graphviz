// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn assert_close(actual : Double, expected : Double, tol : Double) -> Unit raise {
  let ok = Double::is_close(actual, expected, absolute_tolerance=tol)
  if !ok {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
test "node_size keeps fixedsize=true circle dimensions" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [margin=0 fontsize=32 width=0.5 shape=circle style=filled]; b [fixedsize=true label=\"a very long label\"]; }",
  )
  let node = graph.node("b")
  let size = node_size(node, @layout_prep.RecordOrientation::Horizontal)

  assert_close(size.width_in, 0.5, 0.0001)
  assert_close(size.height_in, 0.5, 0.0001)
}

///|
test "node_size keeps fixedsize=shape label bbox without circle inflation" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [margin=0 fontsize=32 width=0.5 shape=circle style=filled]; d [fixedsize=shape label=\"an even longer label\"]; }",
  )
  let node = graph.node("d")
  let size = node_size(node, @layout_prep.RecordOrientation::Horizontal)

  assert_close(size.width_in, 3.5833, 0.001)
  assert_close(size.height_in, 0.51042, 0.001)
}

///|
test "node_size gives square nodes their regular half-inch default" {
  let graph = @dot_parser.parse_dot("digraph { a [shape=square]; }")
  let size = node_size(
    graph.node("a"),
    @layout_prep.RecordOrientation::Horizontal,
  )

  assert_close(size.width_in, 0.5, 0.0001)
  assert_close(size.height_in, 0.5, 0.0001)
}

///|
test "regular empty nodes use supplied dimensions without the other default" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [label=\"\" shape=circle]; a [width=.2]; b [height=.2]; c [width=.2 height=.3]; d [shape=square width=.2]; }",
  )
  for entry in [("a", 0.2), ("b", 0.2), ("c", 0.3), ("d", 0.2)] {
    let (name, expected) = entry
    let size = node_size(
      graph.node(name),
      @layout_prep.RecordOrientation::Horizontal,
    )
    assert_close(size.width_in, expected, 0.000001)
    assert_close(size.height_in, expected, 0.000001)
  }
}
