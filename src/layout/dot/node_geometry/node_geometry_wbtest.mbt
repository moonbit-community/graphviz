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
