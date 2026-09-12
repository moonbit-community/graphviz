///|
test "flat auxiliary clones preserve ports and HTML node attributes" {
  let original = @cgraph.Graph::new(@cgraph.GraphKind::Directed)
  let a = original.node("a")
  let b = original.node("b")
  a.set_attr_value(
    "label",
    @cgraph.AttrValue::Html("<<TABLE><TR><TD>x</TD></TR></TABLE>>"),
  )
  let edge = original.edge(
    a,
    b,
    tail_port={ name: None, compass: Some(@cgraph.Compass::W), },
    head_port={ name: Some("inner"), compass: Some(@cgraph.Compass::N), },
  )
  let aux = @cgraph.Graph::new(@cgraph.GraphKind::Directed)
  let clone_a = clone_flat_node(aux, a)
  let clone_b = clone_flat_node(aux, b)
  let clone = clone_flat_edge(aux, clone_a, clone_b, edge)
  @test.assert_eq(clone_a.get_attr_value("label"), a.get_attr_value("label"))
  @test.assert_eq(clone.tail_port(), edge.tail_port())
  @test.assert_eq(clone.head_port(), edge.head_port())
  @test.assert_eq(original.nodes().length(), 2)
  @test.assert_eq(original.edges().length(), 1)
}

///|
test "adjacent outward compass ports route outside both nodes without mutating the graph" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed)
  let same = graph.subgraph()
  same.set_attr("rank", "same")
  let a = same.node("a")
  let b = same.node("b")
  a.set_attr("shape", "box")
  b.set_attr("shape", "box")
  let edge = graph.edge(
    a,
    b,
    tail_port={ name: None, compass: Some(@cgraph.Compass::W), },
    head_port={ name: None, compass: Some(@cgraph.Compass::E), },
  )
  let layout = layout_dot(graph)
  @test.assert_eq(layout.edges.length(), 1)
  let spline = layout.edges[0].splines[0]
  let left = layout.nodes[0]
  let right = layout.nodes[1]
  assert_true(spline.points[0].x < left.pos.x - left.width_in * 36.0)
  guard spline.end is Some(end) else { fail("missing arrow endpoint") }
  assert_true(end.x > right.pos.x + right.width_in * 36.0)
  assert_true(
    spline.points.any(point => point.y > left.pos.y + left.height_in * 36.0),
  )
  @test.assert_eq(graph.nodes().length(), 2)
  @test.assert_eq(graph.edges().length(), 1)
  @test.assert_eq(edge.get_attr("weight"), None)
}

///|
test "adjacent parallel labels put the widest above and route the narrower below" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let same = graph.subgraph()
  same.set_attr("rank", "same")
  let a = same.node("a")
  let b = same.node("b")
  let narrow = graph.edge(a, b)
  narrow.set_attr("label", "short")
  let wide = graph.edge(a, b)
  wide.set_attr("label", "a much wider label")
  let layout = layout_dot(graph)
  @test.assert_eq(layout.edges.length(), 2)
  let node_y = layout.nodes[0].pos.y
  for edge in layout.edges {
    guard edge.label_pos is Some(label) else { fail("missing label") }
    if edge.edge.id() == narrow.id() {
      @test.assert_eq(label.y < node_y, true)
      @test.assert_eq(
        edge.splines[0].points.any(point => point.y < label.y),
        true,
      )
    } else {
      @test.assert_eq(label.y > node_y, true)
      @test.assert_eq(
        edge.splines[0].points.any(point => point.y != node_y),
        false,
      )
    }
  }
}
