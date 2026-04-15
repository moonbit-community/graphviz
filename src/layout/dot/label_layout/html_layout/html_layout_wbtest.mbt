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
    @geom.Point::{ x: 0.0, y: 0.0 },
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
    @geom.Point::{ x: 0.0, y: 0.0 },
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
