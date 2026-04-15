// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
fn require_port(
  ports : Map[String, RecordPort],
  key : String,
  label : String,
) -> RecordPort raise {
  match ports.get(key) {
    Some(port) => port
    None => fail("missing \{label}")
  }
}

///|
fn assert_port_close(actual : RecordPort, expected : RecordPort) -> Unit raise {
  assert_close(actual.center.x, expected.center.x)
  assert_close(actual.center.y, expected.center.y)
  assert_close(actual.size.width_pt, expected.size.width_pt)
  assert_close(actual.size.height_pt, expected.size.height_pt)
  assert_eq(actual.sides, expected.sides)
}

///|
fn sample_node_size(width_pt : Double, height_pt : Double) -> NodeSize {
  @node_primitives.node_size_from_points(width_pt, height_pt)
}

///|
test "raw_label_ports_for_node prefers html ports even on record-shaped nodes" {
  reset_label_caches()
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("html_first")
  node.set_attr("shape", "record")
  node.set_attr(
    "label", "<<TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\"><TR><TD PORT=\"html\">one</TD></TR></TABLE>>",
  )
  let origin = @geom.Point::{ x: 24.0, y: -12.0 }
  let base_size = sample_node_size(96.0, 48.0)

  let actual = raw_label_ports_for_node(
    node,
    origin,
    base_size,
    RecordOrientation::Horizontal,
  )
  let expected = @html_layout.html_ports(
    node,
    @label_attrs.label_text(node),
    origin,
    base_size,
  )

  assert_eq(actual.length(), 1)
  let actual_port = require_port(actual, "html", "html port")
  let expected_port = require_port(expected, "html", "expected html port")
  assert_port_close(actual_port, expected_port)
}

///|
test "raw_label_ports_for_node uses record ports for record-shaped non-html labels" {
  reset_label_caches()
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("record_ports")
  node.set_attr("shape", "record")
  node.set_attr("label", "<left>left|<right>right")
  let origin = @geom.Point::{ x: -8.0, y: 14.0 }
  let base_size = sample_node_size(120.0, 54.0)

  let actual = raw_label_ports_for_node(
    node,
    origin,
    base_size,
    RecordOrientation::Horizontal,
  )
  let expected = @record_layout.record_ports(
    node,
    origin,
    base_size,
    RecordOrientation::Horizontal,
  )

  assert_eq(actual.length(), 2)
  let actual_left = require_port(actual, "left", "left port")
  let actual_right = require_port(actual, "right", "right port")
  let expected_left = require_port(expected, "left", "expected left port")
  let expected_right = require_port(expected, "right", "expected right port")
  assert_port_close(actual_left, expected_left)
  assert_port_close(actual_right, expected_right)
}

///|
test "raw_label_ports_for_node returns empty for non-html non-record nodes" {
  reset_label_caches()
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("plain")
  node.set_attr("shape", "ellipse")
  node.set_attr("label", "plain text")

  let ports = raw_label_ports_for_node(
    node,
    @geom.Point::{ x: 0.0, y: 0.0 },
    sample_node_size(72.0, 36.0),
    RecordOrientation::Horizontal,
  )

  assert_eq(ports.length(), 0)
}
