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
test "compass_uses_shape_clipping distinguishes ellipse-like and box-like polygons" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let ellipse = graph.node("ellipse")
  ellipse.set_attr("shape", "circle")
  let rect = graph.node("rect")
  rect.set_attr("shape", "box")
  let polygon = graph.node("polygon")
  polygon.set_attr("shape", "polygon")
  polygon.set_attr("sides", "4")
  polygon.set_attr("orientation", "90")

  assert_eq(compass_uses_shape_clipping(ellipse), true)
  assert_eq(compass_uses_shape_clipping(rect), false)
  assert_eq(compass_uses_shape_clipping(polygon), false)
}
