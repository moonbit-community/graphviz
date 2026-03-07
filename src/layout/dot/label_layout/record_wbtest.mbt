///|
test "html_ports include td port names" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=plaintext]; a [label=<<TABLE><TR><TD PORT=\\\"p1\\\">one</TD></TR></TABLE>>]; }",
  )
  let record_orientation =
    @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
  let node = graph.node("a")
  let size = @node_geometry.node_size(node, record_orientation)
  let ports = @html_layout.html_ports(node, @label_attrs.label_text(node), @geom.Point::{ x: 0.0, y: 0.0 }, size)
  match ports.get("p1") {
    Some(port) => {
      let half_w = size.width_pt / 2.0
      let half_h = size.height_pt / 2.0
      assert_true(port.center.x >= -half_w && port.center.x <= half_w)
      assert_true(port.center.y >= -half_h && port.center.y <= half_h)
    }
    None => fail("missing html port")
  }
}

///|
test "record_ports rotate into layout coords for rankdir LR" {
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=LR; node [shape=record]; b [label=\"<left>   |<mid> b |   \"]; }",
  )
  let record_orientation =
    @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
  let node = graph.node("b")
  let size = @node_geometry.node_size(node, record_orientation)
  let ports = @record_layout.record_ports(
    node,
    @geom.Point::{ x: 0.0, y: 0.0 },
    size,
    record_orientation,
  )
  let rotated = @port_geometry.layout_ports_from_final(ports, @geom.Point::{ x: 0.0, y: 0.0 }, @rankdir.RankDir::LR)
  match rotated.get("left") {
    Some(port) => {
      assert_true(port.center.x > 0.0)
    }
    None => fail("missing left port")
  }
}

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
  let orientation = @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
  let node = graph.node("b")
  let size = @node_geometry.node_size(node, orientation)
  assert_close(size.width_in, 0.5, 0.0001)
  assert_close(size.height_in, 0.5, 0.0001)
}

///|
test "node_size keeps fixedsize=shape label bbox without circle inflation" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [margin=0 fontsize=32 width=0.5 shape=circle style=filled]; d [fixedsize=shape label=\"an even longer label\"]; }",
  )
  let orientation = @shared.record_layout_orientation(@rankdir.graph_rankdir(graph))
  let node = graph.node("d")
  let size = @node_geometry.node_size(node, orientation)
  assert_close(size.width_in, 3.5833, 0.001)
  assert_close(size.height_in, 0.51042, 0.001)
}
