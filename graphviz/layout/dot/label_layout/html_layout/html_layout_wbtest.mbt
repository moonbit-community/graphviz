// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "html_ports include td port names" {
  reset_html_label_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=plaintext]; html_ports_node [label=<<TABLE><TR><TD PORT=\\\"p1\\\">one</TD></TR></TABLE>>]; }",
  )
  let node = graph.node("html_ports_node")
  let size = @node_geometry.node_size(
    node,
    @layout_prep.RecordOrientation::Horizontal,
  )
  let ports = html_ports(
    node,
    @label_attrs.label_text(node),
    @geom.Point::{ x: 0.0, y: 0.0, },
    size,
  )
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
test "html_ports recurse into nested tables and preserve nested cell geometry" {
  reset_html_label_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=plaintext]; nested_html_node [label=<<TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\"><TR><TD><TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\"><TR><TD PORT=\"inner\">x</TD></TR></TABLE></TD></TR></TABLE>>]; }",
  )
  let node = graph.node("nested_html_node")
  let size = @node_geometry.node_size(
    node,
    @layout_prep.RecordOrientation::Horizontal,
  )
  let ports = html_ports(
    node,
    @label_attrs.label_text(node),
    @geom.Point::{ x: 0.0, y: 0.0, },
    size,
  )
  let port = match ports.get("inner") {
    Some(value) => value
    None => fail("missing nested html port")
  }

  assert_true(port.size.width_pt > 0.0)
  assert_true(port.size.height_pt > 0.0)
  assert_true(Double::abs(port.center.x) <= size.width_pt / 2.0)
  assert_true(Double::abs(port.center.y) <= size.height_pt / 2.0)
}

///|
test "HTML ports use natural table size and inherited boundary sides" {
  reset_html_label_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { a [label=<<TABLE PORT=\"root\"><TR><TD><TABLE PORT=\"nested\"><TR><TD PORT=\"leaf\">x</TD></TR></TABLE></TD><TD>y</TD></TR></TABLE>>]; }",
  )
  let node = graph.node("a")
  let label = @label_attrs.label_text(node)
  let ports = html_ports(
    node,
    label,
    { x: 10.0, y: 20.0, },
    @node_primitives.node_size_from_points(500.0, 500.0),
  )
  guard ports.get("root") is Some(root) else { fail("missing root port") }
  guard ports.get("nested") is Some(nested) else { fail("missing nested port") }
  guard ports.get("leaf") is Some(leaf) else { fail("missing leaf port") }
  @test.assert_eq(root.center, { x: 10.0, y: 20.0, })
  assert_true(root.size.width_pt < 500.0)
  assert_true(root.size.height_pt < 500.0)
  @test.assert_eq(root.sides, @port_geometry.PORT_SIDE_ALL)
  let expected_sides = @port_geometry.PORT_SIDE_LEFT |
    @port_geometry.PORT_SIDE_TOP |
    @port_geometry.PORT_SIDE_BOTTOM
  @test.assert_eq(nested.sides, expected_sides)
  @test.assert_eq(leaf.sides, expected_sides)
  assert_true(nested.size.width_pt < root.size.width_pt)
}

///|
test "html table sizing honors cell borders" {
  reset_html_label_caches()
  let label = "<<TABLE border=\"10\" cellspacing=\"10\" cellpadding=\"10\"><TR><TD border=\"3\">00</TD></TR></TABLE>>"
  let parsed = match parse_html_label_cached(label) {
    Some(value) => value
    None => fail("missing HTML label")
  }
  let size = html_label_size(parsed, "Times-Roman", 14.0)
  inspect(size.width_pt, content="79.5")
  let graph = @dot_parser.parse_dot(
    "digraph { a [shape=circle label=<<TABLE border=\"10\" cellspacing=\"10\" cellpadding=\"10\"><TR><TD border=\"3\">00</TD></TR></TABLE>>]; }",
  )
  let node_size = @node_geometry.node_size(
    graph.node("a"),
    @layout_prep.RecordOrientation::Horizontal,
  )
  inspect(node_size.width_pt, content="135.0573952066306")
}
